import type { BirthInfo, FeedbackRating, LifeDomain, ReadingType } from "../../types/index.js";
import type { JudgmentCode, RuleId } from "../judgmentTypes.js";

/**
 * 사례 기반 검증 엔진 — 타입 정의 (P2 Case Validation Engine).
 *
 * 목적: 계산 → Evidence → Rule → Judgment → Gate → Claude → Validation 로 나온 판단(JudgmentPack)이
 * 실제 사례에서 얼마나 맞는지 자동으로 대조·집계하는 "데이터를 모으는 엔진".
 *
 * 절대 하지 않는 것(설계 원칙):
 *   - 계산 로직(saju.ts) / eventEngine / Rule / Judgment 구조 변경
 *   - confidence 자동 변경 (통계는 읽기 전용 보정 자료로만 생성)
 * 이 레이어는 "판단을 바꾸는 엔진"이 아니라 "판단이 맞았는지 기록하는 엔진"이다.
 */

export const CASE_SCHEMA_VERSION = "1.0.0" as const;

/** 사례가 다루는 분야. 계산 엔진의 LifeDomain을 그대로 재사용한다. */
export type CaseDomain = LifeDomain;

/** 실제로 관측된 구체 사건 유형 (분야별 현실 사건) */
export type CaseEventKind =
  | "occupation_change" // 이직·직무 변화
  | "promotion" // 승진·역할 확대
  | "startup" // 창업·독립
  | "money_gain" // 재물 이득
  | "money_loss" // 재물 손실
  | "marriage" // 결혼·큰 관계 진전
  | "breakup" // 이별
  | "divorce" // 이혼
  | "new_relationship" // 새 인연
  | "health_issue" // 건강 이상
  | "move" // 이사·이동
  | "family_event"; // 가족 사건

/** 사건 방향 (좋게/나쁘게/중립) */
export type CaseValence = "positive" | "negative" | "neutral";

/** 한 분야에서 실제로 무슨 일이 있었는지 기록 */
export interface CaseDomainOutcome {
  domain: CaseDomain;
  /** 그 기간 이 분야에 눈에 띄는 사건이 있었는가 */
  happened: boolean;
  /** 사건의 방향 (사건이 없으면 neutral) */
  valence: CaseValence;
  /** 구체 사건 유형 (선택) */
  events?: CaseEventKind[];
  /** 사용자/전문가 메모 (선택) */
  note?: string;
}

/** 사례 출처 */
export type CaseSource = "fixture" | "user" | "expert" | "synthetic";

/** 전문가 검토 판정 */
export type ExpertVerdict = "correct" | "partially_correct" | "wrong" | "unsure";

/** rule/judgment 단위 전문가 검토 */
export interface ExpertRuleVerdict {
  ruleId: RuleId;
  verdict: ExpertVerdict;
  comment?: string;
}

/** 전문가 검토 결과 (선택 저장) */
export interface ExpertReview {
  reviewer?: string;
  verdict: ExpertVerdict;
  ruleVerdicts?: ExpertRuleVerdict[];
  comment?: string;
  reviewedAt?: string;
}

/** 사용자 피드백 (맞아요/보통/아니에요 → FeedbackRating) */
export interface CaseUserFeedback {
  rating: FeedbackRating;
  note?: string;
  createdAt?: string;
}

/**
 * 실제 결과를 저장하는 사례 한 건.
 * birth + 그 사람에게 실제로 있었던 일 + (선택) 사용자/전문가 평가.
 */
export interface Case {
  id: string;
  source: CaseSource;
  birth: BirthInfo;
  readingType: ReadingType;
  /** 실제 사건이 관측된 기간(양력 연도). 보통 리딩 시점 이후 관찰 결과 */
  observedYearFrom: number;
  observedYearTo: number;
  /** 분야별 실제 결과 */
  actualOutcomes: CaseDomainOutcome[];
  userFeedback?: CaseUserFeedback;
  expertReview?: ExpertReview;
  note?: string;
  createdAt?: string;
}

// ── Match Score ──────────

/** 한 판단이 실제와 얼마나 맞았는지 등급 */
export type MatchLevel = "match" | "partial" | "minor" | "miss";

/** 등급 → 점수 */
export const MATCH_SCORE: Record<MatchLevel, number> = {
  match: 100,
  partial: 70,
  minor: 30,
  miss: 0,
};

/** 판단 code가 그 분야에 대해 실제로 무엇을 예측하는가 */
export type PredictedDirection =
  | "event" // 그 분야에 변화/사건이 온다
  | "stability" // 큰 사건 없이 안정
  | "risk" // 움직임이 부담/위험 방향
  | "opportunity" // 움직임이 기회/이득 방향
  | "none"; // 특정 사건을 예측하지 않음 (대조 대상 아님)

/** FeedbackRating → 숫자 점수 (unsure는 집계 제외) */
export const FEEDBACK_SCORE: Record<FeedbackRating, number | null> = {
  accurate: 100,
  partial: 60,
  unsure: null,
  inaccurate: 0,
};

// ── 검증 결과 ──────────

/** 판단 한 건의 대조 결과 */
export interface CaseJudgmentOutcome {
  judgmentId: string;
  code: JudgmentCode;
  domain: CaseDomain | "general";
  predicted: PredictedDirection;
  confidence: number;
  triggeredRuleIds: RuleId[];
  /** 실제 결과와 대조 가능했는가 (matchRate 집계 대상 여부) */
  scored: boolean;
  level: MatchLevel;
  score: number;
  reason: string;
}

/** 사례 1건 × JudgmentPack 대조 결과 */
export interface CaseValidationResult {
  caseId: string;
  source: CaseSource;
  readingType: ReadingType;
  outcomes: CaseJudgmentOutcome[];
  /** 대조 가능한 판단만으로 계산한 평균 점수 (0~100). 대조 대상이 없으면 null */
  matchRate: number | null;
  /** 대조 가능(scored) 판단 수 */
  scoredCount: number;
  /** 대조 불가(실제 데이터 없음·일반 흐름) 판단 수 */
  unscoredCount: number;
  rewriteUsed: boolean;
  fallbackUsed: boolean;
  validationStatus?: "pass" | "rewrite" | "fallback";
  userRating?: FeedbackRating;
  expertVerdict?: ExpertVerdict;
}
