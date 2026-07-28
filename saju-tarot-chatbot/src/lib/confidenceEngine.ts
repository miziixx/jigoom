import type { ConfidenceBreakdown, EvidenceRef, TriggeredRule } from "./judgmentTypes.js";

function clamp100(value: number): number {
  return Math.max(0, Math.min(100, Math.round(value)));
}

function sourceScore(evidence: EvidenceRef[], source: EvidenceRef["source"]): number {
  const hits = evidence.filter((ref) => ref.source === source);
  if (hits.length === 0) return source === "context" ? 50 : 35;
  const avg = hits.reduce((sum, ref) => sum + ref.strength, 0) / hits.length;
  return clamp100(avg * 18 + Math.min(hits.length, 3) * 4);
}

export function scoreConfidence(rule: TriggeredRule, contextWeight = 0): ConfidenceBreakdown {
  const evidence = rule.evidence;
  const chart = sourceScore(evidence, "chart");
  const luck = sourceScore(evidence, "luck");
  const event = sourceScore(evidence, "event");
  const context = clamp100(sourceScore(evidence, "context") + contextWeight);
  const counterPenalty = Math.min(18, rule.counterEvidence.reduce((sum, ref) => sum + ref.strength, 0) * 2);
  const ruleWeight = rule.weight * 10;
  const overall = clamp100(chart * 0.2 + luck * 0.25 + event * 0.4 + context * 0.15 + ruleWeight - counterPenalty);
  const reasons: string[] = [
    `chart:${chart}`,
    `luck:${luck}`,
    `event:${event}`,
    `context:${context}`,
  ];
  if (counterPenalty > 0) reasons.push(`counterEvidencePenalty:${counterPenalty}`);
  return { chart, luck, event, context, overall, reasons };
}
