/// 쏟아내기 대기줄 상태(담기 전 미리 분류된 것들). 화면(위젯) 밖으로 올려
/// **탭 이동에도, 앱 재시작에도** 살아남게 한다("말은 버리지 않는다").
///
/// 메모리에는 실제 [VoiceResult] 를 들고 있어 그대로 담을 수 있고, 저장은
/// 원문+착지지점만 drift `Settings` kv 에 JSON 으로 write-through 한다.
/// 재시작 복원 시 원문을 다시 분류하고 저장된 지점으로 강제([VoiceController.restage],
/// 학습 없음)해 사용자가 고쳐둔 분류까지 그대로 되살린다.
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../voice/models/intent_type.dart';
import '../voice/models/voice_result.dart';

/// 대기줄(최신 위) — 담기 전 미리 분류된 것들.
final dumpStagingProvider =
    NotifierProvider<DumpStagingNotifier, List<VoiceResult>>(
        DumpStagingNotifier.new);

class DumpStagingNotifier extends Notifier<List<VoiceResult>> {
  static const _key = 'dump_staging_v1';

  @override
  List<VoiceResult> build() {
    _load();
    return const [];
  }

  Future<void> _load() async {
    final raw = await ref.read(nodeRepoProvider).getSetting(_key);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final ctrl = ref.read(voiceControllerProvider);
      final restored = <VoiceResult>[
        for (final e in decoded)
          ctrl.restage(
            (e as Map<String, dynamic>)['raw'] as String,
            _routeByName(e['route'] as String?),
          ),
      ];
      if (restored.isNotEmpty) state = restored;
    } catch (_) {
      // 손상된 값은 무시 — 다음 저장 때 덮어쓴다.
    }
  }

  Future<void> _persist(List<VoiceResult> items) async {
    final json = jsonEncode([
      for (final r in items) {'raw': r.rawText, 'route': r.routedTo.name},
    ]);
    await ref.read(nodeRepoProvider).setSetting(_key, json);
  }

  /// 새로 분류된 것을 대기줄 맨 위에 넣는다.
  void addResult(VoiceResult r) {
    final next = [r, ...state];
    state = next;
    _persist(next);
  }

  /// i 번째를 교정된 결과로 교체(버킷 탭 → 재분류).
  void replaceAt(int i, VoiceResult r) {
    if (i < 0 || i >= state.length) return;
    final next = [...state]..[i] = r;
    state = next;
    _persist(next);
  }

  /// i 번째를 대기줄에서 뺀다(X).
  void removeAt(int i) {
    if (i < 0 || i >= state.length) return;
    final next = [...state]..removeAt(i);
    state = next;
    _persist(next);
  }

  /// 담기 완료 후 비운다.
  void clear() {
    state = const [];
    _persist(const []);
  }

  RoutePoint _routeByName(String? name) {
    if (name != null) {
      for (final rp in RoutePoint.values) {
        if (rp.name == name) return rp;
      }
    }
    return RoutePoint.inbox;
  }
}
