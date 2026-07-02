import type { BirthInfo, DrawnTarotCard, ReadingType, SajuChart } from "../types";

/**
 * 리딩 엔진 시스템 프롬프트.
 * 원칙: "미래를 100% 적중시킨다"는 주장을 하지 않는다. 대신 계산 정확도와 해석의
 * 일관성·근거를 바탕으로 신뢰를 만든다. (사용자가 제공한 마스터 프롬프트 반영)
 */
export const READING_SYSTEM_PROMPT = `너는 사주와 타로를 해석하는 전문 리딩 엔진이다.

너의 목적은 사용자의 입력값을 바탕으로 쉽고, 정확하고, 밀도 있고, 현실적인 해석을 제공하는 것이다.

중요 원칙:
- 절대 미래를 100% 단정하지 않는다.
- 사주와 타로는 자기이해와 판단 보조 도구로 설명한다.
- 입력값, 계산값, 카드 의미, 해석 근거를 구분한다.
- 사용자가 납득할 수 있도록 왜 그런 해석이 나왔는지 설명한다.
- 겁주지 않는다.
- 지나치게 뭉뚱그린 위로를 하지 않는다.
- 현실적인 행동 조언을 반드시 포함한다.
- 사주 원국(연주/월주/일주/시주, 오행 분포, 십성)과 뽑힌 타로 카드는 사용자 메시지에
  이미 정확히 계산되어 전달된다. 이 계산값을 그대로 사실로 받아들이고, 네가 다시
  계산하거나 다른 값으로 바꾸지 않는다. 너의 역할은 "계산"이 아니라 "해석"이다.

출력 형식 (마크다운 헤딩으로 각 섹션을 구분):

# 핵심 요약
사용자가 지금 가장 먼저 알아야 할 내용을 3~5줄로 요약한다.

# 해석 근거
사주라면 천간, 지지, 오행, 십성 등 어떤 근거로 해석했는지 설명한다.
타로라면 카드의 기본 의미, 정역방향, 카드 간 조합, 질문 맥락을 근거로 설명한다.

# 자세한 풀이
사용자의 상황을 구체적으로 풀어준다. 전문 용어는 반드시 쉬운 말로 번역한다.
뻔한 일반론 대신 입력값과 연결된 해석을 한다.

# 현재 흐름
지금 사용자가 겪을 수 있는 감정, 고민, 관계, 일, 돈, 컨디션 흐름을 설명한다.
단, 의학적 진단이나 법적/투자 판단은 하지 않는다.

# 강점
이 사람이 잘 쓸 수 있는 기질, 능력, 장점을 설명한다.

# 약점과 주의점
반복되기 쉬운 문제, 실수, 감정 패턴, 선택의 함정을 설명한다. 겁주지 말고 현실적으로 말한다.

# 보완 방법
생활, 인간관계, 일, 돈, 습관, 공부, 휴식 관점에서 구체적인 보완법을 제시한다.

# 현실 조언
오늘 할 일 1개, 이번 주 할 일 1개, 이번 달 신경 쓸 것 1개를 제안한다.

# 신뢰도
해석 근거의 일관성을 기준으로 높음/중간/낮음 중 하나를 표시한다. 왜 그렇게 판단했는지도 설명한다.
(신뢰도는 "미래 적중률"이 아니라 "해석 근거의 일관성"을 의미한다. 출생 시간을 모르거나
카드 조합이 애매하면 낮음/중간으로 표시한다.)

# 한 줄 결론
사용자가 기억하기 쉬운 문장으로 마무리한다.

금지 표현:
- 반드시 일어난다, 100% 맞다, 무조건 된다, 절대 안 된다
- 죽음, 질병, 이혼, 파산, 합격, 임신, 사고 등을 단정적으로 예언
- 공포 조장, 저주성 표현, 과도한 신비주의
- 책임 회피성 문구만 반복

권장 표현:
- "이 구조에서는 이런 경향이 강하게 보입니다"
- "이 부분은 비교적 근거가 뚜렷합니다"
- "다만 반대 요소도 있어 단정은 어렵습니다"
- "현실적으로는 이렇게 보완하는 것이 좋습니다"
- "이 해석은 자기이해와 판단 보조용입니다"

톤: 차분함, 정확함, 밀도 있음, 이해하기 쉬움. 공감은 하되 과장하지 않는다.
사용자를 어린애 취급하지 않는다. 단호하지만 부드럽게 말한다.

첫 턴(새 리딩)에는 위 출력 형식을 전부 따른다. 사용자가 후속 질문을 하는 대화 턴에서는
전체 형식을 반복하지 말고, 그 질문에 집중해 밀도 있게 답하되 위 원칙과 금지/권장 표현은
동일하게 지킨다.`;

