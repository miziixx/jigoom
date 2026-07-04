import type { NameEvaluation } from "../lib/naming";

export const NAMING_SYSTEM_PROMPT = [
  "당신은 전통 작명 관점의 계산 결과를 사용자가 이해하기 쉬운 생활 언어로 번역하는 이름 감정 해설가다.",
  "계산 자체를 새로 만들거나, 제공되지 않은 한자 뜻·자원오행·획수를 꾸며내지 않는다.",
  "사용자가 입력한 이름을 나쁜 이름, 불행한 이름, 피해야 할 이름으로 단정하지 않는다.",
  "발음오행, 사주 보완 기운, 수리성명학은 전통 해석 관점의 참고 자료라고 설명한다.",
  "공포감, 운명 단정, 부모에게 죄책감을 주는 표현을 쓰지 않는다.",
  "좋다/나쁘다로 끝내지 말고, 어떤 점을 살리고 어떤 점을 보완하면 좋은지 현실 행동으로 연결한다.",
  "한자어를 남발하지 말고 쉬운 말을 먼저 쓴다. 전문 용어는 '전문가 근거 보기'에 보존한다.",
  "마크다운 표는 쓰지 않는다. 제목과 bullet은 사용할 수 있다.",
].join("\n");

export function buildNamingUserMessage(evaluation: NameEvaluation): string {
  const soundLines = evaluation.sound.syllables
    .map((s) => `- ${s.syllable}: 초성 ${s.choseong}, 발음오행 ${s.elementLabel}`)
    .join("\n");
  const relationLines =
    evaluation.sound.relations.length > 0
      ? evaluation.sound.relations.map((r) => `- ${r.from} → ${r.to}: ${r.relation}`).join("\n")
      : "- 인접 음절 관계 없음";
  const suriLines = evaluation.suri
    ? evaluation.suri.levels.map((l) => `- ${l.name}: ${l.total}획, ${l.level}`).join("\n")
    : "- 한자 획수 미입력: 수리 판단은 하지 않음";

  return [
    "[요청]",
    "아래 이름 감정 계산 결과만 근거로 사용해, 사용자에게 보여줄 이름 해석 리포트를 작성해라.",
    "계산되지 않은 자원오행, 한자 뜻, 실제 법적 작명 적합성은 말하지 마라.",
    "",
    "[출력 구조]",
    "# 한 줄 결론",
    "# 쉬운 풀이",
    "# 현실에서 느껴지는 인상",
    "# 보완하면 더 좋아지는 점",
    "# 이름을 쓸 때의 팁",
    "# 전문가 근거 보기",
    "",
    "[분량]",
    "전체 1100~1700자. 짧은 bullet을 섞어 읽기 좋게 써라.",
    "",
    "[계산 결과]",
    `이름: ${evaluation.name}`,
    `발음오행 기준: ${evaluation.schoolLabel}`,
    `종합 판정: ${evaluation.overall}`,
    `헤드라인: ${evaluation.headline}`,
    "",
    "[소리의 기운]",
    soundLines,
    `발음오행 흐름 판정: ${evaluation.sound.harmony}`,
    `발음오행 메모: ${evaluation.sound.note}`,
    "",
    "[음절 사이 관계]",
    relationLines,
    "",
    "[사주 보완 적합도]",
    `보완하면 좋은 기운: ${evaluation.fit.neededLabel}`,
    `과하면 부담이 되는 기운: ${evaluation.fit.avoidLabel ?? "없음"}`,
    `보완 기운을 직접 담는가: ${evaluation.fit.suppliesNeeded ? "예" : "아니오"}`,
    `보완 기운을 상생으로 살리는가: ${evaluation.fit.supportsNeeded ? "예" : "아니오"}`,
    `부담 기운으로 쏠리는가: ${evaluation.fit.leansAvoid ? "예" : "아니오"}`,
    `사주 적합도: ${evaluation.fit.level}`,
    `사주 적합도 메모: ${evaluation.fit.note}`,
    "",
    "[획수 수리]",
    suriLines,
    evaluation.suri ? `수리 요약: ${evaluation.suri.summary}` : "수리 요약: 획수 미입력으로 생략",
    "",
    "[주의]",
    "이름은 절대적인 길흉 판정이 아니라, 불릴 때의 소리 흐름과 사주 보완 관점의 참고 자료라고 자연스럽게 설명해라.",
  ].join("\n");
}
