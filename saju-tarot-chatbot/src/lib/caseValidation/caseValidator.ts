import type { JudgmentPack } from "../judgmentTypes.js";
import type {
  Case,
  CaseDomain,
  CaseDomainOutcome,
  CaseJudgmentOutcome,
  CaseValidationResult,
} from "./caseTypes.js";
import { MATCH_SCORE } from "./caseTypes.js";
import { expectationFor, scoreMatch } from "./caseScore.js";

/**
 * 사례 검증기 (Case Validator).
 *
 * JudgmentPack(판단 결과)과 Case(실제 결과)를 대조해, 판단마다 match/partial/minor/miss를 매기고
 * 대조 가능한 판단만으로 matchRate를 계산한다. 판단·규칙을 수정하지 않는 읽기 전용 비교기다.
 */

function readAudit(pack: JudgmentPack): {
  rewriteUsed: boolean;
  fallbackUsed: boolean;
  validationStatus?: "pass" | "rewrite" | "fallback";
} {
  const audit = pack.audit;
  const status = audit.validationStatus;
  return {
    rewriteUsed: audit.rewriteAttempted === true || status === "rewrite",
    fallbackUsed: audit.fallbackUsed === true || status === "fallback",
    validationStatus: status,
  };
}

export function validateCase(pack: JudgmentPack, kase: Case): CaseValidationResult {
  const outcomeByDomain = new Map<CaseDomain, CaseDomainOutcome>();
  for (const o of kase.actualOutcomes) outcomeByDomain.set(o.domain, o);

  const outcomes: CaseJudgmentOutcome[] = pack.judgments.map((j) => {
    const exp = expectationFor(j.code);
    const domainOutcome =
      exp.domain === "general" ? undefined : outcomeByDomain.get(exp.domain);
    const confidence = j.confidence.overall;
    const base = {
      judgmentId: j.id,
      code: j.code,
      domain: exp.domain,
      predicted: exp.predicted,
      confidence,
      triggeredRuleIds: j.triggeredRuleIds,
    };

    if (exp.predicted === "none") {
      return {
        ...base,
        scored: false,
        level: "minor" as const,
        score: MATCH_SCORE.minor,
        reason: "특정 사건을 예측하지 않는 일반 흐름 판단 — 대조 대상 아님",
      };
    }
    if (!domainOutcome) {
      return {
        ...base,
        scored: false,
        level: "minor" as const,
        score: MATCH_SCORE.minor,
        reason: `해당 분야(${exp.domain}) 실제 결과가 기록되지 않음 — 대조 불가`,
      };
    }
    const matched = scoreMatch(exp.predicted, domainOutcome);
    return {
      ...base,
      scored: true,
      level: matched.level,
      score: matched.score,
      reason: matched.reason,
    };
  });

  const scored = outcomes.filter((o) => o.scored);
  const matchRate =
    scored.length > 0
      ? Math.round(scored.reduce((sum, o) => sum + o.score, 0) / scored.length)
      : null;

  const audit = readAudit(pack);

  return {
    caseId: kase.id,
    source: kase.source,
    readingType: kase.readingType,
    outcomes,
    matchRate,
    scoredCount: scored.length,
    unscoredCount: outcomes.length - scored.length,
    rewriteUsed: audit.rewriteUsed,
    fallbackUsed: audit.fallbackUsed,
    validationStatus: audit.validationStatus,
    userRating: kase.userFeedback?.rating,
    expertVerdict: kase.expertReview?.verdict,
  };
}

/** 여러 (pack, case) 쌍을 한 번에 검증 */
export function validateCases(
  pairs: { pack: JudgmentPack; case: Case }[],
): CaseValidationResult[] {
  return pairs.map(({ pack, case: kase }) => validateCase(pack, kase));
}
