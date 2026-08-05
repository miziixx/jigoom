import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/gcal/device_calendar_bridge.dart';
import '../../data/db.dart';
import '../../data/repos/gcal_repository.dart';
import '../../data/repos/schedule_repository.dart';
import '../../providers.dart';
import '../widgetkit/widget_bridge.dart';
import 'gcal_sync.dart';

/// 폰 캘린더 연동 UI 상태.
@immutable
class GcalState {
  const GcalState({
    this.connected = false, // 권한 허용 + 사용 중
    this.syncing = false,
    this.lastSyncAt,
    this.error,
  });

  final bool connected;
  final bool syncing;
  final DateTime? lastSyncAt;
  final String? error;

  GcalState copyWith({
    bool? connected,
    bool? syncing,
    DateTime? lastSyncAt,
    Object? error = _keep,
  }) =>
      GcalState(
        connected: connected ?? this.connected,
        syncing: syncing ?? this.syncing,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
        error: identical(error, _keep) ? this.error : error as String?,
      );

  static const _keep = Object();
}

/// 연동 오케스트레이터 — 권한·캘린더 목록·양방향 동기화·위젯 팝업 큐 처리.
class GcalController extends StateNotifier<GcalState> {
  GcalController(this.ref) : super(const GcalState());

  final Ref ref;

  final DeviceCalendarBridge _bridge = DeviceCalendarBridge();

  GcalRepository get _gcalRepo => ref.read(gcalRepoProvider);
  ScheduleRepository get _scheduleRepo => ref.read(scheduleRepoProvider);

  GcalSync get _sync => GcalSync(_bridge, _gcalRepo, _scheduleRepo);

  /// 앱 시작 시 조용히 복구. 권한이 이미 있으면 목록·동기화까지.
  Future<void> restore() async {
    final ok = await _bridge.hasPermission();
    state = state.copyWith(connected: ok);
    // 백업 '합치기' 복원 등으로 이미 생긴 구글 일정 중복을 앱 시작 시 정리.
    await _gcalRepo.dedupeByGcalId();
    // 목록만 조용히 채우고, 실제 동기화는 사용자가 버튼을 눌렀을 때만 한다
    // (자동 동기화 없음 — "지금 동기화"/"연동 켜기"/캘린더 선택 시에만).
    if (ok) await refreshCalendarList();
  }

  /// 캘린더 권한 요청 → 목록 로드 → 첫 동기화.
  Future<bool> connect() async {
    state = state.copyWith(error: null);
    final ok = await _bridge.requestPermission();
    if (!ok) {
      state = state.copyWith(
          error: '캘린더 접근을 허용하지 않았어요. 설정에서 권한을 켜면 연동돼요.');
      return false;
    }
    state = state.copyWith(connected: true);
    await refreshCalendarList();
    await syncNow(refreshList: false);
    return true;
  }

  /// 연동 끄기 — 로컬 캘린더 목록·연결 상태만 정리(폰 캘린더 데이터는 안 건드림).
  Future<void> disconnect() async {
    await _gcalRepo.clearAllCalendars();
    await _pushCalendarsToWidget();
    state = const GcalState();
  }

  /// 폰에서 캘린더 목록을 새로 가져와 로컬에 반영 + 위젯에 전달.
  Future<void> refreshCalendarList() async {
    final entries = await _bridge.calendars();
    final mapped = entries
        .where((e) => e['id'] != null)
        .map((e) => RemoteCalendar(
              id: e['id'].toString(),
              summary: (e['name'] as String?)?.trim().isNotEmpty == true
                  ? e['name'] as String
                  : (e['account'] as String? ?? '캘린더'),
              colorHex: (e['colorHex'] as String?) ?? '#4A5A66',
              primary: e['primary'] == true,
              accessRole: (e['accessRole'] as String?) ?? 'reader',
            ))
        .toList();
    await _gcalRepo.upsertFromRemote(mapped);
    await _pushCalendarsToWidget();
  }

