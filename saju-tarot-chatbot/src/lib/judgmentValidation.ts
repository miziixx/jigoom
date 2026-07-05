import type { ForbiddenClaim, JudgmentDomain, JudgmentPack } from "./judgmentTypes.js";

export type JudgmentValidationIssueCode =
  | "missing-evidence"
  | "missing-rule"
  | "missing-forbidden-claim"
  | "invalid-confidence"
  | "forbidden-claim"
  | "unsupported-domain-claim";

export interface JudgmentValidationIssue {
  code: JudgmentValidationIssueCode;
  severity: "warning" | "error";
  message: string;
  evidence?: string;
}

export interface JudgmentValidationResult {
  ok: boolean;
  issues: JudgmentValidationIssue[];
}

const DOMAIN_KEYWORDS: Partial<Record<JudgmentDomain, string[]>> = {
  career: ["퇴사", "당장 이직", "회사를 그만"],
  money: ["투자하세요", "큰돈", "수익 보장"],
  love: ["결혼합니다", "재회합니다", "헤어집니다"],
  health: ["질병", "암", "진단"],
  startup: ["당장 창업", "반드시 창업"],
  move: ["반드시 이사", "당장 옮기"],
  family: ["가족과 끊", "가족 때문에 망"],
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
  return { ok: issues.every((issue) => issue.severity !== "error"), issues };
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
  for (const [domain, keywords] of Object.entries(DOMAIN_KEYWORDS) as Array<[JudgmentDomain, string[]]>) {
    if (allowedDomains.has(domain)) continue;
    const hit = keywords.find((keyword) => params.reply.includes(keyword));
    if (hit) {
      issues.push({
        code: "unsupported-domain-claim",
        severity: "warning",
        message: `${domain} 영역 판단이 JudgmentPack 없이 출력되었을 수 있습니다.`,
        evidence: hit,
      });
    }
  }

  return { ok: issues.every((issue) => issue.severity !== "error"), issues };
}
