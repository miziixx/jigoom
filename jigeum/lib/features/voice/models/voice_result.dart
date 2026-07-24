/// 음성 파이프라인의 단계별 산출물 타입. 기획서 §1 파이프라인 ④~⑥.
///
/// 커밋1(뼈대)에서는 타입만 정의한다. 채우는 주체:
///  - [IntentScore] : 커밋6 IntentClassifier
///  - [VoiceSlots]  : 커밋7 SlotExtractor
///  - [RouteDecision]/[VoiceResult] : 커밋8 VoiceRouter
library;

import 'intent_type.dart';
import 'time_parse_result.dart';

/// §2 세 갈래 라우팅 결정.
enum RouteDecision {
  /// 점수 S>=CONFIRM 이고 격차 D>=1 → 해당 입력지점으로 확정 실행.
  confirm,

  /// 후보는 있으나 확신 부족(S 낮거나 D 애매) → 빠른담기(A).
  quickCapture,

  /// 아무 단서도 못 잡음(S==0) → 보류함.
  inbox,
}

/// 인텐트 분류기(커밋6) 출력: 최고점 인텐트 + 점수 + 2등과의 격차.
class IntentScore {
  const IntentScore({
    required this.intent,
    required this.score,
    required this.runnerUpGap,
  });

  /// 아무것도 못 잡은 결과(S==0).
  static const IntentScore none =
      IntentScore(intent: IntentType.none, score: 0, runnerUpGap: 0);

  /// 최고점 인텐트.
  final IntentType intent;

  /// 최고점 S.
  final int score;

  /// 2등과의 점수 격차 D(2등이 없으면 score 그대로).
  final int runnerUpGap;
}

/// 인텐트별로 채워지는 슬롯 모음(§3-1 "뽑는 슬롯"). 필요한 것만 채운다.
class VoiceSlots {
  const VoiceSlots({
    this.title,
    this.important = false,
    this.urgent = false,
    this.groupName,
    this.stepName,
    this.durationMin,
    this.date,
    this.time,
    this.habitName,
    this.text,
    this.navDest,
    this.amount,
  });

  /// 제목/내용(일정·할일·기록·목표 공용).
  final String? title;

  /// 매트릭스 중요 축.
  final bool important;

  /// 매트릭스 긴급 축.
  final bool urgent;

  /// 루틴 그룹명(예: "아침").
  final String? groupName;

  /// 루틴 스텝(예: "스트레칭").
  final String? stepName;

  /// 포커스/기록 기간(분).
  final int? durationMin;

  /// 일정 날짜.
  final DateTime? date;

  /// 일정 시각.
  final ParsedTime? time;

  /// 습관명(추가/체크 대상).
  final String? habitName;

  /// 오늘의목표 텍스트.
  final String? text;

  /// 이동 목적지(nav.move).
  final String? navDest;

  /// 금액(원). 지출·결제 발화에서 뽑는다(§13). 없으면 null.
  final int? amount;

  VoiceSlots copyWith({
    String? title,
    bool? important,
    bool? urgent,
    String? groupName,
    String? stepName,
    int? durationMin,
    DateTime? date,
    ParsedTime? time,
    String? habitName,
    String? text,
    String? navDest,
    int? amount,
  }) =>
      VoiceSlots(
        title: title ?? this.title,
        important: important ?? this.important,
        urgent: urgent ?? this.urgent,
        groupName: groupName ?? this.groupName,
        stepName: stepName ?? this.stepName,
        durationMin: durationMin ?? this.durationMin,
        date: date ?? this.date,
        time: time ?? this.time,
        habitName: habitName ?? this.habitName,
        text: text ?? this.text,
        navDest: navDest ?? this.navDest,
        amount: amount ?? this.amount,
      );
}

/// 파이프라인 전체 결과 — 라우터가 이걸 만들어 실행/피드백에 쓴다.
class VoiceResult {
  const VoiceResult({
    required this.rawText,
    required this.normalizedText,
    required this.intent,
    required this.score,
    required this.runnerUpGap,
    required this.decision,
    required this.routedTo,
    required this.slots,
    required this.timeParse,
  });

  /// 사용자가 말한 원문(보류함 저장·되돌리기용).
  final String rawText;

  /// 정규화된 텍스트.
  final String normalizedText;

  /// 최종 인텐트.
  final IntentType intent;

  /// 최고점 S.
  final int score;

  /// 2등 격차 D.
  final int runnerUpGap;

  /// 세 갈래 결정.
  final RouteDecision decision;

  /// 최종 착지 지점.
  final RoutePoint routedTo;

  /// 뽑힌 슬롯.
  final VoiceSlots slots;

  /// 날짜·시간 파싱 결과.
  final TimeParseResult timeParse;

  @override
  String toString() => 'VoiceResult(intent: ${intent.code}, score: $score, '
      'gap: $runnerUpGap, decision: $decision, routedTo: ${routedTo.label})';
}