  /// 캘린더 종류별 동기화 on/off.
  Future<void> setCalendarSelected(String id, bool selected) async {
    await _gcalRepo.setSelected(id, selected);
    await _pushCalendarsToWidget();
    if (selected) {
      await syncNow(refreshList: false);
    } else {
      // 끄면 그 캘린더 일정을 바로 안 보이게 제거(다시 켜면 재동기화).
      await _gcalRepo.deleteSyncedForCalendar(id);
    }
  }

  /// 목록에서 캘린더 숨기기/보이기(편집). 안 쓰는 캘린더로 목록이 지저분할 때.
  /// 숨기면 동기화도 끄고 그 캘린더에서 온 일정을 로컬에서 즉시 제거한다
  /// (로컬 편집분은 보존). 다시 보이게 하면 목록에만 복귀 — 동기화는 꺼진 채라
  /// 필요하면 사용자가 스위치로 다시 켠다.
  Future<void> setCalendarHidden(String id, bool hidden) async {
    await _gcalRepo.setHidden(id, hidden);
    if (hidden) {
      await _gcalRepo.setSelected(id, false);
      await _gcalRepo.deleteSyncedForCalendar(id);
      await _pushCalendarsToWidget();
    }
  }

  /// 위젯 팝업 큐를 비우고 양방향 동기화. [refreshList] 면 캘린더 목록도 갱신.
  Future<void> syncNow({bool refreshList = true}) async {
    if (!state.connected) return;
    if (state.syncing) return;
    // 백그라운드에서 권한이 회수됐을 수 있으니 확인.
    if (!await _bridge.hasPermission()) {
      state = state.copyWith(connected: false);
      return;
    }
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

  /// 1×1 위젯 팝업으로 입력된 항목을 로컬 일정으로 추가(dirty → push 로 폰 캘린더 반영).
  Future<int> drainQuickAddQueue() async {
    final raw = await WidgetBridge.consumeQuickAddQueue();
    if (raw == null || raw.isEmpty) return 0;
    List<dynamic> items;
    try {
      items = jsonDecode(raw) as List<dynamic>;
    } catch (_) {
      return 0;
    }
    final nodeRepo = ref.read(nodeRepoProvider);
    var added = 0;
    for (final it in items) {
      if (it is! Map) continue;
      final title = (it['title'] as String?)?.trim() ?? '';
      if (title.isEmpty) continue;
      // type 없으면 옛 큐(일정)로 간주(하위호환).
      final type = (it['type'] as String?) ?? 'schedule';
      if (type == 'todo') {
        await nodeRepo.create(type: NodeType.task, title: title);
        added++;
        continue;
      }
      if (type == 'memo') {
        await nodeRepo.create(type: NodeType.memo, title: title);
        added++;
        continue;
      }
      // 일정 — 시작·종료 날짜(다일) 지원.
      final calId = it['calendarId'] as String?;
      final startMs = (it['startDate'] as num?)?.toInt();
      final endMs = (it['endDate'] as num?)?.toInt();
      final atMs = (it['at'] as num?)?.toInt();
      final startD = startMs != null
          ? DateTime.fromMillisecondsSinceEpoch(startMs)
          : (atMs != null
              ? DateTime.fromMillisecondsSinceEpoch(atMs)
              : DateTime.now());
      final endD =
          endMs != null ? DateTime.fromMillisecondsSinceEpoch(endMs) : startD;
      final multiDay = endD.isAfter(startD); // 네이티브가 자정으로 보냄
      // 다일 일정은 종일로 취급(시간대 없는 기간 이벤트).
      final allDay = (it['allDay'] == true) || multiDay;
      final startMin = allDay ? 0 : startD.hour * 60 + startD.minute;
      final endMin = allDay ? 0 : (startMin + 60).clamp(0, 1439);
      await _scheduleRepo.addSchedule(
        date: startD,
        endDate: multiDay ? endD : null,
        title: title,
        startMin: startMin,
        endMin: endMin,
        allDay: allDay,
        gcalCalendarId: calId,
        dirty: true,
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
