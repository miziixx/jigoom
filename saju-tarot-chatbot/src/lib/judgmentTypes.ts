import type { LifeDomain, ReadingType } from "../types/index.js";

export const JUDGMENT_SCHEMA_VERSION = "1.0.0" as const;

export type EvidenceSource = "chart" | "luck" | "event" | "context" | "compact";
export type EvidenceDirection = "support" | "risk" | "counter" | "neutral" | "constraint";
export type EvidenceStrength = 1 | 2 | 3 | 4 | 5;

export interface EvidenceRef {
  id: string;
  source: EvidenceSource;
  strength: EvidenceStrength;
  direction: EvidenceDirection;
  summary: string;
}

export type JudgmentDomain = LifeDomain | "personality" | "year" | "decision" | "general";
export type RuleId = `rule.${string}`;

export interface TriggeredRule {
  id: RuleId;
  domain: JudgmentDomain;
  code: string;
  evidence: EvidenceRef[];
  counterEvidence: EvidenceRef[];
  weight: number;
  result: "support" | "risk" | "constraint";
  summary: string;
}

export type JudgmentCode =
  | "CAREER_CHANGE_HIGH"
  | "CAREER_STABLE_CAUTION"
  | "MONEY_RISK_MEDIUM"
  | "MONEY_OPPORTUNITY"
  | "LOVE_STABLE"
  | "LOVE_DELAY"
  | "HEALTH_CAUTION"
  | "STARTUP_NOT_RECOMMENDED"
  | "STARTUP_TEST_FIRST"
  | "MOVE_CAUTION"
  | "FAMILY_RESPONSIBILITY"
  | "GENERAL_MIXED_FLOW";

export interface ConfidenceBreakdown {
  chart: number;
  luck: number;
  event: number;
  context: number;
  overall: number;
  reasons: string[];
}

export interface AllowedTone {
  stance: "confident" | "balanced" | "cautious" | "uncertain";
  modality: "can_say" | "should_say" | "must_frame_as_condition";
  wordingHints: string[];
}

export interface ForbiddenClaim {
  code: string;
  domain?: JudgmentDomain;
  patternHint: string;
  reason: string;
}

export interface JudgmentCandidate {
  id: string;
  code: JudgmentCode;
  domain: JudgmentDomain;
  kind: "trait" | "timing" | "opportunity" | "caution" | "strategy" | "decision_support";
  plainConclusion: string;
  evidence: EvidenceRef[];
  counterEvidence: EvidenceRef[];
  confidence: ConfidenceBreakdown;
  allowedTone: AllowedTone;
  forbiddenClaims: ForbiddenClaim[];
  triggeredRuleIds: RuleId[];
  actionFrame: {
    do: string[];
    avoid: string[];
    checkSignals: string[];
  };
  uncertainty: {
    level: "low" | "medium" | "high";
    reasons: string[];
  };
}

export interface JudgmentContradiction {
  id: string;
  severity: "warning" | "error";
  judgmentIds: string[];
  message: string;
  resolution: "downgrade-confidence" | "prefer-caution" | "remove-claim" | "manual-review";
}

export interface DecisionTraceStep {
  stage: "evidence" | "rule" | "judgment" | "confidence" | "contradiction" | "prompt" | "validation";
  refId: string;
  summary: string;
}

export interface JudgmentAuditLog {
  schemaVersion: typeof JUDGMENT_SCHEMA_VERSION;
  evidenceIds: string[];
  ruleIds: RuleId[];
  judgmentIds: string[];
  promptId?: string;
  validationIssueIds?: string[];
  validationStatus?: "pass" | "rewrite" | "fallback";
  rewriteAttempted?: boolean;
  fallbackUsed?: boolean;
  finalConfidence?: number;
  userFeedback?: {
    rating?: number;
    note?: string;
  };
}

export interface JudgmentPack {
  schemaVersion: typeof JUDGMENT_SCHEMA_VERSION;
  readingType: ReadingType;
  generatedAt: string;
  evidence: EvidenceRef[];
  triggeredRules: TriggeredRule[];
  judgments: JudgmentCandidate[];
  contradictions: JudgmentContradiction[];
  globalForbiddenClaims: ForbiddenClaim[];
  decisionTrace: DecisionTraceStep[];
  audit: JudgmentAuditLog;
}
