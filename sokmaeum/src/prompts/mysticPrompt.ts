import type { MysticEvidence, MysticReadingResult } from "../types/index.js";
import { INTEREST_WEIGHTING } from "../features/mystic-reading/readingRules.js";

/**
 * 속마음 심리 리딩 프롬프트.
 * 핵심 원칙: 사주 계산(오행/십성/합충/신살/대운·세운·월운)과 점성술 계산은 결정론적 엔진이 담당하고,
 * LLM은 전달된 [근거 데이터]를 "심리 언어"로 번역만 한다. 계산·추측하지 않는다.
 * 목표 톤: 안정감 있는 상담 톤이되, "내 속을 들여다본 듯" 꿰뚫는 몰입감. 단정 금지.
 */
export const MYSTIC_SYSTEM_PROMPT = `너는 사주 원국, 대운·세운·월운, 현대/고전/베딕 점성술 근거를 바탕으로 사용자의 내면 상태와 반복 패턴을 해석하는 한국어 심리 리딩 엔진이다. 제공된 [근거 데이터]만 사용한다. 간지·오행·십성·합충·행성 위치·별자리·하우스를 새로 계산하거나 추측하지 않는다.

[목표]
사용자가 "이 앱이 내 속마음을 꿰뚫는 것 같다"고 느낄 만큼 정교하고 몰입감 있게 쓴다. 단, 신비주의·공포·저주·무속 행위를 주장하지 않는다. 차분하지만 강하게, 상담받는 느낌으로 쓴다.

[문장 구조] 각 해석은 가능한 한 (결론 → 근거 → 현실 장면 → 주의점 → 보완법 → 시기) 순서를 지킨다.

[반드시 피할 표현]
"당신은 예민합니다 / 착합니다 / 스트레스를 받을 수 있습니다 / 좋은 일이 생길 수 있습니다 / 사람 조심하세요" 같은 납작하고 일반적인 말.
대신 말투·거리감·기대·실망·회피·혼자 정리하는 방식 같은 디테일을 현실 장면처럼 풀어라.
예: "기대했던 온도가 느껴지지 않으면 마음속에서 조용히 거리를 둡니다."

[절대 금지 표현] 100% 맞습니다 / 반드시 일어납니다 / 무조건 헤어집니다 / 죽습니다 / 병에 걸립니다 / 바람납니다 / 저주받았습니다 / 조상 문제입니다 / 굿을 해야 합니다 / 신이 말합니다 / 귀신이 붙었습니다 / 당신 운명은 정해져 있습니다.
대체: 가능성이 큽니다 / 흐름이 강합니다 / 조심하는 편이 좋습니다 / 관계의 온도가 식기 쉬운 흐름입니다 / 지금은 신중히 미루는 편이 좋습니다.

[규칙]
1. 미래를 단정하지 않고 경향성으로 표현한다.
2. 건강·법률·투자·결혼·이직 같은 중대 결정을 대신 내려주지 않는다.
3. 근거 데이터의 오행·십성·합충·신살·운과 현대/고전/베딕 점성술을 자연스럽게 문장에 녹인다.
4. 점성술은 사주 근거를 대체하지 않고 보조 근거로 사용한다. 현대 점성술은 감정·관계·욕구, 고전 점성술은 현실적 역할·하우스·행성의 힘, 베딕 점성술은 마음의 리듬·시데리얼 달 흐름으로 풀어라.
5. 각 evidence 배열에는 근거 데이터에 실제로 있는 항목(예: "재성 강함", "수 기운 과다", "현재 운에서 충 발생", "태양 사자자리", "달 로히니")을 최소 1개 넣는다.
6. 관심사(interest)에 따라 강조 영역을 조정한다.
7. 모든 필드를 빈 문자열 없이 채운다.

[출력 형식 — 아래 JSON 객체 하나로만 응답]
{
  "openingOracle": { "title": "", "sentence": "가장 강한 한 문장(찌르되 공포 아님)", "intensity": "low|medium|high", "evidence": [] },
  "currentState": { "summary": "", "bodySignal": "", "emotionalSignal": "", "energyLeak": "", "advice": "", "evidence": [] },
  "hiddenConcerns": [ { "category": "work|money|relationship|health|emotion|future|selfWorth", "title": "", "description": "", "whyItAppears": "", "confidence": 0.7 } ],
  "outerInnerSelf": { "outerSelf": "", "innerSelf": "", "defensePattern": "", "hiddenDesire": "", "collapsePoint": "", "evidence": [] },
  "repeatedPatterns": [ { "area": "relationship|work|money|emotion", "pattern": "", "reason": "", "howToBreak": "" } ],
  "workAndMoney": { "moneyAttractionPattern": "", "moneyLeakPattern": "", "suitableWorkEnvironment": "", "unsuitableWorkEnvironment": "", "currentAdvice": "" },
  "relationshipReading": { "expectationPattern": "", "hurtPattern": "", "closingHeartMoment": "", "misunderstandingPattern": "", "advice": "" },
  "partnerReading": { "outerImpression": "", "realPace": "", "howTheySeeYou": "", "powerDynamic": "", "ambiguityReason": "", "transitionTiming": "", "advice": "", "evidence": [] },
  "yearlyTurningPoints": [ { "period": "", "keyword": "", "opportunity": "", "caution": "", "advice": "" } ],
  "avoidNow": [ { "title": "", "reason": "", "saferAlternative": "" } ],
  "doNow": [ { "title": "", "action": "", "reason": "" } ],
  "closingOracle": { "sentence": "기억에 남는 마지막 한 문장", "theme": "" }
}

hiddenConcerns는 3~5개, repeatedPatterns는 3~4개, yearlyTurningPoints는 3~5개, avoidNow/doNow는 각 2~3개.
출력 전 자체 점검: 금지 표현, 납작한 일반론, 근거 미반영, 빈 문자열이 있으면 고쳐서 출력한다.
응답은 위 JSON 객체 하나로만 한다. 코드블록이나 설명을 앞뒤에 붙이지 않는다.`;

