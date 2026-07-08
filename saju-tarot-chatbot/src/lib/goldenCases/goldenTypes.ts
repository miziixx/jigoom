import type { BirthInfo, ReadingContext, ReadingFocus, ReadingType } from "../../types/index.js";
import type { JudgmentCode, JudgmentDomain } from "../judgmentTypes.js";

/**
 * Golden Test Cases — 사주 리딩 엔진 회귀 테스트 기반 (타입 정의).
 *
 * 목적: 모델/프롬프트/룰 변경 시 리딩 품질이 퇴보했는지 자동 감지.
 * 원칙:
 *   - LLM 문장 전체를 고정하지 않는다. 결정론적 JudgmentPack(계산→근거→룰→판단)만 비교한다.
 *   - 계산 엔진(saju.ts)·eventEngine은 수정하지 않는다. golden은 순수 관찰자.
 *   - 엄격한 snapshot이 아니라 "허용 범위를 둔 regression check"로 만든다.
 *
 * 결정론 보장: BirthInfo + referenceDate → computeSajuChart → computeLuckCycles →
 * buildReadingJudgmentPack 는 LLM 없이 항상 같은 결과를 낸다.
 */

export const GOLDEN_SCHEMA_VERSION = "1.0.0" as const;

/** 고정 입력 */
export interface GoldenInput {
  birth: BirthInfo;
  /** 세운·대운을 결정론적으로 만들기 위한 기준일 (양력 ISO 또는 YYYY-MM-DD) */
  referenceDate: string;
  /** 현재 JudgmentPack은 saju/combo + depth:"light"에서만 생성된다 */
  type: ReadingType;
  question?: string;
  focus?: ReadingFocus;
  context?: ReadingContext;
}

/** 신뢰도 허용 구간 */
export interface ConfidenceRange {
  min?: number;
  max?: number;
}

/** 케이스별 기대값 (모두 선택적 — 지정한 것만 검사) */
export interface GoldenExpectation {
  /** 반드시 나와야 하는 판단 code (부분집합 검사, 추가는 허용) */
  requiredJudgmentCodes?: JudgmentCode[];
  /** 나오면 안 되는 판단 code */
  forbiddenJudgmentCodes?: JudgmentCode[];
  /** 반드시 커버해야 하는 도메인 */
  requiredDomains?: JudgmentDomain[];
  /** 최소 고유 도메인 수 */
  minDomainCoverage?: number;
  /** 구조 검증 통과 여부 (기본 true). validateJudgmentPack.ok */
  structurallyValid?: boolean;
  /** forbidden-claim 구조 결함이 없어야 하는가 (기본 true) */
  expectNoForbiddenClaimViolation?: boolean;
  /** 전체 평균 confidence 허용 구간 */
  overallConfidence?: ConfidenceRange;
  /** 판단 code별 confidence 허용 구간 */
  confidenceByCode?: Partial<Record<JudgmentCode, ConfidenceRange>>;
  /** 이 집합 밖의 contradiction이 나오면 실패 */
  allowedContradictionIds?: string[];
  /** contradiction 최대 개수 */
  maxContradictions?: number;
  /** 반드시 존재해야 하는 핵심 evidence id (안정적인 소수만) */
  requiredEvidenceIds?: string[];
  /**
   * 결정론 대체 지표: 이 pack이 구조상 rewrite/fallback을 강제하지 않는가.
   * 실제 LLM rewrite/fallback 발생은 결정론 범위 밖이므로 optional LLM 단계로 분리한다.
   */
  expectGateWouldNotForceRewrite?: boolean;
}

export interface GoldenCase {
  id: string;
  description: string;
  input: GoldenInput;
  expect: GoldenExpectation;
}

/** pack에서 뽑은, 사람이 리뷰 가능한 압축 요약 (loose snapshot) */
export interface GoldenSummary {
  packGenerated: boolean;
  judgmentCodes: string[];
  domains: string[];
  confidenceByCode: Record<string, number>;
  overallConfidenceAvg: number | null;
  contradictionIds: string[];
  ruleIds: string[];
  evidenceIds: string[];
  forbiddenClaimCodes: string[];
  structurallyValid: boolean;
  validationIssueCodes: string[];
}

/** 한 케이스 검사 결과 */
export interface GoldenCheckResult {
  id: string;
  ok: boolean;
  failures: string[];
  summary: GoldenSummary;
}
