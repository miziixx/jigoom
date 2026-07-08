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

export function formatJudgmentPackForPrompt(pack: JudgmentPack): string {
  const role =
    "[판단 묶음 — 이 리딩은 아래 계산된 판단만 근거로 쓴다] " +
    "역할: judgments의 결론(plainConclusion)을 상담 문장으로 번역만 한다. judgments에 없는 새 결론 생성, forbiddenClaims에 해당하는 표현, 근거 없는 퇴사·창업·결혼·투자·질병 결론은 쓰지 마라. 확신도가 낮거나 반대 근거가 있으면 그만큼 말투를 낮춰라.";

  const body =
    pack.judgments.length > 0
      ? pack.judgments.map(formatJudgment).join("\n")
      : "(발동된 판단 없음 — 확인된 기질과 평이한 흐름 안에서만 조언한다)";

  const contradictions =
    pack.contradictions.length > 0
      ? `\n\n■ 판단 간 긴장/모순 (확신 하향에 이미 반영됨): ${pack.contradictions.map((c) => c.message).join("; ")}`
      : "";

  const globalForbidden = forbidden(pack.globalForbiddenClaims);

  return `${role}\n\n■ 판단들\n${body}${contradictions}\n\n■ 공통 금지 표현: ${globalForbidden}`;
}
