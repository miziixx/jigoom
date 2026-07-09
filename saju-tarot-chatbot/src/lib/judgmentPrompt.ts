import type { EvidenceRef, ForbiddenClaim, JudgmentCandidate, JudgmentPack } from "./judgmentTypes.js";

/**
 * JudgmentPack을 LLM 프롬프트용 근거로 직렬화한다.
 *
 * 예전에는 pack 전체를 JSON.stringify(…, null, 2)로 통째 덤프해 ~47,000자에 달했고, LLM에는
 * 쓸모없는 decisionTrace·audit·schemaVersion·evidenceIds·triggeredRules 같은 내부 감사 데이터까지
 * 다 실려 "가벼운(light) 리딩"이 오히려 가장 무거워지는 모순이 있었다. 이제 LLM이 실제로 필요한
 * 판단 필드만 컴팩트한 텍스트로 남긴다(판단 결론·확신·톤·금지·행동·근거). 감사/추적용 필드는 뺀다.
 */

function refs(list: EvidenceRef[]): string {
  return list.map((r) => `(${r.id}) ${r.summary}`).join("; ");
}

function forbidden(list: ForbiddenClaim[]): string {
  return list.map((c) => c.patternHint).filter(Boolean).join(" / ");
}

function formatJudgment(j: JudgmentCandidate, index: number): string {
  const t = j.allowedTone;
  const lines = [
    `${index + 1}) [${j.code} · ${j.domain} · 확신 ${j.confidence.overall}/100 · 불확실성 ${j.uncertainty.level}]`,
    `   결론: ${j.plainConclusion}`,
    `   말투: ${t.stance}/${t.modality}${t.wordingHints.length > 0 ? ` (${t.wordingHints.join("·")})` : ""}`,
  ];
  const af = [
    j.actionFrame.do.length > 0 ? `할 것: ${j.actionFrame.do.join(" / ")}` : "",
    j.actionFrame.avoid.length > 0 ? `피할 것: ${j.actionFrame.avoid.join(" / ")}` : "",
    j.actionFrame.checkSignals.length > 0 ? `확인 신호: ${j.actionFrame.checkSignals.join(" / ")}` : "",
  ].filter(Boolean);
  if (af.length > 0) lines.push(`   ${af.join(" | ")}`);
  if (j.counterEvidence.length > 0) lines.push(`   반대 근거: ${refs(j.counterEvidence)}`);
  if (j.forbiddenClaims.length > 0) lines.push(`   이 분야 금지 표현: ${forbidden(j.forbiddenClaims)}`);
  if (j.evidence.length > 0) lines.push(`   근거: ${refs(j.evidence)}`);
  return lines.join("\n");
}

// 기본(무료) 리딩용: JudgmentPack만 근거로 삼는 빡센 Evidence Gate 프레이밍.
const GATE_ROLE =
  "[판단 묶음 — 이 리딩은 아래 계산된 판단만 근거로 쓴다] " +
  "역할: judgments의 결론(plainConclusion)을 상담 문장으로 번역만 한다. judgments에 없는 새 결론 생성, forbiddenClaims에 해당하는 표현, 근거 없는 퇴사·창업·결혼·투자·질병 결론은 쓰지 마라. 확신도가 낮거나 반대 근거가 있으면 그만큼 말투를 낮춰라.";

// 고급(유료) 리딩용: 원자료로 더 깊게 확장하되, 결론 방향은 이 판단에 앵커링한다.
// 기본과 신뢰가 어긋나지 않게 '바닥'을 깔아주는 것이지, 확장을 가두는 게 아니다.
const ANCHOR_ROLE =
  "[검증된 판단 — JudgmentPack 앵커] 아래는 이미 계산·검증이 끝난 결론(앵커)이다. " +
  "원자료로 더 깊고 촘촘하게 해석하되, 각 판단의 최종 방향(길/흉, 강/약, 추천/회피)은 이 앵커와 모순되면 안 된다. " +
  "원자료는 '왜 / 얼마나 / 언제'를 더 자세히 설명하는 데 쓰고, 결론 자체를 뒤집는 데 쓰지 마라. " +
  "만약 원자료 해석이 이 앵커와 어긋나면 앵커를 따른다. " +
  "방향(길/흉·강/약·추천/회피)은 앵커와 맞추되, 원자료(지장간·12운성·대운/세운/월운 등)로 앵커에 없던 새로운 깊이 — 구체적 시점·정도·메커니즘(왜 그런지) — 을 반드시 더하라. 앵커 결론을 다른 말로 재진술만 하는 것은 실패로 간주한다. " +
  "확신도가 낮거나 반대 근거가 있는 판단은 그만큼 말투를 낮추고, " +
  "forbiddenClaims에 해당하는 표현과 근거 없는 퇴사·창업·결혼·투자·질병 단정은 고급에서도 금지다.";

/** pack.evidence에서 용신(보완하면 좋은 기운) 근거를 뽑아 항상 프롬프트에 노출한다. */
function usefulElementsLine(pack: JudgmentPack): string {
  const ref = pack.evidence.find((r) => r.id === "chart.useful_elements.candidates");
  if (!ref) return "";
  return `\n\n■ 보완하면 좋은 기운(용신·희신)과 과하면 부담되는 기운(기신): ${ref.summary}\n   → 직업·개운 방향, [추천], 재물 습관 조언은 이 '보완하면 좋은 기운'을 논리축으로 삼아 설명하고, 이와 무관한 조언을 지어내지 마라. 단 '용신·기신' 같은 용어는 표면에 쓰지 말고 쉬운 말로 옮겨라.`;
}

export function formatJudgmentPackForPrompt(pack: JudgmentPack, mode: "gate" | "anchor" = "gate"): string {
  const role = mode === "anchor" ? ANCHOR_ROLE : GATE_ROLE;

  const body =
    pack.judgments.length > 0
      ? pack.judgments.map(formatJudgment).join("\n")
      : "(발동된 판단 없음 — 확인된 기질과 평이한 흐름 안에서만 조언한다)";

  const contradictions =
    pack.contradictions.length > 0
      ? `\n\n■ 판단 간 긴장/모순 (확신 하향에 이미 반영됨): ${pack.contradictions.map((c) => c.message).join("; ")}`
      : "";

  const globalForbidden = forbidden(pack.globalForbiddenClaims);

  return `${role}\n\n■ 판단들\n${body}${contradictions}${usefulElementsLine(pack)}\n\n■ 공통 금지 표현: ${globalForbidden}`;
}
