// 로그 위생 유틸 — 사용자 원문·Claude 프롬프트·응답 원문은 절대 로그에 남기지 않는다.
// 여기를 거치지 않고 console.error(msg, rawErrorObjectOrText)로 원문을 남기지 말 것.

export interface RequestLogFields {
  requestId: string;
  mode: string;
  latencyMs: number;
  tokenCount?: number;
  errorCode?: string;
}

/** 에러 객체에서 name/message/status만 뽑는다. 원본 요청/응답 바디는 절대 포함하지 않는다. */
function safeErrorFields(err: unknown): { name?: string; message: string; status?: number } {
  if (err instanceof Error) {
    const status = (err as { status?: number }).status;
    return { name: err.name, message: err.message, status };
  }
  return { message: typeof err === "string" ? err : "알 수 없는 오류" };
}

/** scope(어디서 난 오류인지)만 남기고, 원문 없이 오류를 기록한다. */
export function logError(scope: string, err: unknown): void {
  const { name, message, status } = safeErrorFields(err);
  console.error(`[${scope}]`, { name, message, status });
}

/** requestId/mode/지연시간/토큰수/에러코드만 남긴다 — 원문 없음. */
export function logRequest(fields: RequestLogFields): void {
  console.log("[request]", fields);
}
