/// 음성 오케스트레이터. 기획서 §1 파이프라인 ⑥~⑦ + §9 UX + §11-4 + 커밋10.
///
/// 원문 한 발화를 받아: 분류·라우팅([VoiceRouter]) → 실행([VoiceExecutor]) 또는
/// 보류함 저장([InboxRepository]) → **확정 피드백 모델** 생성 → 되돌리기/다르게담기
/// 처리까지 담당한다. **위젯 비의존(순수 Dart)** — 로직만 담아 단위 테스트한다.
/// 스낵바·마이크 버튼은 이 모델을 렌더링만 한다.
library;

import '../inbox/inbox_item.dart';
import '../inbox/inbox_repository.dart';
import 'models/intent_type.dart';
import 'models/voice_result.dart';
import 'voice_executor.dart';
import 'voice_router.dart';

/// 확정 스낵바가 렌더링할 피드백(§9 "○○에 담았어요 [되돌리기]" + §11-4 칩).
class VoiceFeedback {
  const VoiceFeedback({
    required this.message,
    required this.undoable,
    this.reclassifyTo = const <RoutePoint>[],
  });

  /// 예: "매트릭스에 담았어요".
  final String message;

  /// 되돌리기 가능 여부.
  final bool undoable;

  /// §11-4 "다르게 담기" 칩 후보(1~2개). 비어있을 수 있음.
  final List<RoutePoint> reclassifyTo;
}

/// 마지막 실행 1건(되돌리기·재분류용, §7).
class VoiceExecution {
  const VoiceExecution({
    required this.result,
    required this.entityRef,
    required this.toInbox,
  });

  final VoiceResult result;

  /// 앱이 만든 엔티티 참조(삭제용). 보류함이면 [InboxItem].
  final Object? entityRef;

  /// 보류함에 담긴 실행인지.
  final bool toInbox;
}

class VoiceController {
  VoiceController({
    required this.router,
    required this.inbox,
    this.executor = const VoiceExecutor(),
  });

  final VoiceRouter router;
  final InboxRepository inbox;
  final VoiceExecutor executor;

  VoiceExecution? _last;

  /// 마지막 실행(되돌리기 가능한 상태인지 UI 판단용).
  VoiceExecution? get lastExecution => _last;

  /// 한 발화를 처리하고 확정 피드백을 돌려준다(§1 ⑥~⑦).
  Future<VoiceFeedback> handle(
    String rawText, {
    double? sttConfidence,
    DateTime? now,
  }) async {
    final result = router.analyze(rawText, now: now);

    // 미인식 → 보류함(§0: 말은 버리지 않는다).
    if (result.decision == RouteDecision.inbox) {
      final item = inbox.add(rawText, sttConfidence: sttConfidence);
      _last = VoiceExecution(result: result, entityRef: item, toInbox: true);
      return VoiceFeedback(
        message: '${RoutePoint.inbox.label}에 담았어요',
        undoable: true,
      );
    }

    // 확정/애매 → 해당 입력지점 생성.
    final ref = await executor.createEntity(result);
    _last = VoiceExecution(result: result, entityRef: ref, toInbox: false);
    return VoiceFeedback(
      message: '${result.routedTo.label}에 담았어요',
      undoable: true,
      reclassifyTo: _reclassifyChips(result),
    );
  }

  /// 되돌리기(§9): 생성 엔티티 삭제 + 원문을 보류함으로 되돌림.
  Future<void> undo() async {
    final last = _last;
    if (last == null) return;
    if (last.toInbox) {
      // 이미 보류함 건이면 그대로 둔다(원문 보존이 목적).
    } else {
      await executor.deleteEntity(last.result, last.entityRef);
      inbox.add(last.result.rawText); // 원문 보류함 복원 → 재시도 가능.
    }
    _last = null;
  }

