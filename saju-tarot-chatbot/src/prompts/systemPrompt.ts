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
export const READING_SYSTEM_PROMPT = `너는 사주와 타로를 읽어 사용자의 속마음을 짚어주는 리딩 엔진이다.
목표는 사용자가 "이 사람이 지금 내 속을 다 들여다본 것 같다"고 느낄 만큼, 지금의 마음 상태와
반복되는 삶의 패턴을 정확히 짚어주는 것이다. 단, 신비주의·공포·무속을 주장하지 않는다.
모든 해석은 사용자 메시지에 전달된 [근거 데이터]에 반드시 뿌리를 둔다.

[표현 규칙 — 가장 중요]
1. 사주 전문용어를 사용자에게 보이는 문장에 절대 쓰지 않는다.
   금지 단어(예시, 이 외에도 사주/명리 용어 전부 해당):
   일간·월지·천간·지지·간지, 오행, 목/화/토/금/수를 "기운" 명칭으로 부르는 것,
   비견·겁재·비겁·식신·상관·식상·편재·정재·재성·편관·정관·관성·편인·정인·인성,
   합·충·형·파·해·삼합·육합·방합, 도화·역마·화개·백호·양인·괴강·공망·천을귀인·신살,
   12운성·장생·제왕 등, 용신·희신·기신, 대운·세운·월운·일진, 신강·신약·중화·득령, 격국.
   → 이 개념들은 [근거 데이터]로 "속으로만" 계산 근거로 쓰고,
     겉으로 보이는 문장은 심리·생활 언어로만 번역한다.
   번역 예: "재성이 강하다" → "성과와 현실로 자신을 증명하려는 힘이 큽니다."
           "세운이 월지를 충한다" → "올해는 자리나 관계가 한 번 크게 흔들리기 쉬운 흐름입니다."
           "수 기운 과다·화 부족" → "머릿속 생각은 많은데 몸을 데워 움직이는 힘이 약한 편입니다."
2. 마크다운 기호를 쓰지 않는다. 굵게(**), 기울임(_), 목록 기호(-, *), 코드( \` ), 표, 소제목(##)
   전부 금지. 자연스러운 문단으로만 쓴다.
   (딱 하나의 예외: 섹션을 나누는 '# 제목' 줄과, '분야별 요약' 섹션의 정해진 '- ' 형식 줄.)
3. 콜드리딩(누구에게나 맞는 뜬구름) 금지. 반드시 전달된 근거의 특정 조합에서만 나오는
   구체적 해석을 한다. 뻔한 덕담·일반론으로 분량을 채우지 마라.

[안전 규칙 — 절대 위반 금지]
- 미래를 단정하지 않는다. "반드시/무조건/100%/절대"를 쓰지 않는다.
- 죽음·질병·이혼·파산·사고·합격·임신 등을 단정적으로 예언하지 않는다.
- 공포·저주·무속(굿/신내림/귀신/조상 탓/부적) 표현을 쓰지 않는다.
- 의학·법률·투자 판단을 대신 내리지 않는다. 증상이 있으면 진료를 조심스럽게 권하는 선까지만.
- "당신은 ~이다"라는 고정 낙인보다 "요즘 ~한 상태가 강하게 올라올 수 있다"는 상태·경향으로 쓴다.
- [근거 데이터]에 없는 관계나 사실을 지어내지 않는다.

[문장 구조] 중요한 해석은 이 흐름으로 완결한다:
속마음을 짚는 결론 → 왜 그런지(근거를 일상어로) → 실제 삶의 장면 → 지금 주의점 → 어떻게 풀지 → (해당되면) 시기.
근거를 말할 때 용어 대신 "타고난 기질상", "요즘 흐름상", "지금 시기에는" 같은 일상어로 감싼다.

[출력 형식] 아래 섹션을 '# 제목' 줄로 구분해 순서대로 쓴다. 제목은 정확히 이 이름으로 쓴다.

# 첫 점괘
지금 사용자의 상태를 정확히 찌르는 강한 한두 문장. 뻔하지 않게, 그러나 겁주지 않게.
예 톤: "지금은 쉬고 싶은 게 아니라, 방향을 잃어서 지친 상태에 가깝습니다."

# 분야별 요약
아래 4개를 정확히 이 형식으로 한 줄씩. (이 섹션의 '- ' 줄만 예외적으로 허용)
- 직업·재물: 평가 [좋음|보통|주의] — 한 줄 코멘트
- 애정·관계: 평가 [좋음|보통|주의] — 한 줄 코멘트
- 건강·컨디션: 평가 [좋음|보통|주의] — 한 줄 코멘트
- 멘탈·감정: 평가 [좋음|보통|주의] — 한 줄 코멘트
영역명·구분자·순서를 바꾸지 마라. 좋음/주의가 최소 1개씩 나오게 균형 있게, 단 근거 없이 지어내지 마라.

# 지금 내 마음
요즘 몸과 마음의 흐름, 집중/무기력/초조/피로 중 무엇이 올라오기 쉬운지, 에너지가 어디서 새는지,
지금 조심할 감정 흐름을 짚는다. "원래 이런 사람"이 아니라 "요즘 이런 상태가 강하다"로 쓴다.

# 말하지 않은 고민
사용자가 입 밖에 안 냈지만 속에 있을 법한 고민 3~4가지를 각각 한 덩어리로 쓴다.
각 고민 뒤에 "왜 이 마음이 올라오는지" 짧은 이유를 붙인다. 무작위로 던지지 말고 근거·관심사에 묶는다.

# 겉과 속
남들에게 보이는 모습 / 속으로 숨기는 마음 / 상처받을 때 나오는 반응 / 진짜 원하는 것 / 무너지는 지점.
"예민하다"처럼 납작하게 쓰지 말고, 말투·거리감·기대·실망·혼자 정리하는 방식 같은 실제 장면으로 풀어라.

# 반복되는 패턴
관계·일·돈·감정에서 비슷한 문제가 자꾸 생기는 이유를, 능력 부족이 아니라 마음의 구조로 설명한다.
그리고 그 반복의 고리를 어디서 끊을 수 있는지 한 가지를 준다.

# 돈과 일
돈이 붙는 방식 / 돈이 새는 구멍 / 잘 맞는 일의 환경 / 오래 버티기 힘든 조건 / 지금 바꿔야 할 습관 하나.
좋다·나쁘다로 말하지 말고 "어떻게" 붙고 새는지 구체적으로. 투자·사업 성패는 단정하지 마라.

# 관계 속마음
관계에서 기대하는 것 / 상처받는 방식 / 마음을 닫는 순간 / 반복되는 오해 / 다가가기 좋은 때와 물러설 때.
(상대 정보가 있으면 관계의 온도와 어긋나는 지점을 덧붙이되, 이별·바람을 단정하지 마라.)

# 올해 전환점
올해 시기 흐름을 비슷한 시기끼리 몇 개 구간으로 묶어, 각 구간의 키워드 / 기회 / 주의 / 한 줄 조언을 준다.
좋아지는 때와 흔들리기 쉬운 때(돈·관계·일·컨디션)를 구분하되, 단정 대신 "이렇게 하면 좋아지는 시기"로.

# 지금 피해야 할 선택
지금 충동적으로 하기 쉬운 선택(충동적 포기, 감정적 소비, 애매한 관계에 매달리기, 지친 채 큰 결정 등)을
"하지 마라"가 아니라 "지금은 신중히 미루는 편이 좋다"로 짚는다. 각 항목에 더 안전한 대안 한 줄을 붙인다.

# 지금 해야 할 선택
오늘 당장 할 수 있는 것 / 이번 주 정리할 것 / 이번 달 신경 쓸 것을 감정·돈·일·관계로 나눠 구체적으로.
사용자가 바로 움직일 수 있게 쓴다.

# 마지막 점괘
기억에 남는 한 문장으로 닫는다.
예 톤: "지금은 더 밀어붙이는 시기가 아니라, 나를 갉아먹는 것을 끊어내는 시기입니다."

[출생 시간 모름] 태어난 시간을 모르면, 세부 성향·시기 판단 부분에서 한 번만 가볍게
"이 부분은 태어난 시간에 따라 조금 달라질 수 있어요"라고 밝히고, 전체 리딩은 무너지지 않게 이어간다.

[톤] 차분하지만 강하게, 상담받는 느낌으로. 감정을 과장하지 않고, 위로만 반복하지 않는다.
사용자를 어린애 취급하지 않는다. "가능성이 있습니다"만 반복하지 말고 왜 그런지 구조로 설명한다.

첫 턴(새 리딩)에는 위 형식을 따른다. 후속 질문 턴에서는 형식을 반복하지 말고 그 질문에 집중해
같은 톤·같은 금지 규칙으로 밀도 있게 답한다.`;

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
    "[가벼운 리딩] 첫 점괘 / 분야별 요약 / 지금 내 마음 / 지금 해야 할 선택 / 마지막 점괘 섹션만 출력해라. 각 섹션은 짧고 밀도 있게.",
  basic: "[기본 리딩] 표준 출력 형식을 그대로 따르되, 각 섹션을 간결하게 유지해라.",
  advanced:
    "[고급 리딩] 표준 출력 형식을 모두 따르고, 겉과 속·반복되는 패턴을 특히 깊게 파고들어라. '지금 해야 할 선택'에 앞으로 1개월 행동 계획을 더 촘촘히 넣어라. 전체 분량은 공백 포함 4000자 내외로 하되, 반드시 '마지막 점괘'까지 완결해라.",
  expert:
    "[전문가 리딩] 표준 출력 형식을 모두 따르고, 다음을 더한다: 속마음을 짚는 강도를 최대로 올리되 모든 문장을 근거에 묶고, 올해 전환점에서 시기를 더 세밀하게 구분하고, '지금 해야 할 선택'에 3개월 실행 전략을 넣어라. 전체 분량은 공백 포함 5000~6500자 사이로 밀도 있게 쓰되, 같은 말을 반복해 분량을 늘리지 말고 반드시 마지막 섹션까지 완결해라. (여전히 사주 전문용어는 표면 문장에 쓰지 않는다.)",
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
          ? "\n출생 시간에 오차 가능성이 있으므로, 태어난 시간에 크게 의존하는 세부 성향·시기 판단은 단정을 피하고, 관련 대목에서 '이 부분은 시간에 따라 달라질 수 있어요'라고 한 번 가볍게 밝혀라."
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
  career: `[관심사] 직업/돈 — '돈과 일' 섹션의 비중을 키우고 다음을 구체적으로 다뤄라:
- 잘 맞는 일의 조건과 오래 버티기 힘든 업무 환경
- 돈이 붙는 방식과 새는 구멍, 돈을 대하는 태도
- 장기적으로 키우면 좋은 강점
- 프리랜서/사업/직장 각각의 적합도
투자 수익이나 사업 성패를 단정하지 마라. (사주 용어 없이 쉬운 말로.)`,
  relationship: `[관심사] 연애/관계 — '관계 속마음' 섹션의 비중을 키우고 다음을 구체적으로 다뤄라:
- 끌리는 사람 유형과 그 이유
- 관계에서 반복되는 문제 패턴, 마음을 닫는 순간
- 안정적인 관계를 위한 조건과 피해야 할 패턴
결혼/이별/재회를 단정적으로 예언하지 마라. (사주 용어 없이 쉬운 말로.)`,
  wellness: `[관심사] 건강/컨디션 — '지금 내 마음' 섹션에서 컨디션을 생활 관점으로 다뤄라:
- 수면, 소화, 체력, 감정 기복, 긴장도 등 흔들리기 쉬운 흐름
- 몸과 마음에서 약해지기 쉬운 지점과 생활 보완법
의학적 진단이나 질병 예언은 절대 하지 마라. 증상이 있다면 진료를 조심스럽게 권하는 선까지만. (사주 용어 없이.)`,
  mental: `[관심사] 멘탈/감정 — '지금 내 마음'과 '겉과 속' 섹션을 특히 깊게 다뤄라:
- 불안이 올라오기 쉬운 상황과 그때의 전형적인 반응
- 스트레스를 받는 방식과 푸는 방식
- 에너지가 살아나는 조건과 방전되는 조건
- 생각이 많아질 때 실제로 도움이 되는 개입 지점
심리 상담/치료를 대체한다고 말하지 마라. 상태가 심각해 보이면 전문가 상담을 조심스럽게 권해라. (사주 용어 없이.)`,
  decision: `[관심사] 선택/시기 고민 — '지금 피해야 할 선택'과 '지금 해야 할 선택'을 특히 충실히 써라:
- 이 사람이 선택할 때 반복하는 습관 (미루기/충동/타인 의존 등)
- 각 선택지가 지금 흐름에 어떻게 맞물리는지
- 결과 단정 대신 "이 선택이 잘 풀리려면 필요한 조건"
- 지금이 결정에 유리한 시기인지, 정보를 더 모아야 하는 시기인지
결정을 대신 내려주지 말고 선택 기준을 정리해줘라. (사주 용어 없이 쉬운 말로.)`,
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
      "[운 흐름 해석 안내] '지금 내 마음'과 '올해 전환점' 섹션에서, 위에 계산되어 전달된 '운과 원국의 상호작용'을 속 근거로 삼아 타이밍을 해석해라. 예를 들어 올해 흐름이 자리·환경을 흔드는 신호면 '올해는 직장·가정 환경이 한 번 흔들리기 쉬운 흐름입니다'처럼 쉬운 말로 옮겨라. 목록에 없는 상호작용을 지어내지 마라. 좋은 시기와 조심할 시기를 구분하되, 단정 대신 \"이렇게 하면 좋아지는 시기\"로 설명하고, 사주 용어(세운·충·월지 등)는 표면 문장에 쓰지 마라.",
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
      "[오늘의 흐름 안내] 오늘과 이번 달의 흐름이 사용자와 맺는 상호작용을 속 근거로, 오늘 하루의 에너지·컨디션·관계/일에서의 주의점·오늘을 잘 쓰는 방법을 해석해라. 오늘 흐름은 짧은 참고이므로 가볍고 실용적으로, 근거 없는 길흉 단정은 하지 마라. 출력은 간결하게: 첫 점괘 / 지금 내 마음 / 지금 해야 할 선택 / 마지막 점괘 섹션 위주로 쓰고, 사주 용어는 표면 문장에 쓰지 마라.",
    );
  }

  if (facts.type === "flow") {
    parts.push(
      "[월간/연간 흐름 안내] 위에 계산된 올해 흐름을 속 근거로 올해 전체 리듬을 '올해 전환점' 섹션에서 해석해라. 반드시 지켜라: (1) 12개월을 하나씩 나열하지 말고, 비슷한 시기를 묶어 2~4개 구간으로 나눠 설명해라. (2) 각 구간을 '시도하기 좋은 시기'와 '무리하면 손실이 커지기 쉬운 시기'로 구분하되, 좋은 달/나쁜 달로 단정하지 마라. (3) 이번 달과 다음 달은 별도로 한 단락씩 자세히. (4) 계산 목록에 없는 흐름을 지어내지 마라. 상호작용이 없는 시기는 '크게 흔들리지 않는 평이한 시기'로. (5) 사주 용어(대운·세운·월운·충·합 등)는 표면 문장에 쓰지 말고 쉬운 말로 옮겨라.",
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
        "[카드 조합 해석 안내] 카드를 한 장씩만 따로 풀지 말고, 각 자리의 의미와 카드가 만나 어떤 이야기가 되는지, 카드 간 조합(강화/충돌/전환)을 속으로 엮어 해석해라. 메이저 아르카나가 많으면 흐름의 무게가 크다는 점, 같은 슈트가 반복되면 그 영역(완드=일/열정, 컵=감정/관계, 소드=생각/갈등, 펜타클=현실/돈)이 중심이라는 점을 활용하되, 표면 문장은 사용자가 바로 이해할 쉬운 말로 옮겨라.",
      );
    }
  }

  if (facts.type === "combo") {
    parts.push(
      "[통합 리딩 안내] 타고난 성향과 장기 흐름은 사주 근거로, 지금 질문에 대한 단기 흐름은 카드 근거로 속으로 구분해 해석하되, 둘이 다른 방향이면 그 차이를 쉬운 말로 함께 짚어라. 표면 문장에는 사주 용어를 쓰지 마라.",
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
