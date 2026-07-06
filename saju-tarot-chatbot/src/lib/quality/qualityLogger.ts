import {
  ENGINE_VERSION,
  QUALITY_SCHEMA_VERSION,
  type GateStatus,
  type QualityEvent,
  type QualityLogInput,
  type ValidationOutcome,
} from "./qualityTypes.js";
import { getQualityStore, type QualityStore } from "./qualityStorage.js";

/**
 * Quality 로거 (Observer 진입점).
 *
 * `buildQualityEvent`: JudgmentPack + 검증/게이트 신호 → PII-free QualityEvent (순수 함수).
 * `logReading`: 이벤트를 만들어 저장소에 append. **절대 throw하지 않는다** — 로깅 실패 때문에
 * 리딩이 실패하면 안 된다는 원칙을 코드 레벨에서 보장한다.
 */

const JUDGMENT_SCHEMA_VERSION = "1.0.0";

function uniq<T>(arr: T[]): T[] {
  return [...new Set(arr)];
}

function normalizeGateStatus(status: string | undefined): GateStatus {
  if (status === "pass" || status === "rewrite" || status === "fallback") return status;
  return "unknown";
}

/** 클라이언트 readingValidation issues → pass/warning/error 요약 */
function summarizeValidation(input: QualityLogInput["validation"]): {
  outcome: ValidationOutcome;
  codes: string[];
} {
  const issues = input?.issues ?? [];
  const codes = uniq(issues.map((i) => i.code));
  if (issues.some((i) => i.severity === "error")) return { outcome: "error", codes };
  if (issues.length > 0) return { outcome: "warning", codes };
  return { outcome: "pass", codes };
}

function randomId(): string {
  try {
    if (typeof crypto !== "undefined" && "randomUUID" in crypto) return crypto.randomUUID();
  } catch {
    // fall through
  }
  return `q_${Date.now()}_${Math.random().toString(36).slice(2, 10)}`;
}

/**
 * 순수 이벤트 빌더. 서버(api/reading)에서도 재사용할 수 있도록 저장소·환경에 의존하지 않는다.
 * PII는 구조적으로 배제된다 — pack에서 code/id/confidence/플래그만 읽는다.
 */
export function buildQualityEvent(input: QualityLogInput): QualityEvent | null {
  const pack = input.judgmentPack;
  if (!pack) return null;

  const now = input.now ? input.now() : new Date();
  const judgments = (pack.judgments ?? []).map((j) => ({
    code: j.code,
    domain: j.domain,
    confidence: typeof j.confidence?.overall === "number" ? j.confidence.overall : 0,
  }));
  const ruleIds = uniq((pack.triggeredRules ?? []).map((r) => r.id));
  const contradictionCodes = uniq((pack.contradictions ?? []).map((c) => c.id));
  const forbiddenClaimCodes = uniq([
    ...(pack.globalForbiddenClaims ?? []).map((f) => f.code),
    ...(pack.judgments ?? []).flatMap((j) => (j.forbiddenClaims ?? []).map((f) => f.code)),
  ]);

  const validation = summarizeValidation(input.validation);

  // 게이트 상태: 서버 gate가 있으면 우선, 없으면 pack.audit, 그것도 없으면 클라 validation status
  const gateStatus = normalizeGateStatus(
    input.gate?.status ?? pack.audit?.validationStatus ?? input.validation?.status,
  );
  const rewriteAttempted =
    gateStatus === "rewrite" || gateStatus === "fallback" || pack.audit?.rewriteAttempted === true;
  const fallbackUsed = gateStatus === "fallback" || pack.audit?.fallbackUsed === true;
  const rewriteSucceeded = gateStatus === "rewrite";
  const fallbackReasonCodes = uniq([
    ...(input.gate?.reasonCodes ?? []),
    ...(fallbackUsed || rewriteAttempted ? pack.audit?.validationIssueIds ?? [] : []),
  ]);

  return {
    id: input.id ?? randomId(),
    timestamp: now.toISOString(),
    readingType: input.readingType,
    schemaVersion: QUALITY_SCHEMA_VERSION,
    engineVersion: ENGINE_VERSION,
    judgmentSchemaVersion: JUDGMENT_SCHEMA_VERSION,
    judgments,
    ruleIds,
    contradictionCodes,
    forbiddenClaimCodes,
    validation: validation.outcome,
    validationIssueCodes: validation.codes,
    gateStatus,
    rewriteAttempted,
    rewriteSucceeded,
    fallbackUsed,
    fallbackReasonCodes,
    source: input.source ?? "client",
  };
}

/**
 * 리딩 완료 시 호출하는 관찰자. 절대 throw하지 않는다.
 * @returns 저장된 이벤트(성공) 또는 null(스킵/실패). 반환값 무시해도 안전.
 */
export function logReading(input: QualityLogInput, store: QualityStore = getQualityStore()): QualityEvent | null {
  try {
    const event = buildQualityEvent(input);
    if (!event) return null;
    store.append(event);
    return event;
  } catch {
    // Observer 원칙: 로깅 실패는 삼킨다. 리딩은 이미 성공했다.
    return null;
  }
}
