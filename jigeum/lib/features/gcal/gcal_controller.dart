import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/gcal/gcal_api.dart';
import '../../core/gcal/gcal_auth.dart';
import '../../data/db.dart';
import '../../data/repos/gcal_repository.dart';
import '../../data/repos/schedule_repository.dart';
import '../../providers.dart';
import '../widgetkit/widget_bridge.dart';
import 'gcal_sync.dart';

/// 구글 캘린더 연동 UI 상태.
@immutable
class GcalState {
  const GcalState({
    this.connected = false,
    this.email,
    this.syncing = false,
    this.lastSyncAt,
    this.error,
  });

  final bool connected;
  final String? email;
  final bool syncing;
  final DateTime? lastSyncAt;
  final String? error;

  GcalState copyWith({
    bool? connected,
    String? email,
    bool? syncing,
    DateTime? lastSyncAt,
    Object? error = _keep,
  }) =>
      GcalState(
        connected: connected ?? this.connected,
        email: email ?? this.email,
        syncing: syncing ?? this.syncing,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
        error: identical(error, _keep) ? this.error : error as String?,
      );

  static const _keep = Object();
}

/// 연동 오케스트레이터 — 로그인·캘린더 목록·양방향 동기화·위젯 팝업 큐 처리.
class GcalController extends StateNotifier<GcalState> {
  GcalController(this.ref) : super(const GcalState());

  final Ref ref;

  final GcalApi _api = GcalApi();
  GcalAuth get _auth => GcalAuth.instance;

  GcalRepository get _gcalRepo => ref.read(gcalRepoProvider);
  ScheduleRepository get _scheduleRepo => ref.read(scheduleRepoProvider);

  GcalSync get _sync => GcalSync(_api, _gcalRepo, _scheduleRepo);

  /// 앱 시작 시 조용히 복구. 연결돼 있으면 위젯 팝업 큐를 비우고 동기화까지.
  Future<void> restore() async {
    final ok = await _auth.restore();
    state = state.copyWith(connected: ok, email: _auth.email);
    if (ok) {
      await _pushCalendarsToWidget();
      await syncNow(refreshList: false);
    }
  }

  /// 사용자 로그인 → 캘린더 목록 로드 → 첫 동기화.
  Future<bool> connect() async {
    state = state.copyWith(error: null);
    final ok = await _auth.connect();
    if (!ok) {
      state = state.copyWith(error: '구글 로그인을 취소했거나 실패했어요.');
      return false;
    }
    state = state.copyWith(connected: true, email: _auth.email);
    await refreshCalendarList();
    await syncNow(refreshList: false);
    return true;
  }

  Future<void> disconnect() async {
    await _auth.disconnect();
    await _gcalRepo.clearAllCalendars();
    await _pushCalendarsToWidget();
    state = const GcalState();
  }

  /// 구글에서 캘린더 목록을 새로 가져와 로컬에 반영 + 위젯에 전달.
  Future<void> refreshCalendarList() async {
    final entries = await _api.calendars();
    final mapped = entries
        .where((e) => e.id != null)
        .map((e) => RemoteCalendar(
              id: e.id!,
              summary: e.summaryOverride ?? e.summary ?? e.id!,
              colorHex: e.backgroundColor ?? '#4A5A66',
              primary: e.primary ?? false,
              accessRole: e.accessRole ?? 'reader',
            ))
        .toList();
    await _gcalRepo.upsertFromRemote(mapped);
    await _pushCalendarsToWidget();
  }

  /// 캘린더 종류별 동기화 on/off.
  Future<void> setCalendarSelected(String id, bool selected) async {
    await _gcalRepo.setSelected(id, selected);
    await _pushCalendarsToWidget();
    // 켜면 곧바로 그 캘린더를 당겨온다.
    if (selected) await syncNow(refreshList: false);
  }

  /// 위젯 팝업 큐를 비우고 양방향 동기화. [refreshList] 면 캘린더 목록도 갱신.
  Future<void> syncNow({bool refreshList = true}) async {
    if (!_auth.isConnected) return;
    if (state.syncing) return;
    state = state.copyWith(syncing: true, error: null);
    try {
      await drainQuickAddQueue();
      if (refreshList) await refreshCalendarList();
      await _sync.run();
      state = state.copyWith(syncing: false, lastSyncAt: DateTime.now());
    } catch (e) {
      state = state.copyWith(syncing: false, error: '동기화 중 문제가 있었어요.');
      debugPrint('gcal syncNow 실패: $e');
    }
  }

  /// 1×1 위젯 팝업으로 입력된 항목을 로컬 일정으로 추가(dirty → 다음 push 로 원격 반영).
  /// 네이티브 SharedPreferences 큐를 1회성으로 소비한다.
  Future<int> drainQuickAddQueue() async {
    final raw = await WidgetBridge.consumeQuickAddQueue();
    if (raw == null || raw.isEmpty) return 0;
    List<dynamic> items;
    try {
      items = jsonDecode(raw) as List<dynamic>;
    } catch (_) {
      return 0;
    }
    var added = 0;
    for (final it in items) {
      if (it is! Map) continue;
      final title = (it['title'] as String?)?.trim() ?? '';
      if (title.isEmpty) continue;
      final calId = (it['calendarId'] as String?);
      final allDay = it['allDay'] == true;
      final millis = (it['at'] as num?)?.toInt();
      final at = millis != null
          ? DateTime.fromMillisecondsSinceEpoch(millis)
          : DateTime.now();
      final startMin = allDay ? 0 : at.hour * 60 + at.minute;
      final endMin = allDay ? 0 : (startMin + 60).clamp(0, 1439);
      await _scheduleRepo.addSchedule(
        date: at,
        title: title,
        startMin: startMin,
        endMin: endMin,
        allDay: allDay,
        gcalCalendarId: calId,
        dirty: true, // 원격으로 밀어야 함
      );
      added++;
    }
    return added;
  }

  /// 선택된 캘린더 목록을 네이티브(위젯 팝업 스피너)로 전달.
  Future<void> _pushCalendarsToWidget() async {
    try {
      final cals = await _gcalRepo.selectedCalendars();
      final payload = cals
          .map((c) => {'id': c.id, 'name': c.summary, 'color': c.colorHex})
          .toList();
      await WidgetBridge.setGcalCalendars(jsonEncode(payload));
    } catch (e) {
      debugPrint('gcal 위젯 캘린더 전달 실패(무시): $e');
    }
  }
}

final gcalControllerProvider =
    StateNotifierProvider<GcalController, GcalState>((ref) {
  return GcalController(ref);
});

/// 캘린더 목록 스트림(설정 화면 종류별 선택 UI).
final gcalCalendarsProvider = StreamProvider<List<GcalCalendar>>((ref) {
  return ref.watch(gcalRepoProvider).watchCalendars();
});
