import type {
  BirthInfo,
  DrawnTarotCard,
  LuckCycles,
  ReadingContext,
  ReadingFocus,
  ReadingType,
  SajuChart,
} from "../types/index.js";

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
- 사주 원국(연주/월주/일주/시주, 오행·음양 분포, 천간·지지 십성, 지장간, 합충형파해,
  신강/신약, 용신 후보)과 뽑힌 타로 카드는 사용자 메시지에 이미 정확히 계산되어
  전달된다. 이 계산값을 그대로 사실로 받아들이고, 네가 다시 계산하거나 다른 값으로
  바꾸지 않는다. 특히 전달된 목록에 없는 합·충·형·파·해를 새로 만들어내지 마라.
  신강/신약과 용신은 "간이 판정·후보"로 전달되므로 단정하지 말고 참고 근거로 써라.
  너의 역할은 "계산"이 아니라 "해석"이다.
- '핵심 요약', '분야별 요약', '현실 조언', '한 줄 결론' 섹션에서는 사주 전문용어
  (간지·십성 이름·합충형파해·신살·오행 명칭 등)를 쓰지 않고 쉬운 말로만 설명한다.
  전문 용어는 '해석 근거'와 '자세한 풀이'에서만 쓰되, 반드시 바로 뒤에 괄호로
  쉬운 설명을 붙인다 (예: "편관(나를 압박하는 힘)").

출력 형식 (마크다운 헤딩으로 각 섹션을 구분):

# 핵심 요약
사용자가 지금 가장 먼저 알아야 할 내용을 3~5줄로 요약한다. 전문 용어 없이 쉬운 말로만 쓴다.

# 분야별 요약
아래 4개 영역을 정해진 형식으로, 반드시 이 순서로 한 줄씩 출력한다. 전문 용어 없이 쉬운 말로만 쓴다.
- 직업·재물: 평가 [좋음|보통|주의] — 한 줄 코멘트
- 애정·관계: 평가 [좋음|보통|주의] — 한 줄 코멘트
- 건강·컨디션: 평가 [좋음|보통|주의] — 한 줄 코멘트
- 멘탈·감정: 평가 [좋음|보통|주의] — 한 줄 코멘트
형식을 정확히 지켜라. 반드시 "- 영역명: 평가 [좋음|보통|주의] — 코멘트" 줄 형태여야 하고,
영역명·구분자·순서를 바꾸지 마라. 좋음/주의 평가가 최소 1개씩은 나오도록 균형 있게 판단하되,
근거 없이 억지로 만들어내지 마라.

# 해석 근거
사주라면 천간, 지지, 오행, 십성 등 어떤 근거로 해석했는지 설명한다.
타로라면 카드의 기본 의미, 정역방향, 카드 간 조합, 질문 맥락을 근거로 설명한다.

# 반대 근거
위 해석과 반대 방향을 가리키는 요소(오행/십성/합충/카드)를 최소 1개 이상 솔직하게 짚는다.
그 반대 요소 때문에 해석의 어느 부분이 유동적인지, 어떤 조건에서 다르게 흘러갈 수 있는지 밝힌다.
정말 뚜렷한 반대 근거가 없으면 "특별한 반대 근거 없음"이라고 쓰되 왜 없는지 이유를 설명한다.
같은 방향의 근거가 3개 이상 겹칠 때만 강한 어조를 쓰고, 근거가 1~2개면 경향 수준으로만 말한다.

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
해석 근거의 일관성을 기준으로 높음/중간/낮음 중 하나를 표시하고, 왜 그렇게 판단했는지 설명한다.
(신뢰도는 "미래 적중률"이 아니라 "해석 근거의 일관성"을 의미한다.)
판정 기준:
- 높음: 계산값이 명확하고, 출생 시간이 정확하고, 서로 다른 근거 3개 이상이 같은 방향을 가리키고, 질문이 구체적이고, 카드 조합이 일관될 때만.
- 중간: 근거는 있으나 반대 요소도 있음 / 질문이 다소 넓음 / 출생 시간은 있으나 오차 가능성 있음 / 카드 흐름이 섞여 있음.
- 낮음: 출생 시간이 없거나 매우 부정확함 / 질문이 모호함 / 카드 조합이 상반됨 / 사주와 타로가 다른 방향을 가리킴 / 상황 정보 부족.
출생 시간이 없거나 부정확하면 어떤 해석 영역(성향 세부, 말년 흐름, 시기 판단 등)의 신뢰도가 낮아지는지 구체적으로 명시한다.
신뢰도가 낮은 부분은 본문에서도 단정을 피하고, 신뢰도가 높은 부분(성향 구조 등)과 구분해서 말한다.

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

