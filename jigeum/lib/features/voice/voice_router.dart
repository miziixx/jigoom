/// 음성 라우터. 기획서 §1(파이프라인)·§2(세 갈래 결정) + §5 커밋8.
///
/// 최상위 진입점: 원문 텍스트 → [VoiceResult]. 정규화 → 시간파싱 → 분류 →
/// 슬롯추출 → **세 갈래 라우팅 결정**까지의 순수 오케스트레이션을 담당한다.
///
///   S == 0                      → 보류함(inbox)      : 아무 단서도 못 잡음
///   S >= CONFIRM 그리고 D >= GAP → 확정(해당 A~J)     : 유력 + 경쟁자와 벌어짐
///   그 외(S 낮거나 D 애매)       → 빠른담기(A)         : 뭔가 있으나 애매
///
/// 실제 엔티티 생성(A~J repository 호출)·보류함 저장은 앱 계층(커밋9~10)에서
/// [VoiceResult] 를 받아 수행한다. 여기서는 **결정만** 내려 순수 Dart 로 남긴다
/// (프레임워크 비의존 → 빠른 단위 테스트).
library;

import 'learning/user_lexicon.dart';
import 'models/intent_type.dart';
import 'models/voice_result.dart';
import 'pipeline/intent_classifier.dart';
import 'pipeline/ko_datetime_parser.dart';
import 'pipeline/slot_extractor.dart';
import 'pipeline/text_normalizer.dart';
import 'voice_constants.dart';

class VoiceRouter {
  VoiceRouter({
    this.normalizer = const TextNormalizer(),
    this.parser = const KoDateTimeParser(),
    Set<String> knownHabits = const <String>{},
    UserLexicon? learning,
  })  : classifier = IntentClassifier(knownHabits: knownHabits),
        extractor = SlotExtractor(knownHabits: knownHabits),
        learning = learning ?? UserLexicon();

  final TextNormalizer normalizer;
  final KoDateTimeParser parser;
  final IntentClassifier classifier;
  final SlotExtractor extractor;

  /// §11-1 개인화 자동학습 사전. 되돌리기·재분류를 세어 다음 분류에 반영한다.
  final UserLexicon learning;

  /// 원문 [raw] 를 전 구간 통과시켜 라우팅 결정을 담은 [VoiceResult] 를 만든다.
  /// [now] 는 날짜 파싱 기준(테스트 주입용).
  VoiceResult analyze(String raw, {DateTime? now}) {
    final normalized = normalizer.normalize(raw);
    final tp = parser.parse(normalized, now: now);
    final cls = classifier.classify(normalized, tp,
        userLexicon: learning.activeEntries());

    final decision = _decide(cls);

    // 보류함으로 갈 땐 인텐트를 none 으로 못박고 슬롯은 비운다(원문만 저장).
    final intent =
        decision == RouteDecision.inbox ? IntentType.none : cls.intent;
    final slots = decision == RouteDecision.inbox
        ? const VoiceSlots()
        : extractor.extract(intent, normalized, tp);

    final routedTo = switch (decision) {
      RouteDecision.inbox => RoutePoint.inbox,
      RouteDecision.quickCapture => RoutePoint.quickCapture,
      RouteDecision.confirm => defaultRoutePointOf(intent),
    };

    return VoiceResult(
      rawText: raw,
      normalizedText: normalized,
      intent: intent,
      score: cls.score,
      runnerUpGap: cls.runnerUpGap,
      decision: decision,
      routedTo: routedTo,
      slots: slots,
      timeParse: tp,
    );
  }

  /// 되돌리기·재분류·"다르게 담기" 교정 1건을 학습에 기록한다(§11-1).
  ///
  /// 키는 제목(없으면 정규화문)을 쓴다. 같은 표현이 임계(기본 3회) 같은 인텐트로
  /// 교정되면 다음부터 분류기가 그 인텐트에 가점한다.
  void recordCorrection(VoiceResult result, IntentType finalIntent,
      {DateTime? at}) {
    final key = (result.slots.title?.trim().isNotEmpty ?? false)
        ? result.slots.title!.trim()
        : result.normalizedText;
    learning.record(key, finalIntent, at: at);
  }

  /// §2 세 갈래 결정.
  RouteDecision _decide(IntentScore cls) {
    if (cls.score == 0 || cls.intent == IntentType.none) {
      return RouteDecision.inbox;
    }
    if (cls.score >= VoiceThresholds.confirm &&
        cls.runnerUpGap >= VoiceThresholds.minGap) {
      return RouteDecision.confirm;
    }
    return RouteDecision.quickCapture;
  }
}
