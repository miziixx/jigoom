import type { JudgmentCandidate, JudgmentContradiction } from "./judgmentTypes.js";

function has(judgments: JudgmentCandidate[], code: JudgmentCandidate["code"]): JudgmentCandidate | undefined {
  return judgments.find((judgment) => judgment.code === code);
}

export function detectContradictions(judgments: JudgmentCandidate[]): JudgmentContradiction[] {
  const contradictions: JudgmentContradiction[] = [];
  const careerChange = has(judgments, "CAREER_CHANGE_HIGH");
  const startupNo = has(judgments, "STARTUP_NOT_RECOMMENDED");
  if (careerChange && startupNo) {
    contradictions.push({
      id: "contradiction.career_change.startup_not_recommended",
      severity: "warning",
      judgmentIds: [careerChange.id, startupNo.id],
      message: "직업 변화 가능성과 창업 비추천이 함께 있으므로, 변화는 말하되 즉시 창업 권유로 번역하면 안 됩니다.",
      resolution: "prefer-caution",
    });
  }

  const moneyRisk = has(judgments, "MONEY_RISK_MEDIUM");
  const startupTest = has(judgments, "STARTUP_TEST_FIRST");
  if (moneyRisk && startupTest) {
    contradictions.push({
      id: "contradiction.money_risk.startup_test_first",
      severity: "warning",
      judgmentIds: [moneyRisk.id, startupTest.id],
      message: "수익 위험과 창업 실험 신호가 함께 있으므로, 비용이 큰 실행이나 확장 표현을 금지해야 합니다.",
      resolution: "prefer-caution",
    });
  }

  const loveStable = has(judgments, "LOVE_STABLE");
  const loveDelay = has(judgments, "LOVE_DELAY");
  if (loveStable && loveDelay) {
    contradictions.push({
      id: "contradiction.love_stable.love_delay",
      severity: "error",
      judgmentIds: [loveStable.id, loveDelay.id],
      message: "관계 안정과 관계 지연 판단이 동시에 생성되었습니다.",
      resolution: "manual-review",
    });
  }

  const moneyOpportunity = has(judgments, "MONEY_OPPORTUNITY");
  if (moneyRisk && moneyOpportunity && Math.abs(moneyRisk.confidence.overall - moneyOpportunity.confidence.overall) < 15) {
    contradictions.push({
      id: "contradiction.money_opportunity.money_risk",
      severity: "warning",
      judgmentIds: [moneyRisk.id, moneyOpportunity.id],
      message: "재물 기회와 재물 위험이 비슷한 강도로 함께 있어 단정 수익 표현은 피해야 합니다.",
      resolution: "downgrade-confidence",
    });
  }

  return contradictions;
}