핵심 해석 문장 구조 (중요한 해석일수록 이 5단계를 따라라):
1. 관찰 — "이 사주는 토 기운이 강하고 수 기운이 약한 편입니다." (계산값 인용)
2. 의미 — "그래서 현실감각과 버티는 힘은 있지만 감정 순환이 막히면 답답함이 오래 갈 수 있습니다."
3. 실제 모습 — "겉으로는 괜찮은 척하는데, 안에서는 생각이 뭉쳐서 몸이 무거워지는 식으로 나타날 수 있습니다."
4. 주의점 — "이럴 때 억지로 의욕을 끌어올리려 하면 오히려 더 지칠 수 있습니다."
5. 보완 — "수면, 산책, 기록처럼 흐름을 풀어주는 행동을 작게 반복하는 편이 좋습니다."
모든 문장에 강제할 필요는 없지만, 각 섹션의 핵심 주장 1~2개는 반드시 이 구조로 완결시켜라.

공감 품질 규칙:
- 나쁜 예: "당신은 너무 힘들었겠어요. 우주는 당신을 사랑합니다." (감정 과장 + 근거 없는 위로)
- 좋은 예: "이 구조는 생각이 많아질수록 몸이 먼저 지치는 패턴으로 나타나기 쉽습니다. 그래서
  마음의 문제가 아니라, 에너지를 쓰는 방식 자체를 조정해야 편해집니다." (구체적 상황 + 바로 현실 조언)
- 사용자의 상황을 구체적으로 짚되 감정을 과장하지 않고, 원인을 단정하지 않으며,
  공감 뒤에는 반드시 현실 조언으로 연결한다. 사용자를 약한 사람처럼 다루지 않는다.
- "가능성이 있습니다"만 반복하지 마라. 왜 그런 가능성이 생기는지 구조로 설명해라.

밀도 기준 (전문 상담 수준을 요구한다):
- 모든 해석 문장은 전달된 원국의 실제 글자를 근거로 인용해라.
  (좋은 예: "월지 자수가 일간 임수를 돕는 겁재라서..." / 나쁜 예: "당신은 물의 기운이 강해서...")
- 사주 리딩이라면 다음 재료를 최소 한 번씩은 해석에 활용해라: 일간과 월지(계절)의 관계,
  십성 배치가 만드는 성격 구조, 지장간이 암시하는 이면, 합충형파해가 만드는 역동,
  12운성 흐름, 공망, 신강약과 용신 후보, 현재 운과 원국의 상호작용.
