import type { ReadingType } from "../../types/index.js";
import type { JudgmentCode, JudgmentDomain, RuleId } from "../judgmentTypes.js";

/**
 * AI Quality Dashboard — 타입 정의 (개발자 전용 Observability Layer).
 *
 * 이 레이어는 관찰자(Observer)다. 사주 계산·룰·판단 엔진을 절대 바꾸지 않는다.
 * 리딩이 끝날 때 "품질 신호"만 PII 없이 기록하고, 그걸 집계해 엔진 상태를 숫자로 보여준다.
 *
 * ⚠️ 저장 금지(설계 불변식): 생년월일 / 이름 / 사용자 입력 / LLM 원문 / 그 어떤 개인정보도
 * QualityEvent에 담지 않는다. 여기에 정의된 필드는 모두 enum·id·플래그·집계 수치뿐이다.
 *
 * 확장성: 이 QualityEvent 스키마는 앞으로 Case Validation Engine / Explain Engine /
 * Rule Calibration Engine이 공통으로 소비하는 중심 이벤트다. 필드를 추가할 때는
 * schemaVersion을 올리고 하위 호환을 유지한다 (구조를 다시 뜯지 않도록).
 */

export const QUALITY_SCHEMA_VERSION = "1.0.0" as const;

/** 판단 엔진 버전 (품질 변화 원인 추적용). 엔진 구조가 바뀌면 올린다. */
export const ENGINE_VERSION = "judgment-1.0.0" as const;

/** 클라이언트 readingValidation 결과를 pass/warning/error로 요약 */
export type ValidationOutcome = "pass" | "warning" | "error";

/** 서버 Evidence Gate 최종 상태 (스트림 done 라인에서 전달됨) */
export type GateStatus = "pass" | "rewrite" | "fallback" | "unknown";

/** 이벤트 출처 (지금은 client 저장. 향후 server sink 대비) */
export type QualitySource = "client" | "server";

/** 판단 하나의 압축 신호 (code + domain + confidence만; 원문 없음) */
export interface QualityJudgmentSignal {
  code: JudgmentCode;
  domain: JudgmentDomain;
  confidence: number;
}

/**
 * 리딩 1건의 품질 이벤트. 개인정보 없음.
 * (timestamp, reading type, judgment/rule ids, validation, rewrite/fallback, confidence, version만)
 */
export interface QualityEvent {
  id: string;
  timestamp: string; // ISO
  readingType: ReadingType;
  schemaVersion: typeof QUALITY_SCHEMA_VERSION;
  engineVersion: string;
  judgmentSchemaVersion: string;

  /** 이 리딩에서 생성된 판단들 (code/domain/confidence) */
  judgments: QualityJudgmentSignal[];
  /** 발동한 rule id (pack.triggeredRules) */
  ruleIds: RuleId[];
  /** 감지된 모순 id (contradiction.*) */
  contradictionCodes: string[];
  /** 이 리딩이 가드하는 forbidden claim code (global + 판단별) */
  forbiddenClaimCodes: string[];

  /** 클라이언트 출력 검증 요약 */
  validation: ValidationOutcome;
  /** 검증에서 걸린 이슈 code (enum) */
  validationIssueCodes: string[];

  /** 서버 게이트 최종 상태 */
  gateStatus: GateStatus;
  rewriteAttempted: boolean;
  rewriteSucceeded: boolean;
  fallbackUsed: boolean;
  /** rewrite/fallback을 유발한 이슈 code (서버가 전달; 없으면 빈 배열) */
  fallbackReasonCodes: string[];

  source: QualitySource;
}

/** 로거 입력: 리딩 완료 시점에 클라이언트가 가진 재료 */
export interface QualityLogInput {
  readingType: ReadingType;
  /** meta의 JudgmentPack (PII 없음). 없으면 이벤트를 남기지 않는다. */
  judgmentPack: QualityJudgmentPackLike | null | undefined;
  /** 클라이언트 readingValidation 결과 요약 재료 */
  validation?: {
    status?: "pass" | "rewrite" | "fallback";
    issues?: { code: string; severity: "warning" | "error" }[];
  };
  /** 서버 게이트 신호 (스트림 done 라인) */
  gate?: { status?: string; reasonCodes?: string[] } | null;
  /** 테스트/서버용 override */
  source?: QualitySource;
  now?: () => Date;
  id?: string;
}

/**
 * QualityEvent를 만들기 위해 JudgmentPack에서 실제로 읽는 최소 형태.
 * (판단 엔진의 JudgmentPack이 이 형태를 만족한다. 느슨하게 잡아 서버/구버전 pack도 수용)
 */
export interface QualityJudgmentPackLike {
  judgments?: {
    code: JudgmentCode;
    domain: JudgmentDomain;
    confidence?: { overall?: number };
    forbiddenClaims?: { code: string }[];
  }[];
  triggeredRules?: { id: RuleId }[];
  contradictions?: { id: string }[];
  globalForbiddenClaims?: { code: string }[];
  audit?: {
    validationStatus?: "pass" | "rewrite" | "fallback";
    validationIssueIds?: string[];
    rewriteAttempted?: boolean;
    fallbackUsed?: boolean;
  };
}