  /// §11-4 "다르게 담기": 마지막 실행을 취소하고 [target] 지점으로 다시 담는다.
  /// 이 교정은 §11-1 학습 신호가 된다(다음부터 그리로 가점).
  Future<VoiceFeedback> reclassifyLast(RoutePoint target) async {
    final last = _last;
    if (last == null) {
      return const VoiceFeedback(message: '되돌릴 게 없어요', undoable: false);
    }
    if (!last.toInbox) {
      await executor.deleteEntity(last.result, last.entityRef);
    }
    final intent = _intentForRoute(target);
    router.recordCorrection(last.result, intent); // 학습.

    final forced = _forceResult(last.result, intent, target);
    final ref = await executor.createEntity(forced);
    _last = VoiceExecution(result: forced, entityRef: ref, toInbox: false);
    return VoiceFeedback(
      message: '${target.label}(으)로 옮겼어요',
      undoable: true,
      reclassifyTo: _reclassifyChips(forced),
    );
  }

  // ------------------------------------------------- 쏟아내기 스테이징 API

  /// 부작용 없이 분류만 한다(쏟아내기 화면: 담기 전 미리보기·확인용).
  VoiceResult classify(String rawText, {DateTime? now}) =>
      router.analyze(rawText, now: now);

  /// [result] 를 [target] 지점으로 바꾼 새 결과(슬롯·시간 유지). 사용자가 확인
  /// 단계에서 고치는 것이므로 §11-1 학습 신호로도 기록한다(다음부터 그리로 가점).
  VoiceResult reroute(VoiceResult result, RoutePoint target) {
    final intent = _intentForRoute(target);
    router.recordCorrection(result, intent);
    return _forceResult(result, intent, target);
  }

  /// 저장된 쏟아내기 항목 복원용: 원문을 다시 분류하고, 사용자가 골라둔
  /// [route] 로 강제한다. 앱 재시작 복원 경로이므로 **학습은 기록하지 않는다**
  /// (교정 학습은 [reroute] 시점에 이미 한 번 반영됨 — 중복 가점 방지).
  VoiceResult restage(String rawText, RoutePoint route, {DateTime? now}) {
    final base = router.analyze(rawText, now: now);
    if (route == base.routedTo) return base;
    return _forceResult(base, _intentForRoute(route), route);
  }

  /// [result] 대로 실제로 담는다(스테이징 커밋). 보류함 지점이면 원문을 보류함에.
  Future<void> commit(VoiceResult result) async {
    if (result.decision == RouteDecision.inbox ||
        result.routedTo == RoutePoint.inbox) {
      inbox.add(result.rawText, sttConfidence: null);
    } else {
      await executor.createEntity(result);
    }
  }

  // ---------------------------------------------------------------- helpers

  /// 현재 착지 외의 유력 대안 1~2개(§11-4). 추가형 위주로 흔한 오분류 짝을 제시.
  List<RoutePoint> _reclassifyChips(VoiceResult r) {
    const candidates = [
      RoutePoint.schedule,
      RoutePoint.matrix,
      RoutePoint.quickCapture,
    ];
    return candidates.where((c) => c != r.routedTo).take(2).toList();
  }

  IntentType _intentForRoute(RoutePoint route) => switch (route) {
        RoutePoint.schedule => IntentType.scheduleAdd,
        RoutePoint.matrix => IntentType.todoMatrix,
        RoutePoint.quickCapture => IntentType.todoAdd,
        RoutePoint.logNow => IntentType.logNow,
        RoutePoint.habit => IntentType.habitAdd,
        RoutePoint.routine => IntentType.routineAdd,
        RoutePoint.goal => IntentType.goalAdd,
        RoutePoint.goalToday => IntentType.goalToday,
        RoutePoint.focus => IntentType.focusStart,
        _ => IntentType.todoAdd,
      };

  /// 재분류용으로 인텐트/라우팅만 바꾼 결과를 만든다(슬롯·시간은 유지).
  VoiceResult _forceResult(
          VoiceResult base, IntentType intent, RoutePoint route) =>
      VoiceResult(
        rawText: base.rawText,
        normalizedText: base.normalizedText,
        intent: intent,
        score: base.score,
        runnerUpGap: base.runnerUpGap,
        decision: RouteDecision.confirm,
        routedTo: route,
        slots: base.slots,
        timeParse: base.timeParse,
      );
}