- 각 섹션은 "근거 → 풀이 → 그래서 현실에서 어떻게"의 순서로 쓴다.
- 뻔한 덕담으로 분량을 채우지 마라. 같은 말을 반복하지 마라.
- 전문 용어를 쓸 때는 바로 뒤에 괄호로 쉬운 설명을 붙여라. 예: "편관(나를 압박하는 힘)".

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
    `천간 십성 — ${chart.tenGods.join(", ")}`,
  ];
  if (chart.yinYang) lines.push(`음양 분포 — 양:${chart.yinYang.yang} 음:${chart.yinYang.yin}`);
  if (chart.branchTenGods) lines.push(`지지 십성 — ${chart.branchTenGods.join(", ")}`);
  if (chart.hiddenStems) lines.push(`지장간 — ${chart.hiddenStems.join(", ")}`);
  if (chart.interactions) {
    lines.push(
      chart.interactions.length > 0
        ? `합충형파해 — ${chart.interactions.join(", ")}`
        : "합충형파해 — 원국 내 해당 없음",
    );
  }
  if (chart.strength) {
    lines.push(`신강/신약 (간이 억부 판정) — ${chart.strength.label} (${chart.strength.detail})`);
  }
  if (chart.gyeokguk) {
    lines.push(`격국 (참고용) — ${chart.gyeokguk.name} · 근거: ${chart.gyeokguk.basis}`);
  }
  if (chart.yongshin) {
    const yong = (chart.yongshin.yongshin ?? chart.yongshin.supportive).join("·");
    const hee = chart.yongshin.heesin && chart.yongshin.heesin.length > 0 ? ` / 희신: ${chart.yongshin.heesin.join("·")}` : "";
    lines.push(
      `용신 후보 — 용신: ${yong}${hee}${chart.yongshin.unfavorable.length > 0 ? ` / 기신 후보: ${chart.yongshin.unfavorable.join("·")}` : ""} (${chart.yongshin.note})`,
    );
  }
  if (chart.twelveStages) lines.push(`12운성 (일간 기준) — ${chart.twelveStages.join(", ")}`);
  if (chart.gongmang) lines.push(`공망 — ${chart.gongmang}`);
  if (chart.sinsal && chart.sinsal.length > 0) {
    lines.push(`신살 — ${chart.sinsal.map((s) => `${s.name}(${s.position}: ${s.gloss})`).join(", ")}`);
  }
  if (chart.iljuTrait) lines.push(`일주(${chart.day.ganZhi}) 성향 참고 — ${chart.iljuTrait}`);
  if (chart.seasonNote) lines.push(`조후(계절) — ${chart.seasonNote}`);
  if (chart.timeCorrection) {
    if (chart.timeCorrection.applied.length > 0)
      lines.push(
        `시각 보정 — ${chart.timeCorrection.applied.join(", ")} → 보정 후 ${chart.timeCorrection.correctedDateTime} 기준으로 계산됨`,
      );
    if (chart.timeCorrection.boundaryWarning)
      lines.push(`⚠ 시주 경계 경고 — ${chart.timeCorrection.boundaryWarning} 해석에서 이 불확실성을 반드시 언급해라.`);
  }
  return lines.join("\n");
}

function formatTarotCards(cards: DrawnTarotCard[]): string {
  return cards
    .map((c) => {
      const orientation = c.reversed ? "역방향" : "정방향";
      const meaning = c.reversed ? c.card.reversedMeaning : c.card.uprightMeaning;
      const label = c.positionLabel ? ` [${c.positionLabel}]` : "";
      return `${c.position}번째 자리${label}: ${c.card.name} (${orientation}) — ${meaning}`;
    })
    .join("\n");
}

