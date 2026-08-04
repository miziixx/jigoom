import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notion/notion_client.dart';
import '../../data/repos/notion_repository.dart';
import '../../providers.dart';
import 'notion_sync.dart';

/// 노션 연동 UI 상태.
@immutable
class NotionState {
  const NotionState({
    this.connected = false,
    this.syncing = false,
    this.autoShare = false,
    this.enabled = const {},
    this.lastSyncAt,
    this.error,
  });

  final bool connected; // 토큰·부모 페이지 저장됨(= 사용 중)
  final bool syncing;
  final bool autoShare; // 실시간 자동 공유 on/off
  final Map<NotionSyncType, bool> enabled; // 유형별 동기화 on/off
  final DateTime? lastSyncAt;
  final String? error;

  NotionState copyWith({
    bool? connected,
    bool? syncing,
    bool? autoShare,
    Map<NotionSyncType, bool>? enabled,
    DateTime? lastSyncAt,
    Object? error = _keep,
  }) =>
      NotionState(
        connected: connected ?? this.connected,
        syncing: syncing ?? this.syncing,
        autoShare: autoShare ?? this.autoShare,
        enabled: enabled ?? this.enabled,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
        error: identical(error, _keep) ? this.error : error as String?,
      );

  static const _keep = Object();
}

/// 노션 연동 오케스트레이터 — 연결/해제·유형 선택·실시간 자동 공유·동기화.
/// gcal 의 [GcalController] 에 대응한다.
class NotionController extends StateNotifier<NotionState> {
  NotionController(this.ref) : super(const NotionState());

  final Ref ref;

  NotionRepository get _repo => ref.read(notionRepoProvider);

  /// 저장된 토큰으로 클라이언트 생성(없으면 null). 웹은 client.usable=false 로 no-op.
  Future<NotionClient?> _client() async {
    final token = await _repo.token();
    if (token == null || token.trim().isEmpty) return null;
    return NotionClient(token);
  }

  /// 앱 시작 시 조용히 복구 — 저장된 설정만 읽는다(네트워크 없음).
  Future<void> restore() async {
    final configured = await _repo.isConfigured();
    final auto = await _repo.autoShare();
    final enabled = await _loadEnabled();
    state = state.copyWith(
        connected: configured, autoShare: auto, enabled: enabled);
  }

  Future<Map<NotionSyncType, bool>> _loadEnabled() async {
    final map = <NotionSyncType, bool>{};
    for (final t in NotionSyncType.values) {
      map[t] = await _repo.isTypeEnabled(t);
    }
    return map;
  }

  /// 토큰·부모 페이지 저장 → 토큰 검증 → 첫 동기화.
  Future<bool> connect(String token, String parentPage) async {
    state = state.copyWith(error: null);
    if (kIsWeb) {
      state = state.copyWith(
          error: '웹에서는 노션 연동을 쓸 수 없어요. 안드로이드 앱에서 연결해 주세요.');
      return false;
    }
    if (token.trim().isEmpty || parentPage.trim().isEmpty) {
      state = state.copyWith(error: '토큰과 부모 페이지를 모두 입력해 주세요.');
      return false;
    }
    await _repo.saveConnection(token: token, parentPageId: parentPage);
    final client = await _client();
    final me = await client?.usersMe();
    if (me == null) {
      await _repo.clear();
      client?.dispose();
      state = state.copyWith(
          error: '노션에 연결하지 못했어요. 토큰이 맞는지, 페이지를 integration 과 공유했는지 확인해 주세요.');
      return false;
    }
    client?.dispose();
    // 기본으로 실시간 자동 공유 켬.
    await _repo.setAutoShare(true);
    state = state.copyWith(
        connected: true,
        autoShare: true,
        enabled: await _loadEnabled(),
        error: null);
    await syncNow();
    return true;
  }

  /// 연동 끄기 — 로컬 설정만 삭제(노션 쪽 데이터는 그대로 둔다).
  Future<void> disconnect() async {
    await _repo.clear();
    state = const NotionState();
  }

  Future<void> setAutoShare(bool v) async {
    await _repo.setAutoShare(v);
    state = state.copyWith(autoShare: v);
  }

  /// 유형별 동기화 on/off. 켜면 바로 한 번 동기화.
  Future<void> setTypeEnabled(NotionSyncType t, bool v) async {
    await _repo.setTypeEnabled(t, v);
    state = state.copyWith(enabled: {...state.enabled, t: v});
    if (v) await syncNow();
  }

  /// "지금 동기화" — 변경분을 노션으로 밀어 올린다.
  Future<void> syncNow() async {
    if (!state.connected || state.syncing) return;
    state = state.copyWith(syncing: true, error: null);
    try {
      final client = await _client();
      if (client == null) {
        state = state.copyWith(syncing: false, connected: false);
        return;
      }
      try {
        await NotionSync(client, _repo).run();
      } finally {
        client.dispose();
      }
      state = state.copyWith(syncing: false, lastSyncAt: DateTime.now());
    } catch (e) {
      state = state.copyWith(syncing: false, error: '동기화 중 문제가 있었어요.');
      debugPrint('notion syncNow 실패: $e');
    }
  }

  /// 실시간 자동 공유 훅 — 기록이 바뀌거나 앱이 resume 될 때 호출된다.
  /// 자동 공유가 꺼져 있거나 미연결·동기화 중이면 아무것도 안 한다.
  Future<void> flush() async {
    if (!state.connected || !state.autoShare || state.syncing) return;
    await syncNow();
  }
}

final notionControllerProvider =
    StateNotifierProvider<NotionController, NotionState>((ref) {
  return NotionController(ref);
});
