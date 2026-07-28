import type { JudgmentDomain } from "../judgmentTypes.js";
import type { QualityEvent, ValidationOutcome } from "./qualityTypes.js";

/**
 * Quality 지표 집계 (순수·읽기 전용).
 * QualityEvent[] → Dashboard가 그릴 모든 숫자.
 */

export interface CountEntry {
  key: string;
  count: number;
}

export interface ReadingCounts {
  total: number;
  today: number;
  thisWeek: number;
  thisMonth: number;
}

export interface ValidationBreakdown {
  pass: number;
  warning: number;
  error: number;
  total: number;
  passRate: number; // 0~100
  warningRate: number;
  errorRate: number;
}

export interface RewriteBreakdown {
  attempted: number;
  succeeded: number;
  failed: number;
  attemptRate: number; // 발생률 0~100
  successRate: number; // 성공률 0~100 (attempted 대비)
  avgRewritePerReading: number; // 평균 rewrite 횟수
}

export interface FallbackBreakdown {
  count: number;
  rate: number; // 0~100
  reasonsTop: CountEntry[];
}

export interface DomainConfidence {
  domain: JudgmentDomain;
  avgConfidence: number;
  sampleCount: number;
}

export interface ValidationFailureLogEntry {
  timestamp: string;
  readingType: string;
  ruleIds: string[];
  reasonCodes: string[];
  validation: ValidationOutcome;
  rewrite: boolean;
  fallback: boolean;
}

export interface QualityMetrics {
  readingCounts: ReadingCounts;
  validation: ValidationBreakdown;
  rewrite: RewriteBreakdown;
  fallback: FallbackBreakdown;
  forbiddenClaimsTop10: CountEntry[];
  confidenceByDomain: DomainConfidence[];
  judgmentTop20: CountEntry[];
  ruleTop20: CountEntry[];
  contradictionTop10: CountEntry[];
  recentFailures: ValidationFailureLogEntry[];
}

const DAY_MS = 24 * 60 * 60 * 1000;

function startOfDay(d: Date): number {
  return new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
}

function round(n: number, digits = 0): number {
  const f = 10 ** digits;
  return Math.round(n * f) / f;
}

function rate(part: number, whole: number): number {
  return whole > 0 ? round((part / whole) * 100, 1) : 0;
}

/** 빈도 집계 → 내림차순 상위 N */
function topCounts(keys: string[], limit: number): CountEntry[] {
  const map = new Map<string, number>();
  for (const k of keys) map.set(k, (map.get(k) ?? 0) + 1);
  return [...map.entries()]
    .map(([key, count]) => ({ key, count }))
    .sort((a, b) => b.count - a.count || a.key.localeCompare(b.key))
    .slice(0, limit);
}

function computeReadingCounts(events: QualityEvent[], now: Date): ReadingCounts {
  const todayStart = startOfDay(now);
  const weekStart = todayStart - 6 * DAY_MS; // 오늘 포함 최근 7일
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1).getTime();
  let today = 0;
  let thisWeek = 0;
  let thisMonth = 0;
  for (const e of events) {
    const t = Date.parse(e.timestamp);
    if (Number.isNaN(t)) continue;
    if (t >= todayStart) today += 1;
    if (t >= weekStart) thisWeek += 1;
    if (t >= monthStart) thisMonth += 1;
  }
  return { total: events.length, today, thisWeek, thisMonth };
}

function computeValidation(events: QualityEvent[]): ValidationBreakdown {
  let pass = 0;
  let warning = 0;
  let error = 0;
  for (const e of events) {
    if (e.validation === "pass") pass += 1;
    else if (e.validation === "warning") warning += 1;
    else error += 1;
  }
  const total = events.length;
  return {
    pass,
    warning,
    error,
    total,
    passRate: rate(pass, total),
    warningRate: rate(warning, total),
    errorRate: rate(error, total),
  };
}

function computeRewrite(events: QualityEvent[]): RewriteBreakdown {
  const attempted = events.filter((e) => e.rewriteAttempted).length;
  const succeeded = events.filter((e) => e.rewriteSucceeded).length;
  const failed = attempted - succeeded;
  return {
    attempted,
    succeeded,
    failed,
    attemptRate: rate(attempted, events.length),
    successRate: rate(succeeded, attempted),
    // 현 엔진은 리딩당 최대 1회 rewrite. attempted/total로 평균 횟수를 낸다.
    avgRewritePerReading: events.length > 0 ? round(attempted / events.length, 2) : 0,
  };
}

function computeFallback(events: QualityEvent[]): FallbackBreakdown {
  const fallbacks = events.filter((e) => e.fallbackUsed);
  const reasons = fallbacks.flatMap((e) => e.fallbackReasonCodes);
  return {
    count: fallbacks.length,
    rate: rate(fallbacks.length, events.length),
    reasonsTop: topCounts(reasons, 10),
  };
}

function computeConfidenceByDomain(events: QualityEvent[]): DomainConfidence[] {
  const sums = new Map<JudgmentDomain, { sum: number; count: number }>();
  for (const e of events) {
    for (const j of e.judgments) {
      const cur = sums.get(j.domain) ?? { sum: 0, count: 0 };
      cur.sum += j.confidence;
      cur.count += 1;
      sums.set(j.domain, cur);
    }
  }
  return [...sums.entries()]
    .map(([domain, { sum, count }]) => ({
      domain,
      avgConfidence: count > 0 ? round(sum / count, 1) : 0,
      sampleCount: count,
    }))
    .sort((a, b) => b.sampleCount - a.sampleCount);
}

function computeRecentFailures(events: QualityEvent[], limit: number): ValidationFailureLogEntry[] {
  return events
    .filter((e) => e.validation !== "pass" || e.rewriteAttempted || e.fallbackUsed)
    .slice()
    .sort((a, b) => Date.parse(b.timestamp) - Date.parse(a.timestamp))
    .slice(0, limit)
    .map((e) => ({
      timestamp: e.timestamp,
      readingType: e.readingType,
      ruleIds: e.ruleIds,
      reasonCodes: uniqReasons(e),
      validation: e.validation,
      rewrite: e.rewriteAttempted,
      fallback: e.fallbackUsed,
    }));
}

function uniqReasons(e: QualityEvent): string[] {
  return [...new Set([...e.validationIssueCodes, ...e.fallbackReasonCodes])];
}

export function computeQualityMetrics(events: QualityEvent[], now: Date = new Date()): QualityMetrics {
  return {
    readingCounts: computeReadingCounts(events, now),
    validation: computeValidation(events),
    rewrite: computeRewrite(events),
    fallback: computeFallback(events),
    forbiddenClaimsTop10: topCounts(events.flatMap((e) => e.forbiddenClaimCodes), 10),
    confidenceByDomain: computeConfidenceByDomain(events),
    judgmentTop20: topCounts(events.flatMap((e) => e.judgments.map((j) => j.code)), 20),
    ruleTop20: topCounts(events.flatMap((e) => e.ruleIds), 20),
    contradictionTop10: topCounts(events.flatMap((e) => e.contradictionCodes), 10),
    recentFailures: computeRecentFailures(events, 20),
  };
}
