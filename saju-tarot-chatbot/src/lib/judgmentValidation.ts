import type { ForbiddenClaim, JudgmentDomain, JudgmentPack } from "./judgmentTypes.js";

export type JudgmentValidationIssueCode =
  | "missing-evidence"
  | "missing-rule"
  | "missing-forbidden-claim"
  | "invalid-confidence"
  | "forbidden-claim"
  | "unsupported-domain-claim"
  | "confidence-tone-violation"
  | "semantic-claim-violation";

export interface JudgmentValidationIssue {
  code: JudgmentValidationIssueCode;
  severity: "warning" | "error";
  message: string;
  evidence?: string;
}

export interface JudgmentValidationResult {
  ok: boolean;
  status: "pass" | "rewrite" | "fallback";
  issues: JudgmentValidationIssue[];
}

interface DomainClaimPattern {
  domain: JudgmentDomain;
  phrases: string[];
  highRisk: boolean;
}

const DOMAIN_CLAIMS: DomainClaimPattern[] = [
  { domain: "career", phrases: ["퇴사", "이직", "회사를 그만", "직장", "커리어", "직업"], highRisk: true },
  { domain: "money", phrases: ["투자", "큰돈", "수익", "돈을 벌", "재물", "금전"], highRisk: true },
  { domain: "love", phrases: ["결혼", "재회", "헤어집", "이별", "연애", "관계"], highRisk: true },
  { domain: "health", phrases: ["질병", "암", "진단", "병원", "건강"], highRisk: true },
  { domain: "startup", phrases: ["창업", "독립", "사업"], highRisk: true },
  { domain: "move", phrases: ["이사", "이동", "옮기"], highRisk: true },
  { domain: "family", phrases: ["가족", "집안", "부모"], highRisk: true },
];

const LOW_CONFIDENCE_ASSERTIONS = [
  "강하게 나타납니다",
  "뚜렷합니다",
  "분명합니다",
  "확실",
  "반드시",
  "무조건",
  "절대",
];

const MID_CONFIDENCE_FORBIDDEN = ["확실", "반드시", "무조건", "100%", "절대"];

const SEMANTIC_FORBIDDEN: Array<{ code: JudgmentValidationIssueCode; phrases: string[]; message: string }> = [
  {
    code: "semantic-claim-violation",
    phrases: ["지금 퇴사하세요", "당장 퇴사", "회사를 그만두세요", "당장 이직하세요"],
    message: "직업 변화 판단이 직접 퇴사/이직 명령으로 바뀌었습니다.",
  },
  {
    code: "semantic-claim-violation",
    phrases: ["반드시 창업", "당장 창업", "바로 창업하세요"],
    message: "창업 판단이 조건 검증 없이 실행 명령으로 바뀌었습니다.",
  },
  {
    code: "semantic-claim-violation",
    phrases: ["수익 보장", "큰돈을 벌게", "무조건 수익", "투자하세요"],
    message: "재물 판단이 수익 보장이나 투자 지시로 바뀌었습니다.",
  },
  {
    code: "semantic-claim-violation",
    phrases: ["반드시 결혼", "무조건 재회", "헤어집니다"],
    message: "관계 판단이 결혼·재회·이별 확정으로 바뀌었습니다.",
  },
  {
    code: "semantic-claim-violation",
    phrases: ["암입니다", "질병입니다", "병에 걸립니다", "진단됩니다"],
    message: "건강 조언이 의학적 진단처럼 바뀌었습니다.",
  },
];

export const CONFIDENCE_TONE_RULES = {
  low: {
    maxExclusive: 40,
    requiredHints: ["가능성", "여지", "현재 확인되는 범위", "단정하기 어렵"],
    forbiddenHints: LOW_CONFIDENCE_ASSERTIONS,
  },
  medium: {
    minInclusive: 40,
    maxInclusive: 70,
    requiredHints: ["경향", "흐름", "가능성", "조건"],
    forbiddenHints: MID_CONFIDENCE_FORBIDDEN,
  },
  high: {
    minExclusive: 70,
    requiredHints: ["강하게 나타납니다", "뚜렷합니다", "흐름이 강"],
    forbiddenHints: ["반드시", "무조건", "100%", "절대"],
  },
};

function claimPattern(claim: ForbiddenClaim): RegExp {
  return new RegExp(claim.patternHint.replace(/[.*+?^${}()|[\]\\]/g, "\\$&").replace(/\\\|/g, "|"));
}

