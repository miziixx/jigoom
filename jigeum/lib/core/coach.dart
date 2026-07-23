/// 코치 다중 페르소나 — 같은 상황을 다른 톤으로 말해준다.
/// LLM 없이 규칙 기반 템플릿. 사용자가 자기에게 맞는 목소리를 고른다.

class CoachPersona {
  const CoachPersona(this.key, this.name, this.desc);
  final String key;
  final String name; // 표시 이름
  final String desc; // 한 줄 설명
}

const kCoachPersonas = <CoachPersona>[
  CoachPersona('warm', '격려형', '"괜찮아, 잘하고 있어"'),
  CoachPersona('calm', '차분형', '"천천히, 하나씩"'),
  CoachPersona('analyst', '분석형', '"지금 상황은 이래"'),
  CoachPersona('firm', '단호형', '"딱 2분, 지금"'),
];

const kDefaultCoachKey = 'warm';

CoachPersona coachOf(String key) =>
    kCoachPersonas.firstWhere((p) => p.key == key,
        orElse: () => kCoachPersonas.first);

/// 코치 컨텍스트 — 오늘 상태를 담아 톤별 한마디를 만든다.
class CoachContext {
  const CoachContext({
    required this.partOfDay, // '아침'|'낮'|'오후'|'저녁'|'밤'|'새벽'
    required this.pending, // 남은 할 일 수
    required this.startedToday, // 오늘 시작 횟수
    required this.streak, // 연속 물 준 날
    this.peakLabel, // 집중 피크 창(있으면)
    this.inPeakNow = false, // 지금이 피크 시간대인가
  });

  final String partOfDay;
  final int pending;
  final int startedToday;
  final int streak;
  final String? peakLabel;
  final bool inPeakNow;
}

/// 페르소나 + 컨텍스트 → 코치 한마디(한 줄).
String coachLine(String personaKey, CoachContext c) {
  // 우선순위: 지금 피크 → 연속기록 → 시작함 → 시작 전.
  switch (personaKey) {
    case 'calm':
      if (c.inPeakNow) return '지금이 좋은 때예요. 천천히 하나만.';
      if (c.startedToday > 0) return '벌써 움직였네요. 이 흐름 그대로.';
      if (c.streak >= 2) return '${c.streak}일째 이어가는 중. 오늘도 가볍게.';
      return '${c.partOfDay}이네요. 딱 하나만 골라볼까요.';
    case 'analyst':
      if (c.peakLabel != null && c.inPeakNow) {
        return '지금은 집중 피크(${c.peakLabel}). 어려운 일에 유리해요.';
      }
      if (c.peakLabel != null) return '당신의 집중 피크는 ${c.peakLabel}.';
      if (c.pending > 0) return '남은 일 ${c.pending}개. 가장 작은 것부터 표시됩니다.';
      return '데이터가 쌓이면 최적 시간대를 알려줄게요.';
    case 'firm':
      if (c.pending > 0) return '딱 2분. 가장 위의 것, 지금 시작.';
      if (c.startedToday > 0) return '${c.startedToday}번 시작. 한 번 더.';
      return '고민은 그만. 하나 적고 바로 시작.';
    case 'warm':
    default:
      if (c.inPeakNow) return '지금 컨디션 좋을 때예요. 잘 골랐어!';
      if (c.streak >= 2) return '${c.streak}일 연속이라니, 대단해 🌱';
      if (c.startedToday > 0) return '오늘 ${c.startedToday}번이나 시작했어. 충분해.';
      if (c.pending > 0) return '괜찮아, 딱 하나만 시작해보자.';
      return '천천히 와도 돼. 오늘도 반가워.';
  }
}
