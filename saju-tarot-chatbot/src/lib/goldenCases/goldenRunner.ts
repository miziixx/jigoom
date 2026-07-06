import { computeLuckCycles, computeSajuChart } from "../saju.js";
import { buildReadingJudgmentPack } from "../../prompts/systemPrompt.js";
import { validateJudgmentPack } from "../judgmentValidation.js";
import type { JudgmentPack } from "../judgmentTypes.js";
import type {
  ConfidenceRange,
  GoldenCase,
  GoldenCheckResult,
  GoldenSummary,
} from "./goldenTypes.js";

/**
 * Golden 러너 (순수·결정론, LLM 미호출).
 *
 * 케이스 입력 → 실제 계산 파이프라인으로 JudgmentPack 생성 → 압축 요약 → 허용범위 검사.
 * 계산·룰·판단 로직은 호출만 하고 절대 수정하지 않는다.
 */

function uniq<T>(arr: T[]): T[] {
  return [...new Set(arr)];
}

function round(n: number, digits = 0): number {
  const f = 10 ** digits;
  return Math.round(n * f) / f;
}

/** 케이스 입력으로 실제 JudgmentPack을 결정론적으로 만든다 */
export function buildPackForCase(input: GoldenCase["input"]): JudgmentPack | null {
  const chart = computeSajuChart(input.birth);
  const refDate = new Date(input.referenceDate);
  const includeMonthlyFlow = input.type === "saju" || input.type === "combo";
  const luckCycles = computeLuckCycles(input.birth, refDate, {
    includeMonthlyFlow,
    yongElements: chart.yongshin?.supportive ?? chart.yongshin?.yongshin,
    avoidElements: chart.yongshin?.unfavorable,
  });
  return buildReadingJudgmentPack({
    type: input.type,
    question: input.question ?? "",
    focus: input.focus,
    context: input.context ?? { depth: "light" },
    gender: input.birth.gender,
    sajuChart: chart,
    luckCycles,
  });
}

export function summarizeJudgmentPack(pack: JudgmentPack | null): GoldenSummary {
  if (!pack) {
    return {
      packGenerated: false,
      judgmentCodes: [],
      domains: [],
      confidenceByCode: {},
      overallConfidenceAvg: null,
      contradictionIds: [],
      ruleIds: [],
      evidenceIds: [],
      forbiddenClaimCodes: [],
      structurallyValid: false,
      validationIssueCodes: [],
    };
  }
  const confidenceByCode: Record<string, number> = {};
  const confidences: number[] = [];
  for (const j of pack.judgments) {
    confidenceByCode[j.code] = j.confidence.overall;
    confidences.push(j.confidence.overall);
  }
  const evidenceIds = uniq([
    ...pack.evidence.map((e) => e.id),
    ...pack.judgments.flatMap((j) => j.evidence.map((e) => e.id)),
  ]);
  const forbiddenClaimCodes = uniq([
    ...pack.globalForbiddenClaims.map((f) => f.code),
    ...pack.judgments.flatMap((j) => j.forbiddenClaims.map((f) => f.code)),
  ]);
  const validation = validateJudgmentPack(pack);

  return {
    packGenerated: true,
    judgmentCodes: pack.judgments.map((j) => j.code),
    domains: uniq(pack.judgments.map((j) => j.domain)),
    confidenceByCode,
    overallConfidenceAvg:
      confidences.length > 0 ? round(confidences.reduce((s, n) => s + n, 0) / confidences.length, 1) : null,
    contradictionIds: pack.contradictions.map((c) => c.id),
    ruleIds: uniq(pack.triggeredRules.map((r) => r.id)),
    evidenceIds,
    forbiddenClaimCodes,
    structurallyValid: validation.ok,
    validationIssueCodes: uniq(validation.issues.map((i) => i.code)),
  };
}

function inRange(value: number, range: ConfidenceRange): boolean {
  if (range.min != null && value < range.min) return false;
  if (range.max != null && value > range.max) return false;
  return true;
}

function rangeText(range: ConfidenceRange): string {
  return `[${range.min ?? "-"}, ${range.max ?? "-"}]`;
}

