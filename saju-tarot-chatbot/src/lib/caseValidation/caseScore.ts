import type { JudgmentCode, RuleId } from "../judgmentTypes.js";
import type {
  CaseDomain,
  CaseDomainOutcome,
  MatchLevel,
  PredictedDirection,
} from "./caseTypes.js";
import { MATCH_SCORE } from "./caseTypes.js";

/**
 * 사례 검증 채점 로직 (순수·결정론).
 *
 * 각 JudgmentCode는 특정 분야에 대해 하나의 "방향"을 예측한다.
 * 실제 사례의 그 분야 결과(사건 발생 여부 + 방향)와 대조해 match/partial/minor/miss 등급을 매긴다.
 *
 * 여기서는 Rule/Judgment/confidence를 바꾸지 않는다. 오직 "예측 방향 ↔ 실제" 매핑만 한다.
 */

interface CodeExpectation {
  domain: CaseDomain | "general";
  predicted: PredictedDirection;
}

/**
 * 판단 code → (분야, 예측 방향).
 * judgmentEngine.codeForRule / CONCLUSION_BY_CODE의 의미를 그대로 반영한다.
 */
export const CODE_EXPECTATION: Record<JudgmentCode, CodeExpectation> = {
  CAREER_CHANGE_HIGH: { domain: "career", predicted: "event" },
  CAREER_STABLE_CAUTION: { domain: "career", predicted: "stability" },
  MONEY_RISK_MEDIUM: { domain: "money", predicted: "risk" },
  MONEY_OPPORTUNITY: { domain: "money", predicted: "opportunity" },
  LOVE_STABLE: { domain: "love", predicted: "stability" },
  LOVE_DELAY: { domain: "love", predicted: "risk" },
  HEALTH_CAUTION: { domain: "health", predicted: "risk" },
  STARTUP_NOT_RECOMMENDED: { domain: "startup", predicted: "risk" },
  STARTUP_TEST_FIRST: { domain: "startup", predicted: "opportunity" },
  MOVE_CAUTION: { domain: "move", predicted: "risk" },
  FAMILY_RESPONSIBILITY: { domain: "family", predicted: "event" },
  GENERAL_MIXED_FLOW: { domain: "general", predicted: "none" },
};

/** 판단 code → RuleId (엔진 codeForRule의 역매핑). 없으면 null */
export const RULE_FOR_CODE: Partial<Record<JudgmentCode, RuleId>> = {
  CAREER_CHANGE_HIGH: "rule.career.change",
  MONEY_RISK_MEDIUM: "rule.money.risk",
  MONEY_OPPORTUNITY: "rule.money.opportunity",
  LOVE_STABLE: "rule.love.stable",
  LOVE_DELAY: "rule.love.delay",
  HEALTH_CAUTION: "rule.health.caution",
  STARTUP_NOT_RECOMMENDED: "rule.startup.not_recommended",
  STARTUP_TEST_FIRST: "rule.startup.test_first",
  MOVE_CAUTION: "rule.move.caution",
  FAMILY_RESPONSIBILITY: "rule.family.responsibility",
  GENERAL_MIXED_FLOW: "rule.general.mixed_flow",
};

export function expectationFor(code: JudgmentCode): CodeExpectation {
  return CODE_EXPECTATION[code];
}

export interface ScoredMatch {
  level: MatchLevel;
  score: number;
  reason: string;
}

function level(l: MatchLevel, reason: string): ScoredMatch {
  return { level: l, score: MATCH_SCORE[l], reason };
}

/**
 * 예측 방향 하나를 실제 분야 결과와 대조해 등급을 매긴다.
 * 이 함수는 predicted !== "none" 이고 outcome이 존재하는(대조 가능한) 경우에만 호출한다.
 */
export function scoreMatch(
  predicted: PredictedDirection,
  outcome: CaseDomainOutcome,
): ScoredMatch {
  const { happened, valence } = outcome;
  switch (predicted) {
    case "event":
      return happened
        ? level("match", "변화 예측 → 실제 사건 발생")
        : level("miss", "변화 예측 → 실제 사건 없음");
    case "stability":
      if (!happened) return level("match", "안정 예측 → 큰 사건 없음");
      if (valence === "positive") return level("partial", "안정 예측 → 사건은 있었으나 긍정 방향");
      return level("miss", "안정 예측 → 실제로는 흔들림/부정 사건");
    case "risk":
      if (happened && valence === "negative") return level("match", "위험 예측 → 실제 부정 사건 발생");
      if (happened && valence === "neutral") return level("partial", "위험 예측 → 사건은 있었으나 중립 방향");
      if (happened && valence === "positive") return level("miss", "위험 예측 → 실제로는 긍정 사건");
      return level("partial", "위험 예측 → 사건 없음 (과잉 경고, 해는 없음)");
    case "opportunity":
      if (happened && valence === "positive") return level("match", "기회 예측 → 실제 긍정 사건 발생");
      if (happened && valence === "neutral") return level("partial", "기회 예측 → 사건은 있었으나 중립 방향");
      if (happened && valence === "negative") return level("miss", "기회 예측 → 실제로는 부정 사건");
      return level("partial", "기회 예측 → 사건 없음 (기회 미실현)");
    default:
      return level("minor", "판정 불가");
  }
}
