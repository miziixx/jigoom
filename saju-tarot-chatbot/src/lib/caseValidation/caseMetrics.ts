import type { JudgmentCode, RuleId } from "../judgmentTypes.js";
import type { CaseJudgmentOutcome, CaseValidationResult } from "./caseTypes.js";
import { FEEDBACK_SCORE } from "./caseTypes.js";

/**
 * 사례 검증 통계 (Case Metrics) — 읽기 전용 집계.
 *
 * 여러 CaseValidationResult를 모아 Rule/Judgment/Confidence 단위 통계를 만든다.
 * 이 통계는 confidence 보정을 위한 "자료"일 뿐, 자동으로 값을 바꾸지 않는다.
 */

export interface RuleMetric {
  ruleId: RuleId;
  triggerCount: number;
  matchCount: number;
  partialCount: number;
  missCount: number;
  scoredCount: number;
  /** scored 발생 건의 평균 점수 (0~100). scored가 없으면 null */
  avgScore: number | null;
  /** 트리거된 전체 건의 평균 confidence */
  avgConfidence: number;
  /** 이 rule이 포함된 사례들의 사용자 피드백 평균 (unsure 제외). 없으면 null */
  avgUserFeedback: number | null;
}

export interface JudgmentMetric {
  code: JudgmentCode;
  triggerCount: number;
  matchCount: number;
  partialCount: number;
  missCount: number;
  scoredCount: number;
  avgScore: number | null;
  avgConfidence: number;
}

export interface ConfidenceBin {
  /** 예: "60-79" */
  range: string;
  lower: number;
  upper: number;
  /** 이 confidence 구간의 예측 중앙값 */
  predictedMid: number;
  /** 구간에 든 scored 판단 수 */
  count: number;
  /** 구간의 실제 평균 적중 점수. count 0이면 null */
  avgScore: number | null;
}

export interface CaseMetrics {
  totalCases: number;
  totalJudgments: number;
  scoredJudgments: number;
  /** 전체 scored 판단 평균 점수 (0~100). 없으면 null */
  overallMatchRate: number | null;
  ruleMetrics: RuleMetric[];
  judgmentMetrics: JudgmentMetric[];
  confidenceBins: ConfidenceBin[];
  rewriteRate: number;
  fallbackRate: number;
}

function avg(nums: number[]): number | null {
  if (nums.length === 0) return null;
  return Math.round(nums.reduce((s, n) => s + n, 0) / nums.length);
}

interface RuleAcc {
  triggerCount: number;
  matchCount: number;
  partialCount: number;
  missCount: number;
  scores: number[];
  confidences: number[];
  feedback: number[];
}

interface CodeAcc {
  triggerCount: number;
  matchCount: number;
  partialCount: number;
  missCount: number;
  scores: number[];
  confidences: number[];
}

function bumpLevel(acc: RuleAcc | CodeAcc, o: CaseJudgmentOutcome): void {
  acc.triggerCount += 1;
  acc.confidences.push(o.confidence);
  if (!o.scored) return;
  acc.scores.push(o.score);
  if (o.level === "match") acc.matchCount += 1;
  else if (o.level === "partial") acc.partialCount += 1;
  else if (o.level === "miss") acc.missCount += 1;
}

const BIN_BOUNDS: { lower: number; upper: number }[] = [
  { lower: 0, upper: 19 },
  { lower: 20, upper: 39 },
  { lower: 40, upper: 59 },
  { lower: 60, upper: 79 },
  { lower: 80, upper: 100 },
];

export function computeMetrics(results: CaseValidationResult[]): CaseMetrics {
  const ruleAcc = new Map<RuleId, RuleAcc>();
  const codeAcc = new Map<JudgmentCode, CodeAcc>();
  const binScores: number[][] = BIN_BOUNDS.map(() => []);

  let totalJudgments = 0;
  let scoredJudgments = 0;
  const allScored: number[] = [];
  let rewrites = 0;
  let fallbacks = 0;

  for (const result of results) {
    if (result.rewriteUsed) rewrites += 1;
    if (result.fallbackUsed) fallbacks += 1;
    const feedbackScore =
      result.userRating != null ? FEEDBACK_SCORE[result.userRating] : null;

    for (const o of result.outcomes) {
      totalJudgments += 1;
      if (o.scored) {
        scoredJudgments += 1;
        allScored.push(o.score);
        const binIdx = BIN_BOUNDS.findIndex(
          (b) => o.confidence >= b.lower && o.confidence <= b.upper,
        );
        if (binIdx >= 0) binScores[binIdx].push(o.score);
      }

      // judgment code 집계
      let cAcc = codeAcc.get(o.code);
      if (!cAcc) {
        cAcc = {
          triggerCount: 0,
          matchCount: 0,
          partialCount: 0,
          missCount: 0,
          scores: [],
          confidences: [],
        };
        codeAcc.set(o.code, cAcc);
      }
      bumpLevel(cAcc, o);

      // rule 집계 (판단의 triggeredRuleIds 각각에 귀속)
      for (const ruleId of o.triggeredRuleIds) {
        let rAcc = ruleAcc.get(ruleId);
        if (!rAcc) {
          rAcc = {
            triggerCount: 0,
            matchCount: 0,
            partialCount: 0,
            missCount: 0,
            scores: [],
            confidences: [],
            feedback: [],
          };
          ruleAcc.set(ruleId, rAcc);
        }
        bumpLevel(rAcc, o);
        if (feedbackScore != null) rAcc.feedback.push(feedbackScore);
      }
    }
  }

  const ruleMetrics: RuleMetric[] = [...ruleAcc.entries()]
    .map(([ruleId, a]) => ({
      ruleId,
      triggerCount: a.triggerCount,
      matchCount: a.matchCount,
      partialCount: a.partialCount,
      missCount: a.missCount,
      scoredCount: a.scores.length,
      avgScore: avg(a.scores),
      avgConfidence: avg(a.confidences) ?? 0,
      avgUserFeedback: avg(a.feedback),
    }))
    .sort((x, y) => y.triggerCount - x.triggerCount);

  const judgmentMetrics: JudgmentMetric[] = [...codeAcc.entries()]
    .map(([code, a]) => ({
      code,
      triggerCount: a.triggerCount,
      matchCount: a.matchCount,
      partialCount: a.partialCount,
      missCount: a.missCount,
      scoredCount: a.scores.length,
      avgScore: avg(a.scores),
      avgConfidence: avg(a.confidences) ?? 0,
    }))
    .sort((x, y) => y.triggerCount - x.triggerCount);

  const confidenceBins: ConfidenceBin[] = BIN_BOUNDS.map((b, i) => ({
    range: `${b.lower}-${b.upper}`,
    lower: b.lower,
    upper: b.upper,
    predictedMid: Math.round((b.lower + b.upper) / 2),
    count: binScores[i].length,
    avgScore: avg(binScores[i]),
  }));

  const total = results.length;
  return {
    totalCases: total,
    totalJudgments,
    scoredJudgments,
    overallMatchRate: avg(allScored),
    ruleMetrics,
    judgmentMetrics,
    confidenceBins,
    rewriteRate: total > 0 ? Math.round((rewrites / total) * 100) : 0,
    fallbackRate: total > 0 ? Math.round((fallbacks / total) * 100) : 0,
  };
}