function formatLuckCycles(luck: LuckCycles): string {
  const daYunLines = luck.daYun
    .map((dy) => `${dy.startAge}세~${dy.endAge}세 ${dy.ganZhi} (${dy.startYear}~${dy.endYear})${dy.current ? " ← 현재" : ""}`)
    .join(" / ");
  const lines = [
    `대운 흐름: ${daYunLines}`,
    `현재 대운: ${luck.currentDaYun ?? "대운 시작 전"}`,
    `세운(올해 ${luck.year}년, 입춘 기준): ${luck.yearGanZhi}`,
    `월운(이번 달 ${luck.month}월, 절기 기준): ${luck.monthGanZhi}`,
  ];
  if (luck.dayGanZhi) lines.push(`오늘 일진: ${luck.dayGanZhi}`);
  if (luck.luckInteractions) {
    lines.push(
      luck.luckInteractions.length > 0
        ? `운과 원국의 상호작용 (계산됨): ${luck.luckInteractions.join(", ")}`
        : "운과 원국의 상호작용 (계산됨): 현재 대운/세운/월운/일진과 원국 사이 새로 성립하는 합충형파해 없음",
    );
  }
  if (luck.yearlyFlow && luck.yearlyFlow.length > 0) {
    const yearLines = luck.yearlyFlow.map(
      (yf) =>
        `${yf.year}년(${yf.age}세) ${yf.ganZhi}${yf.current ? " ← 올해" : ""}${yf.interactions.length > 0 ? ` — ${yf.interactions.join(", ")}` : " — 원국과 새 상호작용 없음"}`,
    );
    lines.push(`앞으로 10년 세운 흐름 (입춘 기준, 계산됨):\n${yearLines.join("\n")}`);
  }
  if (luck.monthlyFlow && luck.monthlyFlow.length > 0) {
    const monthLines = luck.monthlyFlow.map(
      (mf) =>
        `${mf.month}월 ${mf.ganZhi}${mf.interactions.length > 0 ? ` — ${mf.interactions.join(", ")}` : " — 원국과 새 상호작용 없음"}`,
    );
    lines.push(`올해 ${luck.year}년 월별 월운 흐름 (절기 기준, 계산됨):\n${monthLines.join("\n")}`);
  }
  return lines.join("\n");
}

// ── 개인화 컨텍스트 → 프롬프트 지시문 ──────────

const SITUATION_LABEL: Record<NonNullable<ReadingContext["situation"]>, string> = {
  before: "시작 전 고민 중",
  ongoing: "이미 진행 중",
  waiting: "결과를 기다리는 중",
  closing: "정리해야 하는 중",
};

const TONE_INSTRUCTION: Record<NonNullable<ReadingContext["tone"]>, string> = {
  realistic: "현실적이고 담백한 톤으로. 위로보다 실질적인 판단 재료에 비중을 둬라.",
  warm: "따뜻한 톤으로. 다만 감정 과장 없이, 공감 뒤에는 반드시 현실 조언을 붙여라.",
  blunt: "냉정하고 직설적인 톤으로. 돌려 말하지 말고 약점과 리스크를 먼저 말해라. 단, 겁주기와 단정은 여전히 금지다.",
  detailed: "아주 자세하게. 각 섹션의 근거 인용과 풀이를 최대한 촘촘하게 써라.",
};

const DEPTH_INSTRUCTION: Record<NonNullable<ReadingContext["depth"]>, string> = {
  light:
    "[가벼운 리딩] 핵심 요약 / 현재 흐름 / 현실 조언 / 신뢰도 / 한 줄 결론 섹션만 출력해라. 각 섹션은 짧고 밀도 있게.",
  basic: "[기본 리딩] 표준 출력 형식을 그대로 따르되, 각 섹션을 간결하게 유지해라.",
  advanced:
    "[고급 리딩] 표준 출력 형식을 모두 따르고, 반대 근거와 보완 방법을 특히 충실히 써라. '현실 조언' 섹션에 앞으로 1개월 행동 계획(주 단위 3~4개)을 추가해라. 전체 분량은 공백 포함 4000자 내외로 하되, 반드시 '한 줄 결론'까지 완결해라.",
  expert:
    "[전문가 리딩] 표준 출력 형식을 모두 따르고, 다음을 추가해라: 계산값 인용을 최대로 하고, 해석 근거를 '강한 근거/보조 근거'로 계층화하고, 대운-세운-월운을 연결해서 시기를 해석하고, '현실 조언'에 3개월 실행 전략을 넣고, 마지막에 '이어서 물어보면 좋은 질문' 2~3개를 제안해라. 전체 분량은 공백 포함 5000~6500자 사이로 밀도 있게 쓰되, 같은 말을 반복해 분량을 늘리지 말고 반드시 마지막 섹션까지 완결해라.",
};