/** 케이스를 검사해 실패 사유 목록을 만든다 (빈 배열 = 통과) */
export function checkGoldenCase(def: GoldenCase): GoldenCheckResult {
  const pack = buildPackForCase(def.input);
  const summary = summarizeJudgmentPack(pack);
  const e = def.expect;
  const failures: string[] = [];

  // pack 생성 여부
  if (!summary.packGenerated) {
    failures.push("JudgmentPack이 생성되지 않았습니다 (type/depth 확인: saju·combo + light).");
    return { id: def.id, ok: false, failures, summary };
  }

  const codeSet = new Set(summary.judgmentCodes);
  const domainSet = new Set(summary.domains);
  const evidenceSet = new Set(summary.evidenceIds);
  const contradictionSet = new Set(summary.contradictionIds);

  // 필수 judgment code (부분집합)
  for (const code of e.requiredJudgmentCodes ?? []) {
    if (!codeSet.has(code)) failures.push(`필수 judgment code 누락: ${code}`);
  }
  // 금지 judgment code
  for (const code of e.forbiddenJudgmentCodes ?? []) {
    if (codeSet.has(code)) failures.push(`나오면 안 되는 judgment code 발생: ${code}`);
  }
  // 필수 도메인
  for (const domain of e.requiredDomains ?? []) {
    if (!domainSet.has(domain)) failures.push(`필수 도메인 커버리지 누락: ${domain}`);
  }
  // 최소 도메인 수
  if (e.minDomainCoverage != null && domainSet.size < e.minDomainCoverage) {
    failures.push(`도메인 커버리지 부족: ${domainSet.size} < ${e.minDomainCoverage}`);
  }
  // 구조 검증 / forbidden-claim 구조 결함
  const wantStructurallyValid = e.structurallyValid ?? true;
  if (wantStructurallyValid && !summary.structurallyValid) {
    failures.push(`구조 검증 실패: ${summary.validationIssueCodes.join(", ")}`);
  }
  const wantNoForbiddenViolation = e.expectNoForbiddenClaimViolation ?? true;
  if (
    wantNoForbiddenViolation &&
    summary.validationIssueCodes.some((c) => c === "forbidden-claim" || c === "missing-forbidden-claim")
  ) {
    failures.push(`forbidden-claim 구조 결함 발생: ${summary.validationIssueCodes.join(", ")}`);
  }
  // 게이트가 구조상 rewrite를 강제하지 않아야 함(구조 유효 = 강제 rewrite 없음)
  if ((e.expectGateWouldNotForceRewrite ?? false) && !summary.structurallyValid) {
    failures.push("구조 결함으로 rewrite가 강제될 수 있습니다.");
  }
  // 전체 confidence 구간
  if (e.overallConfidence && summary.overallConfidenceAvg != null) {
    if (!inRange(summary.overallConfidenceAvg, e.overallConfidence)) {
      failures.push(
        `전체 confidence ${summary.overallConfidenceAvg}가 허용범위 ${rangeText(e.overallConfidence)} 밖`,
      );
    }
  }
  // code별 confidence 구간
  for (const [code, range] of Object.entries(e.confidenceByCode ?? {})) {
    const value = summary.confidenceByCode[code];
    if (value == null) {
      failures.push(`confidence 검사 대상 code 없음: ${code}`);
    } else if (range && !inRange(value, range)) {
      failures.push(`${code} confidence ${value}가 허용범위 ${rangeText(range)} 밖`);
    }
  }
  // contradiction 허용 집합 / 개수
  if (e.allowedContradictionIds) {
    const allowed = new Set(e.allowedContradictionIds);
    for (const id of contradictionSet) {
      if (!allowed.has(id)) failures.push(`허용되지 않은 contradiction 발생: ${id}`);
    }
  }
  if (e.maxContradictions != null && contradictionSet.size > e.maxContradictions) {
    failures.push(`contradiction 개수 초과: ${contradictionSet.size} > ${e.maxContradictions}`);
  }
  // 필수 evidence id
  for (const id of e.requiredEvidenceIds ?? []) {
    if (!evidenceSet.has(id)) failures.push(`필수 evidence id 누락: ${id}`);
  }

  return { id: def.id, ok: failures.length === 0, failures, summary };
}