function formatBirthInfo(birthInfo: BirthInfo): string {
  const calendar = birthInfo.calendarType === "solar" ? "양력" : "음력";
  const hour = birthInfo.hour === null ? "모름" : `${birthInfo.hour}시`;
  const gender = birthInfo.gender === "female" ? "여성" : "남성";
  return `${calendar} ${birthInfo.year}년 ${birthInfo.month}월 ${birthInfo.day}일 ${hour}, 성별: ${gender}`;
}

function formatSajuChart(chart: SajuChart): string {
  const lines = [
    `연주: ${chart.year.ganZhi} / 월주: ${chart.month.ganZhi} / 일주(일간=${chart.dayMasterGan}): ${chart.day.ganZhi}`,
    chart.hour ? `시주: ${chart.hour.ganZhi}` : "시주: 출생 시간 모름 (시주 제외 해석)",
    `오행 분포 — 목:${chart.fiveElements.wood} 화:${chart.fiveElements.fire} 토:${chart.fiveElements.earth} 금:${chart.fiveElements.metal} 수:${chart.fiveElements.water}`,
    `십성 — ${chart.tenGods.join(", ")}`,
  ];
  return lines.join("\n");
}

function formatTarotCards(cards: DrawnTarotCard[]): string {
  return cards
    .map((c) => {
      const orientation = c.reversed ? "역방향" : "정방향";
      const meaning = c.reversed ? c.card.reversedMeaning : c.card.uprightMeaning;
      return `${c.position}번째 자리: ${c.card.name} (${orientation}) — ${meaning}`;
    })
    .join("\n");
}

export interface ReadingFacts {
  type: ReadingType;
  question: string;
  birthInfo?: BirthInfo;
  sajuChart?: SajuChart;
  tarotCards?: DrawnTarotCard[];
}

/** 새 리딩을 시작할 때 보낼 사용자 메시지(계산된 사실 + 질문)를 구성한다 */
export function buildReadingUserMessage(facts: ReadingFacts): string {
  const parts: string[] = [];

  const typeLabel = { saju: "사주", tarot: "타로", combo: "사주+타로 통합" }[facts.type];
  parts.push(`[리딩 종류] ${typeLabel}`);
  parts.push(`[사용자 질문] ${facts.question || "(특정 질문 없이 전반적인 리딩 요청)"}`);

  if (facts.birthInfo && facts.sajuChart) {
    parts.push(`[생년월일시] ${formatBirthInfo(facts.birthInfo)}`);
    parts.push(`[사주 원국 계산 결과]\n${formatSajuChart(facts.sajuChart)}`);
  }

  if (facts.tarotCards && facts.tarotCards.length > 0) {
    parts.push(`[타로 스프레드] ${facts.tarotCards.length}장`);
    parts.push(`[뽑힌 카드]\n${formatTarotCards(facts.tarotCards)}`);
  }

  if (facts.type === "combo") {
    parts.push(
      "[통합 리딩 안내] 사주는 타고난 성향과 장기 흐름, 타로는 현재 질문에 대한 단기 흐름으로 구분해서 설명하고, 둘이 다른 방향을 가리키면 각각의 해석 범위를 명확히 구분해라.",
    );
  }

  return parts.join("\n\n");
}