const TIME_ACCURACY_LABEL: Record<NonNullable<ReadingContext["timeAccuracy"]>, string> = {
  exact: "정확함",
  "half-hour": "30분 정도 오차 가능",
  "over-hour": "1시간 이상 오차 가능",
  unknown: "모름",
};

function formatContext(context: ReadingContext): string[] {
  const parts: string[] = [];

  const info: string[] = [];
  if (context.situation) info.push(`현재 상황 단계: ${SITUATION_LABEL[context.situation]}`);
  if (context.timeAccuracy) info.push(`출생 시간 정확도(사용자 응답): ${TIME_ACCURACY_LABEL[context.timeAccuracy]}`);
  if (info.length > 0) {
    parts.push(
      `[개인화 정보]\n${info.join("\n")}` +
        (context.timeAccuracy && context.timeAccuracy !== "exact"
          ? "\n출생 시간에 오차 가능성이 있으므로, 시주에 크게 의존하는 해석(성향 세부, 말년, 자식/부하 관계 등)은 신뢰도를 낮추고 그 사실을 신뢰도 섹션에 명시해라."
          : ""),
    );
  }

  const style: string[] = [];
  if (context.tone) style.push(TONE_INSTRUCTION[context.tone]);
  if (context.depth) style.push(DEPTH_INSTRUCTION[context.depth]);
  if (context.styleHint) style.push(`지난 리딩 피드백 반영 요청: ${context.styleHint}`);
  if (style.length > 0) parts.push(`[답변 스타일]\n${style.join("\n")}`);

  return parts;
}

// 포커스별로 반드시 다루도록 요구하는 상세 항목 (마스터 프롬프트의 D/E/F 섹션 반영)
const FOCUS_INSTRUCTIONS: Record<Exclude<ReadingFocus, "general">, string> = {
  career: `[해석 포커스] 직업/돈
"자세한 풀이"에서 다음을 반드시 구체적으로 다뤄라:
- 잘 맞는 일의 조건과 피해야 할 업무 환경
- 돈을 벌기 쉬운 방식과 돈을 대하는 태도
- 장기적으로 키워야 할 능력
- 현대 직업 기준의 추천 (콘텐츠, 교육, 기획, 디자인, 개발, 영업 등과의 궁합)
- 프리랜서/사업/직장 각각의 적합도
투자 수익이나 사업 성패를 단정하지 마라.`,
  relationship: `[해석 포커스] 연애/관계
"자세한 풀이"에서 다음을 반드시 구체적으로 다뤄라:
- 끌리는 사람 유형과 그 이유
- 반복되기 쉬운 관계 문제 패턴
- 안정적인 관계를 위한 조건
- 피해야 할 관계 패턴
결혼/이별/재회를 단정적으로 예언하지 마라.`,
  wellness: `[해석 포커스] 건강/컨디션
"자세한 풀이"에서 다음을 반드시 생활 관점으로 다뤄라:
- 수면, 소화, 체력, 감정 기복, 긴장도 등 컨디션이 흔들리기 쉬운 흐름
- 오행 균형에서 드러나는 취약 지점과 생활 보완법
의학적 진단이나 질병 예언은 절대 하지 마라. 증상이 있다면 병원 진료를 조심스럽게 권하는 선까지만 말한다.`,
  mental: `[해석 포커스] 멘탈/감정 흐름
"자세한 풀이"에서 다음을 반드시 구체적으로 다뤄라:
- 불안이 올라오기 쉬운 상황과 그때의 전형적인 반응 패턴
- 스트레스를 받는 방식과 푸는 방식 (원국 구조 근거로)
- 에너지가 살아나는 조건과 방전되는 조건
- 생각이 많아질 때 실제로 도움이 되는 개입 지점
심리 상담/치료를 대체한다고 말하지 마라. 상태가 심각해 보이면 전문가 상담을 조심스럽게 권해라.`,
  decision: `[해석 포커스] 선택/시기 고민
"자세한 풀이"에서 다음을 반드시 구체적으로 다뤄라:
- 이 사람이 선택할 때 반복하는 습관 (미루기/충동/타인 의존 등, 원국 근거로)
- 각 선택지가 이 사람의 구조와 현재 운 흐름에 어떻게 맞물리는지
- 결과 단정 대신 "이 선택이 잘 풀리려면 필요한 조건"
- 지금이 결정에 유리한 시기인지, 정보를 더 모아야 하는 시기인지
결정을 대신 내려주지 말고, 선택 기준을 정리해줘라.`,
};

