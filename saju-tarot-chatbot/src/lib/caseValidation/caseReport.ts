import type { CaseDomain, CaseValidationResult } from "./caseTypes.js";
import type { CaseMetrics, RuleMetric } from "./caseMetrics.js";
import { computeMetrics } from "./caseMetrics.js";
import { DOMAIN_LABEL } from "../eventEngine.js";
import { CODE_EXPECTATION } from "./caseScore.js";

/**
 * 사례 검증 리포트 (Case Validation Report) — 읽기 전용.
 *
 * 전체 적중률, 분야별 적중, Rule Top/Best/Worst, rewrite/fallback 발생률, confidence 분포,
 * 그리고 "자동 보정 후보"와 "사람 검토 필요" 항목을 정리한다.
 * 이 리포트는 자료 제시일 뿐, 값을 자동으로 바꾸지 않는다.
 */

export interface DomainMatch {
  domain: CaseDomain;
  label: string;
  scoredCount: number;
  avgScore: number | null;
}

export interface CalibrationSuggestion {
  ruleId: string;
  currentAvgConfidence: number;
  observedMatchRate: number;
  scoredCount: number;
  /** confidence와 실제 적중률의 차이 (양수=자신감 과다, 음수=과소) */
  gap: number;
  note: string;
}

export interface CaseValidationReport {
  generatedAt: string;
  totalCases: number;
  totalJudgments: number;
  scoredJudgments: number;
  overallMatchRate: number | null;
  domainMatches: DomainMatch[];
  topRules: RuleMetric[];
  bestRules: RuleMetric[];
  worstRules: RuleMetric[];
  rewriteRate: number;
  fallbackRate: number;
  confidenceBins: CaseMetrics["confidenceBins"];
  /** 통계상 confidence 보정이 검토될 만한 rule (자동 적용 아님) */
  calibrationSuggestions: CalibrationSuggestion[];
  /** 아직 사람 검토가 필요한 부분 */
  humanReviewNotes: string[];
}

export interface ReportOptions {
  /** best/worst/보정 후보로 뽑기 위한 최소 scored 표본 수 */
  minSample?: number;
  /** confidence-실제 적중 gap이 이 값을 넘으면 보정 후보 */
  calibrationGap?: number;
  now?: () => Date;
}

const ALL_DOMAINS: CaseDomain[] = ["career", "money", "love", "health", "family", "move", "startup"];

function domainMatches(results: CaseValidationResult[]): DomainMatch[] {
  const scoresByDomain = new Map<CaseDomain, number[]>();
  for (const r of results) {
    for (const o of r.outcomes) {
      if (!o.scored || o.domain === "general") continue;
      const arr = scoresByDomain.get(o.domain) ?? [];
      arr.push(o.score);
      scoresByDomain.set(o.domain, arr);
    }
  }
  return ALL_DOMAINS.map((domain) => {
    const arr = scoresByDomain.get(domain) ?? [];
    return {
      domain,
      label: DOMAIN_LABEL[domain],
      scoredCount: arr.length,
      avgScore: arr.length > 0 ? Math.round(arr.reduce((s, n) => s + n, 0) / arr.length) : null,
    };
  }).filter((d) => d.scoredCount > 0);
}

