import type { QualityEvent } from "./qualityTypes.js";
import { computeQualityMetrics, type QualityMetrics } from "./qualityMetrics.js";

/**
 * Engine Health Score (0~100) — 여러 품질 지표를 가중 합산한 종합 점수.
 *
 * 핵심 요구사항: Health가 왜 올라갔는지/내려갔는지 추적 가능해야 한다.
 * 그래서 점수를 컴포넌트별 breakdown(가중치·점수·기여도·설명)으로 분해하고,
 * 두 시점 Health를 비교하는 explainHealthChange를 제공한다.
 *
 * 처음에는 단순 가중치로 시작한다 (요구사항대로). 가중치는 한 곳(HEALTH_WEIGHTS)에서만 관리.
 */

export const HEALTH_WEIGHTS = {
  validationPass: 40,
  rewriteSuccess: 20,
  fallback: 15,
  confidenceStability: 15,
  ruleCoverage: 10,
} as const;

export type HealthComponentKey = keyof typeof HEALTH_WEIGHTS;

export interface HealthComponent {
  key: HealthComponentKey;
  label: string;
  weight: number;
  /** 컴포넌트 점수 0~100 */
  score: number;
  /** 가중 기여도 = weight * score / 100 */
  contribution: number;
  /** 왜 이 점수인지 사람이 읽는 설명 */
  note: string;
}

export interface EngineHealth {
  /** 종합 점수 0~100 */
  score: number;
  hasData: boolean;
  sampleCount: number;
  components: HealthComponent[];
  summary: string;
}

const LABELS: Record<HealthComponentKey, string> = {
  validationPass: "Validation Pass",
  rewriteSuccess: "Rewrite Success",
  fallback: "Fallback 억제",
  confidenceStability: "Confidence Stability",
  ruleCoverage: "Rule Coverage",
};

function round(n: number, digits = 0): number {
  const f = 10 ** digits;
  return Math.round(n * f) / f;
}

function clamp(n: number, lo = 0, hi = 100): number {
  return Math.max(lo, Math.min(hi, n));
}

/** 전체 판단 confidence의 평균·표준편차 */
function confidenceStats(events: QualityEvent[]): { mean: number; stdev: number; count: number } {
  const vals: number[] = [];
  for (const e of events) for (const j of e.judgments) vals.push(j.confidence);
  if (vals.length === 0) return { mean: 0, stdev: 0, count: 0 };
  const mean = vals.reduce((s, n) => s + n, 0) / vals.length;
  const variance = vals.reduce((s, n) => s + (n - mean) ** 2, 0) / vals.length;
  return { mean, stdev: Math.sqrt(variance), count: vals.length };
}

/** rule을 하나라도 발동시킨 리딩 비율 (일반 흐름으로만 떨어지지 않았는가) */
function ruleCoverageRate(events: QualityEvent[]): number {
  if (events.length === 0) return 0;
  const withRule = events.filter((e) => e.ruleIds.length > 0).length;
  return (withRule / events.length) * 100;
}