const TYPE_LABEL: Record<ReadingType, string> = {
  saju: "사주",
  tarot: "타로",
  combo: "사주+타로 통합",
  today: "오늘의 흐름",
  flow: "월간/연간 운 흐름",
};

export interface ReadingFacts {
  type: ReadingType;
  question: string;
  focus?: ReadingFocus;
  context?: ReadingContext;
  birthInfo?: BirthInfo;
  sajuChart?: SajuChart;
  luckCycles?: LuckCycles;
  tarotCards?: DrawnTarotCard[];
  /** 타로 스프레드별 해석 방법 안내 (A/B 비교, 한 달 흐름 등) */
  spreadNote?: string;
}

/** 새 리딩을 시작할 때 보낼 사용자 메시지(계산된 사실 + 질문)를 구성한다 */
export function buildReadingUserMessage(facts: ReadingFacts): string {
  const parts: string[] = [];

  parts.push(`[리딩 종류] ${TYPE_LABEL[facts.type]}`);
  parts.push(`[사용자 질문] ${facts.question || "(특정 질문 없이 전반적인 리딩 요청)"}`);

  if (facts.birthInfo && facts.sajuChart) {
    parts.push(`[생년월일시] ${formatBirthInfo(facts.birthInfo)}`);
    parts.push(`[사주 원국 계산 결과]\n${formatSajuChart(facts.sajuChart)}`);
  }

  if (facts.luckCycles) {
    parts.push(`[대운/세운/월운/일진 계산 결과]\n${formatLuckCycles(facts.luckCycles)}`);
    parts.push(
      "[운 흐름 해석 안내] \"현재 흐름\" 섹션에서 위에 계산되어 전달된 '운과 원국의 상호작용'을 핵심 근거로 삼아 타이밍을 해석해라. 예를 들어 세운이 원국 월지와 충이면 그 영역(월지가 뜻하는 환경·직장·가정)의 변동 가능성으로 연결해라. 목록에 없는 상호작용을 만들어내지 마라. 좋은 시기와 조심할 시기를 구분하되, 단정 대신 \"이런 선택을 하면 좋아지는 시기\"의 형태로 설명해라.",
    );
  }

  if (facts.focus && facts.focus !== "general") {
    parts.push(FOCUS_INSTRUCTIONS[facts.focus]);
  }

  if (facts.context) {
    parts.push(...formatContext(facts.context));
  }

  if (facts.type === "today") {
    parts.push(
      "[오늘의 흐름 안내] 오늘 일진과 이번 달 월운이 원국과 맺는 상호작용을 핵심 근거로, 오늘 하루의 에너지 흐름·컨디션·관계/일에서의 주의점·오늘을 잘 쓰는 방법을 해석해라. 일진은 참고용 단기 흐름이므로 가볍고 실용적으로 다루되, 근거 없는 길흉 단정은 하지 마라. 출력은 간결하게: 핵심 요약 / 해석 근거 / 현재 흐름 / 현실 조언(오늘 할 일 중심) / 신뢰도 / 한 줄 결론 섹션 위주로 써라.",
    );
  }

  if (facts.type === "flow") {
    parts.push(
      "[월간/연간 흐름 안내] 위에 계산된 '올해 월별 월운 흐름'을 핵심 근거로 올해 전체의 리듬을 해석해라. 반드시 지켜라: (1) 12개월을 하나씩 나열식으로 채우지 말고, 흐름이 비슷한 달을 묶어 2~4개의 구간으로 나눠 설명해라. (2) 각 구간을 '시도하기 쉬운 조건의 시기'와 '무리하면 손실이 커지는 시기'로 구분하되, 좋은 달/나쁜 달로 단정하지 마라. (3) 이번 달과 다음 달은 별도로 한 단락씩 자세히 다뤄라. (4) 계산된 상호작용 목록에 없는 합충을 만들어내지 마라. 상호작용이 없는 달은 '원국을 크게 흔들지 않는 평이한 달'로 해석해라. (5) 대운·세운이라는 큰 배경 위에 월운이 얹히는 구조로 설명해라.",
    );
  }

  if (facts.tarotCards && facts.tarotCards.length > 0) {
    parts.push(`[타로 스프레드] ${facts.tarotCards.length}장`);
    parts.push(`[뽑힌 카드]\n${formatTarotCards(facts.tarotCards)}`);
    if (facts.spreadNote) {
      parts.push(`[이 배열의 해석 방법] ${facts.spreadNote}`);
    }
    if (facts.tarotCards.length >= 3) {
      parts.push(
        "[카드 조합 해석 안내] 카드를 한 장씩만 따로 풀지 말고, \"해석 근거\"에서 각 자리의 의미와 카드가 만나 어떤 이야기가 되는지, 카드 간 조합(강화/충돌/전환)을 반드시 별도로 짚어라. 메이저 아르카나가 많으면 흐름의 무게가 크다는 점, 같은 슈트가 반복되면 그 영역(완드=일/열정, 컵=감정/관계, 소드=생각/갈등, 펜타클=현실/돈)이 중심이라는 점을 활용해라.",
      );
    }
  }

  if (facts.type === "combo") {
    parts.push(
      "[통합 리딩 안내] 사주는 타고난 성향과 장기 흐름, 타로는 현재 질문에 대한 단기 흐름으로 구분해서 설명하고, 둘이 다른 방향을 가리키면 각각의 해석 범위를 명확히 구분해라.",
    );
  }

  return parts.join("\n\n");
}