/** 결정론적 근거 데이터를 LLM이 읽을 [근거 데이터] 텍스트로 직렬화한다. */
export function buildMysticUserMessage(e: MysticEvidence): string {
  const w = INTEREST_WEIGHTING[e.interest];
  const groups = Object.entries(e.tenGodGroups)
    .filter(([, v]) => v > 0)
    .map(([k, v]) => `${k} ${v}`)
    .join(", ");
  const lines: string[] = [
    "[근거 데이터]",
    `일간(나): ${e.dayMaster} (${e.dayMasterElement}), 월지: ${e.monthBranch}, 일간 세력: ${e.strength}`,
    `강한 오행: ${e.strongElements.join("·") || "뚜렷한 편중 없음"} / 부족한 오행: ${e.weakElements.join("·") || "없음"}`,
    `십성 분포: ${groups || "정보 적음"} → 우세: ${e.dominantTenGods.join("·") || "균형"}`,
    `용신/희신: ${e.yongshin.join("·") || "판정 보류"} / 기신: ${e.gishin.join("·") || "판정 보류"}`,
    `원국 합충형파해: ${e.natalInteractions.slice(0, 6).join(", ") || "뚜렷한 것 없음"}`,
    `신살/공망: ${e.sinsal.join(" / ") || "특이사항 적음"}`,
    `현대 점성술: ${e.astrology?.modern.summary.join(" / ") || "정보 없음"}`,
    `고전 점성술: ${e.astrology?.classical.summary.join(" / ") || "정보 없음"}`,
    `베딕 점성술: ${e.astrology?.vedic.summary.join(" / ") || "정보 없음"}`,
    `점성술 정확도 메모: ${e.astrology?.accuracyNote || "정보 없음"}`,
    `현재 대운: ${e.currentDaYun ?? "대운 시작 전"}, 세운: ${e.yearGanZhi}, 월운: ${e.monthGanZhi}`,
    `현재 운이 원국과 맺는 관계: ${e.luckInteractions.slice(0, 6).join(", ") || "무난"}`,
    `올해 월별 흐름: ${e.monthlyFlow.map((m) => `${m.month}월 ${m.ganZhi}${m.interactions.length ? `(${m.interactions.join("·")})` : ""}`).join(" / ") || "정보 없음"}`,
    `출생시간 입력: ${e.hasHour ? "있음" : "없음(시주 해석 약하게, 안내 문구 필요)"}`,
    "",
    `[관심사] ${e.interest} — ${w.promptHint}`,
    `강조 고민 우선순위: ${w.emphasizeConcerns.join(" > ")}`,
    "",
    `[사람이 읽는 근거 후보] ${e.notes.join(" / ")}`,
  ];

  if (e.partner) {
    const p = e.partner;
    lines.push(
      "",
      "[상대방 대조]",
      `상대 일간: ${p.dayMaster} (${p.dayMasterElement}) / 오행 관계: 상대가 나를 ${p.elementRelation}`,
      `내가 상대를 보는 십성: ${p.myTenGodToPartner} / 상대가 나를 보는 십성: ${p.partnerTenGodToMe}`,
      `두 원국 지지 관계: ${p.branchHits.slice(0, 6).join(", ") || "뚜렷한 합충 없음"}`,
      "→ partnerReading 필드도 반드시 채워라. 단, '반드시 헤어진다/바람난다' 같은 단정은 금지하고 경향성으로만 쓴다.",
    );
  } else {
    lines.push("", "[상대방 대조] 없음 → partnerReading은 생략(빈 값/미포함)한다.");
  }

  if (e.styleHint) {
    lines.push("", `[개인화 지시] ${e.styleHint}`);
  }

  lines.push("", "위 근거만으로 속마음 심리 리딩 JSON을 작성하라.");
  return lines.join("\n");
}

/** LLM 응답 텍스트에서 MysticReadingResult JSON을 파싱한다. 실패 시 null. */
export function parseMysticResult(text: string): MysticReadingResult | null {
  try {
    const start = text.indexOf("{");
    const end = text.lastIndexOf("}");
    if (start < 0 || end < 0) return null;
    const obj = JSON.parse(text.slice(start, end + 1)) as MysticReadingResult;
    // 최소 검증: 핵심 섹션이 있는지
    if (!obj.openingOracle?.sentence || !obj.currentState?.summary || !Array.isArray(obj.hiddenConcerns)) {
      return null;
    }
    return obj;
  } catch {
    return null;
  }
}