export function computeEngineHealth(
  events: QualityEvent[],
  metricsInput?: QualityMetrics,
): EngineHealth {
  const metrics = metricsInput ?? computeQualityMetrics(events);
  const hasData = events.length > 0;

  // 1. Validation Pass
  const validationPass = metrics.validation.passRate;

  // 2. Rewrite Success: rewrite가 없었으면(문제 없음) 100, 있었으면 성공률
  const rewriteSuccess = metrics.rewrite.attempted === 0 ? 100 : metrics.rewrite.successRate;

  // 3. Fallback 억제: fallback이 적을수록 높다
  const fallback = clamp(100 - metrics.fallback.rate);

  // 4. Confidence Stability: 평균 신뢰도와 일관성(낮은 분산)을 반반 반영
  const cs = confidenceStats(events);
  const consistency = clamp(100 - cs.stdev * 2);
  const confidenceStability = hasData ? round(0.5 * cs.mean + 0.5 * consistency) : 100;

  // 5. Rule Coverage
  const ruleCoverage = hasData ? round(ruleCoverageRate(events)) : 100;

  const raw: Record<HealthComponentKey, { score: number; note: string }> = {
    validationPass: {
      score: validationPass,
      note: `출력 검증 통과율 ${validationPass}% (pass ${metrics.validation.pass}/${metrics.validation.total})`,
    },
    rewriteSuccess: {
      score: rewriteSuccess,
      note:
        metrics.rewrite.attempted === 0
          ? "재작성이 필요한 리딩 없음"
          : `재작성 성공률 ${metrics.rewrite.successRate}% (성공 ${metrics.rewrite.succeeded}/${metrics.rewrite.attempted})`,
    },
    fallback: {
      score: fallback,
      note: `Fallback 발생률 ${metrics.fallback.rate}% (${metrics.fallback.count}건)`,
    },
    confidenceStability: {
      score: confidenceStability,
      note: hasData
        ? `평균 confidence ${round(cs.mean, 1)}, 표준편차 ${round(cs.stdev, 1)}`
        : "데이터 없음",
    },
    ruleCoverage: {
      score: ruleCoverage,
      note: hasData ? `rule 발동 리딩 비율 ${ruleCoverage}%` : "데이터 없음",
    },
  };

  const components: HealthComponent[] = (Object.keys(HEALTH_WEIGHTS) as HealthComponentKey[]).map((key) => {
    const weight = HEALTH_WEIGHTS[key];
    const score = clamp(round(raw[key].score));
    return {
      key,
      label: LABELS[key],
      weight,
      score,
      contribution: round((weight * score) / 100, 1),
      note: raw[key].note,
    };
  });

  const score = clamp(round(components.reduce((s, c) => s + c.contribution, 0)));
  const summary = hasData
    ? `${events.length}건 기준 종합 ${score}/100`
    : "관찰된 리딩이 없습니다. 리딩이 실행되면 품질 신호가 쌓입니다.";

  return { score, hasData, sampleCount: events.length, components, summary };
}

// ── Health 변화 추적 (왜 올라갔는지/내려갔는지) ──────────

export interface HealthDelta {
  key: HealthComponentKey;
  label: string;
  before: number;
  after: number;
  /** 컴포넌트 점수 변화 */
  scoreDelta: number;
  /** 종합점수 기여도 변화 (가중 반영) */
  contributionDelta: number;
}

export interface HealthChangeExplanation {
  overallDelta: number;
  movers: HealthDelta[];
  notes: string[];
}

/** 두 시점 Health를 비교해 어떤 컴포넌트가 점수를 올리고 내렸는지 설명한다. */
export function explainHealthChange(before: EngineHealth, after: EngineHealth): HealthChangeExplanation {
  const beforeByKey = new Map(before.components.map((c) => [c.key, c]));
  const movers: HealthDelta[] = after.components
    .map((c) => {
      const prev = beforeByKey.get(c.key);
      const b = prev?.score ?? 0;
      const bc = prev?.contribution ?? 0;
      return {
        key: c.key,
        label: c.label,
        before: b,
        after: c.score,
        scoreDelta: round(c.score - b, 1),
        contributionDelta: round(c.contribution - bc, 1),
      };
    })
    .filter((d) => d.scoreDelta !== 0)
    .sort((a, b) => Math.abs(b.contributionDelta) - Math.abs(a.contributionDelta));

  const overallDelta = round(after.score - before.score, 1);
  const notes: string[] = [];
  if (movers.length === 0) {
    notes.push("변화 없음");
  } else {
    for (const m of movers.slice(0, 3)) {
      const dir = m.contributionDelta >= 0 ? "상승" : "하락";
      notes.push(
        `${m.label} ${m.before}→${m.after} (종합 ${m.contributionDelta >= 0 ? "+" : ""}${m.contributionDelta}점 ${dir})`,
      );
    }
  }
  return { overallDelta, movers, notes };
}