export function validateJudgmentPack(pack: JudgmentPack): JudgmentValidationResult {
  const issues: JudgmentValidationIssue[] = [];
  for (const judgment of pack.judgments) {
    if (judgment.evidence.length === 0) {
      issues.push({ code: "missing-evidence", severity: "error", message: `${judgment.code} 판단에 evidence가 없습니다.` });
    }
    if (judgment.triggeredRuleIds.length === 0) {
      issues.push({ code: "missing-rule", severity: "error", message: `${judgment.code} 판단에 rule id가 없습니다.` });
    }
    if (judgment.forbiddenClaims.length === 0) {
      issues.push({ code: "missing-forbidden-claim", severity: "error", message: `${judgment.code} 판단에 forbiddenClaims가 없습니다.` });
    }
    const { chart, luck, event, context, overall } = judgment.confidence;
    if ([chart, luck, event, context, overall].some((score) => score < 0 || score > 100 || Number.isNaN(score))) {
      issues.push({ code: "invalid-confidence", severity: "error", message: `${judgment.code} confidence 값이 0~100 범위를 벗어났습니다.` });
    }
  }
  return resultFromIssues(issues);
}

export function validateOutputAgainstJudgmentPack(params: { reply: string; pack: JudgmentPack }): JudgmentValidationResult {
  const issues = [...validateJudgmentPack(params.pack).issues];
  const allForbidden = [...params.pack.globalForbiddenClaims, ...params.pack.judgments.flatMap((judgment) => judgment.forbiddenClaims)];
  const seenForbidden = new Set<string>();
  for (const claim of allForbidden) {
    const hit = params.reply.match(claimPattern(claim))?.[0];
    if (hit && !seenForbidden.has(claim.code)) {
      seenForbidden.add(claim.code);
      issues.push({
        code: "forbidden-claim",
        severity: "error",
        message: `금지된 결론 표현이 출력되었습니다: ${claim.reason}`,
        evidence: hit,
      });
    }
  }

  const allowedDomains = new Set(params.pack.judgments.map((judgment) => judgment.domain));
  for (const claim of DOMAIN_CLAIMS) {
    if (allowedDomains.has(claim.domain)) continue;
    const hit = claim.phrases.find((keyword) => params.reply.includes(keyword));
    if (hit) {
      issues.push({
        code: "unsupported-domain-claim",
        severity: claim.highRisk ? "error" : "warning",
        message: `${claim.domain} 영역 판단이 JudgmentPack 없이 출력되었습니다.`,
        evidence: hit,
      });
    }
  }

  for (const rule of SEMANTIC_FORBIDDEN) {
    const hit = rule.phrases.find((phrase) => params.reply.includes(phrase));
    if (hit) {
      issues.push({
        code: rule.code,
        severity: "error",
        message: rule.message,
        evidence: hit,
      });
    }
  }

  const strongestConfidence = params.pack.judgments.reduce((max, judgment) => Math.max(max, judgment.confidence.overall), 0);
  const toneIssue = validateConfidenceTone(params.reply, strongestConfidence);
  if (toneIssue) issues.push(toneIssue);

  return resultFromIssues(issues);
}

function validateConfidenceTone(reply: string, strongestConfidence: number): JudgmentValidationIssue | null {
  if (strongestConfidence < CONFIDENCE_TONE_RULES.low.maxExclusive) {
    const hit = CONFIDENCE_TONE_RULES.low.forbiddenHints.find((phrase) => reply.includes(phrase));
    if (hit) {
      return {
        code: "confidence-tone-violation",
        severity: "error",
        message: "낮은 confidence에 비해 표현이 단정적입니다.",
        evidence: hit,
      };
    }
  }

  if (strongestConfidence >= CONFIDENCE_TONE_RULES.medium.minInclusive && strongestConfidence <= CONFIDENCE_TONE_RULES.medium.maxInclusive) {
    const hit = CONFIDENCE_TONE_RULES.medium.forbiddenHints.find((phrase) => reply.includes(phrase));
    if (hit) {
      return {
        code: "confidence-tone-violation",
        severity: "error",
        message: "중간 confidence에서는 확정 표현을 사용할 수 없습니다.",
        evidence: hit,
      };
    }
  }

  if (strongestConfidence > CONFIDENCE_TONE_RULES.high.minExclusive) {
    const hit = CONFIDENCE_TONE_RULES.high.forbiddenHints.find((phrase) => reply.includes(phrase));
    if (hit) {
      return {
        code: "confidence-tone-violation",
        severity: "error",
        message: "높은 confidence여도 필연·확정 표현은 금지됩니다.",
        evidence: hit,
      };
    }
  }

  return null;
}

function resultFromIssues(issues: JudgmentValidationIssue[]): JudgmentValidationResult {
  const hasError = issues.some((issue) => issue.severity === "error");
  return { ok: !hasError, status: hasError ? "rewrite" : "pass", issues };
}