export function buildCaseReport(
  results: CaseValidationResult[],
  options: ReportOptions = {},
): CaseValidationReport {
  const minSample = options.minSample ?? 2;
  const calibrationGap = options.calibrationGap ?? 20;
  const now = options.now ?? (() => new Date());
  const metrics = computeMetrics(results);

  const scoredRules = metrics.ruleMetrics.filter(
    (r) => r.scoredCount >= minSample && r.avgScore != null,
  );
  const bestRules = [...scoredRules].sort((a, b) => (b.avgScore ?? 0) - (a.avgScore ?? 0)).slice(0, 10);
  const worstRules = [...scoredRules].sort((a, b) => (a.avgScore ?? 0) - (b.avgScore ?? 0)).slice(0, 10);
  const topRules = metrics.ruleMetrics.slice(0, 10);

  const calibrationSuggestions: CalibrationSuggestion[] = scoredRules
    .map((r) => {
      const observed = r.avgScore ?? 0;
      const gap = Math.round(r.avgConfidence - observed);
      return {
        ruleId: r.ruleId,
        currentAvgConfidence: r.avgConfidence,
        observedMatchRate: observed,
        scoredCount: r.scoredCount,
        gap,
        note:
          gap > 0
            ? `confidence(${r.avgConfidence})가 실제 적중(${observed})보다 높음 — 자신감 과다 가능. 사람 검토 후 하향 검토 대상.`
            : `confidence(${r.avgConfidence})가 실제 적중(${observed})보다 낮음 — 과소평가 가능. 사람 검토 후 상향 검토 대상.`,
      };
    })
    .filter((s) => Math.abs(s.gap) >= calibrationGap)
    .sort((a, b) => Math.abs(b.gap) - Math.abs(a.gap));

  const humanReviewNotes: string[] = [];
  if (results.length < 20) {
    humanReviewNotes.push(
      `사례가 ${results.length}건으로 통계 신뢰에는 부족합니다. 자동 보정 없이 자료로만 사용하세요 (권장 20건 이상).`,
    );
  }
  const lowSampleRules = metrics.ruleMetrics.filter((r) => r.scoredCount < minSample);
  if (lowSampleRules.length > 0) {
    humanReviewNotes.push(
      `표본 부족 rule ${lowSampleRules.length}개(${lowSampleRules.map((r) => r.ruleId).join(", ")})는 판단 유보 — 더 많은 사례 필요.`,
    );
  }
  const noExpert = results.every((r) => r.expertVerdict == null);
  if (noExpert) {
    humanReviewNotes.push("전문가 검토(ExpertReview)가 아직 없습니다. best/worst rule은 사용자 결과 기반 추정치입니다.");
  }
  // GENERAL_MIXED_FLOW 등 예측 없는 판단은 대조 불가임을 명시
  const noneCodes = Object.entries(CODE_EXPECTATION)
    .filter(([, v]) => v.predicted === "none")
    .map(([code]) => code);
  if (noneCodes.length > 0) {
    humanReviewNotes.push(
      `예측 방향이 없는 판단(${noneCodes.join(", ")})은 자동 대조 대상이 아니며 사람 판단이 필요합니다.`,
    );
  }

  return {
    generatedAt: now().toISOString(),
    totalCases: metrics.totalCases,
    totalJudgments: metrics.totalJudgments,
    scoredJudgments: metrics.scoredJudgments,
    overallMatchRate: metrics.overallMatchRate,
    domainMatches: domainMatches(results),
    topRules,
    bestRules,
    worstRules,
    rewriteRate: metrics.rewriteRate,
    fallbackRate: metrics.fallbackRate,
    confidenceBins: metrics.confidenceBins,
    calibrationSuggestions,
    humanReviewNotes,
  };
}

/** 리포트를 로그·문서용 텍스트로 (개발자용). */
export function formatCaseReport(report: CaseValidationReport): string {
  const lines: string[] = [];
  lines.push("# 사례 검증 리포트 (Case Validation Report)");
  lines.push(`- 생성: ${report.generatedAt}`);
  lines.push(`- 사례 수: ${report.totalCases}`);
  lines.push(`- 판단 수: ${report.totalJudgments} (대조 가능 ${report.scoredJudgments})`);
  lines.push(`- 전체 적중률: ${report.overallMatchRate ?? "N/A"}`);
  lines.push(`- Rewrite 발생률: ${report.rewriteRate}% / Fallback 발생률: ${report.fallbackRate}%`);

  lines.push("\n## 분야별 적중");
  for (const d of report.domainMatches) {
    lines.push(`- ${d.label}: ${d.avgScore ?? "N/A"} (n=${d.scoredCount})`);
  }

  lines.push("\n## Rule Top (트리거 빈도순)");
  for (const r of report.topRules) {
    lines.push(
      `- ${r.ruleId}: 트리거 ${r.triggerCount}, 적중 ${r.matchCount}/부분 ${r.partialCount}/빗나감 ${r.missCount}, 평균 ${r.avgScore ?? "N/A"}, conf ${r.avgConfidence}`,
    );
  }

  lines.push("\n## Best Rules");
  for (const r of report.bestRules) lines.push(`- ${r.ruleId}: ${r.avgScore} (n=${r.scoredCount})`);
  lines.push("\n## Worst Rules");
  for (const r of report.worstRules) lines.push(`- ${r.ruleId}: ${r.avgScore} (n=${r.scoredCount})`);

  lines.push("\n## Confidence 분포 (예측 confidence 구간 → 실제 적중)");
  for (const b of report.confidenceBins) {
    lines.push(`- ${b.range} (예측 중앙 ${b.predictedMid}): 실제 ${b.avgScore ?? "N/A"} (n=${b.count})`);
  }

  lines.push("\n## 자동 보정 후보 (검토 후 적용, 자동 변경 아님)");
  if (report.calibrationSuggestions.length === 0) lines.push("- 없음");
  for (const s of report.calibrationSuggestions) lines.push(`- ${s.ruleId}: gap ${s.gap} — ${s.note}`);

  lines.push("\n## 사람 검토 필요");
  for (const n of report.humanReviewNotes) lines.push(`- ${n}`);

  return lines.join("\n");
}
