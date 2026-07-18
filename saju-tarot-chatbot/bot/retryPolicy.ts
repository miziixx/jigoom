// LLM 호출의 "일시적 실패" 판단과 백오프 정책. 부작용 없는 순수 함수만 둔다(단위 테스트 가능).
//
// 배경: runStream/ask*가 스트림을 만들다 429(rate limit)·529(overloaded)·5xx·순간 네트워크
// 오류를 맞으면, 예전엔 곧장 "지금 답을 만드는 데 문제가 생겼어요"로 떨어졌다. 이런 건 대부분
// 몇백 ms 뒤 다시 하면 되는 일시적 오류라, 아무 텍스트도 안 나온 초기 실패에 한해 재시도한다.

/** 재시도할 가치가 있는 HTTP 상태 코드(과부하·rate limit·일시적 서버 오류). */
const RETRYABLE_STATUS = new Set([408, 409, 425, 429, 500, 502, 503, 529]);

/** SDK가 네트워크 계열 오류에 붙이는 이름(연결 끊김·SDK 자체 타임아웃). */
const RETRYABLE_ERROR_NAMES = new Set(["APIConnectionError", "APIConnectionTimeoutError"]);

/**
 * 이 오류가 "잠깐 뒤 다시 하면 될" 일시적 오류인지 판단한다.
 *
 * 주의: 우리가 AbortSignal.timeout으로 직접 끊은 경우(TimeoutError/AbortError)는 *재시도하지 않는다* —
 * 이미 상한 시간(기본 120s)을 통째로 써버린 뒤라, 재시도하면 Vercel maxDuration(5분)을 넘겨 함수가
 * 죽고 텔레그램이 같은 메시지를 무한 재시도하는 원래의 먹통으로 돌아간다.
 */
export function isTransientApiError(err: unknown): boolean {
  if (!err || typeof err !== "object") return false;
  const e = err as { name?: string; status?: number };

  // 우리가 건 타임아웃/중단은 일시적이 아니다(시간을 이미 다 씀).
  if (e.name === "TimeoutError" || e.name === "AbortError") return false;

  if (typeof e.status === "number" && RETRYABLE_STATUS.has(e.status)) return true;
  if (e.name && RETRYABLE_ERROR_NAMES.has(e.name)) return true;
  return false;
}

/**
 * 재시도 전 대기 시간(ms). 지수 백오프 + 소량 지터. attempt는 1부터(첫 재시도=1).
 * 초기 실패에만 쓰므로 짧게 잡는다(전체 시간 예산을 아끼려고).
 */
export function retryBackoffMs(attempt: number, now: () => number = Date.now): number {
  const base = 400 * 2 ** (attempt - 1); // 400, 800, 1600...
  const capped = Math.min(base, 4000);
  const jitter = (now() % 200); // 0~199ms
  return capped + jitter;
}

/** runStream이 초기 실패에 시도할 총 횟수(첫 시도 포함). */
export const MAX_STREAM_ATTEMPTS = 3;