export interface CompareReadingInput {
  type: ReadingType;
  createdAt: string;
  question: string;
  reply: string;
}

/** 두 리딩을 비교 분석해달라는 사용자 메시지를 구성한다 */
export function buildCompareUserMessage(a: CompareReadingInput, b: CompareReadingInput): string {
  const format = (label: string, r: CompareReadingInput) =>
    [
      `[리딩 ${label}]`,
      `종류: ${TYPE_LABEL[r.type]} / 날짜: ${new Date(r.createdAt).toLocaleDateString("ko-KR")}`,
      `질문: ${r.question || "(질문 없음)"}`,
      `내용:\n${r.reply}`,
    ].join("\n");

  return [
    "아래 두 개의 지난 리딩을 비교 분석해라. 새 리딩을 만들지 말고, 두 리딩의 내용만 근거로 삼아라.",
    format("A", a),
    format("B", b),
    `출력 형식 (마크다운 헤딩):
# 두 리딩의 공통 흐름
반복해서 나타나는 주제, 성향, 조언을 짚어라.
# 달라진 점
시점/질문/카드가 다르면서 해석이 어떻게 달라졌는지, 그 이유가 무엇인지 설명해라.
# 종합 해석
두 리딩을 함께 놓고 봤을 때 지금 사용자에게 의미 있는 결론을 정리해라. 단정 대신 경향으로 말해라.
# 지금 취할 행동
두 리딩의 공통 조언에서 나온, 오늘부터 실행 가능한 행동 2~3가지를 제안해라.
# 한 줄 결론`,
  ].join("\n\n");
}
