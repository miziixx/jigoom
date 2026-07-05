import type { LuckCycles, SajuChart } from "../types";
import type { JudgmentPack } from "./judgmentTypes.js";

export interface ReadingMeta {
  userMessage: string;
  sajuChart?: SajuChart;
  luckCycles?: LuckCycles;
  judgmentPack?: JudgmentPack | null;
}

interface StreamHandlers {
  /** 새 리딩 스트림 첫 줄의 계산 결과 (followup/compare에는 없음) */
  onMeta?: (meta: ReadingMeta) => void;
  /** 텍스트 델타가 올 때마다 누적 전문을 전달 */
  onText?: (accumulated: string) => void;
}

export interface StreamResult {
  meta?: ReadingMeta;
  reply: string;
}

/** 한 번의 스트림 호출 결과 (이어쓰기 판단용 완결 여부 포함) */
interface StreamChunkResult {
  meta?: ReadingMeta;
  reply: string;
  /** 이 호출이 끝까지 완성됐는가 (done 수신 + stopReason이 max_tokens가 아님) */
  complete: boolean;
}

/** 이어쓰기(continue) 최대 횟수 — 무한 루프 방지. 전문가 리딩도 이 안에서 완결된다. */
const MAX_CONTINUATIONS = 6;

type FanOutBody = Record<string, unknown> & {
  type?: unknown;
  continueFrom?: unknown;
  sectionGroup?: unknown;
  context?: unknown;
};

/** 스트림 라인으로 전달된 서버 측 오류 (네트워크 단절과 구분용) */
class ServerReportedError extends Error {}

/**
 * 서버/프록시가 보낸 error 값을 사람이 읽을 수 있는 문자열로 만든다.
 * error가 문자열이 아니라 객체({message}, {error}, 기타)로 오면 그대로 Error에 넣었을 때
 * "[object Object]"가 되어버리므로, 여기서 안전하게 풀어낸다.
 */
export function serverErrorText(value: unknown, fallback: string): string {
  if (typeof value === "string" && value.trim()) return value;
  if (value && typeof value === "object") {
    const obj = value as Record<string, unknown>;
    if (typeof obj.message === "string" && obj.message.trim()) return obj.message;
    if (typeof obj.error === "string" && obj.error.trim()) return obj.error;
    try {
      const json = JSON.stringify(value);
      if (json && json !== "{}") return json;
    } catch {
      // 순환 참조 등 직렬화 실패 시 fallback
    }
  }
  return fallback;
}

/** 긴 생성(전문가 리딩 등) 동안 모바일 화면이 꺼져 연결이 끊기는 것을 막는다 */
async function acquireWakeLock(): Promise<WakeLockSentinel | null> {
  try {
    if ("wakeLock" in navigator) return await navigator.wakeLock.request("screen");
  } catch {
    // 배터리 절약 모드 등으로 거부될 수 있음 — 없어도 동작에는 지장 없음
  }
  return null;
}

/** 스트림이 done 없이 끊긴 네트워크 단절 (재시도 가능 여부 판별용) */
class NetworkDropError extends Error {}

/** 네트워크 단절(fetch 실패/스트림 중단)을 사용자가 조치할 수 있는 메시지로 변환 */
function networkError(): NetworkDropError {
  return new NetworkDropError(
    "네트워크 연결이 끊겼습니다. 긴 리딩은 생성에 1~2분 걸릴 수 있으니, 화면을 켠 채 잠시 기다려주세요. 지금까지 생성된 부분이 있다면 기록에 저장되어 있습니다.",
  );
}

/**
 * /api/reading을 NDJSON 스트리밍으로 호출한다.
 * 첫 토큰부터 바로 받아 그리므로 긴 리딩에서도 게이트웨이 타임아웃(504)이 나지 않는다.
 * 서버가 스트리밍을 지원하지 않으면(JSON 응답) 자동으로 일괄 응답을 처리한다.
 */
export async function streamReading(body: unknown, handlers: StreamHandlers = {}): Promise<StreamResult> {
  const wakeLock = await acquireWakeLock();
  try {
    if (shouldFanOut(body)) return await streamReadingFanOut(body as FanOutBody, handlers);
    return await streamReadingWithContinuations(body, handlers);
  } finally {
    wakeLock?.release().catch(() => {});
  }
}

function shouldFanOut(body: unknown): body is FanOutBody {
  if (!body || typeof body !== "object") return false;
  const b = body as FanOutBody;
  const depth = b.context && typeof b.context === "object" ? (b.context as { depth?: unknown }).depth : undefined;
  if (depth !== "advanced" && depth !== "expert") return false;
  return (b.type === "saju" || b.type === "combo") && !b.continueFrom && !b.sectionGroup;
}

function combineParts(front: string, back: string): string {
  if (!front) return back;
  if (!back) return front;
  return `${front.trimEnd()}\n\n${back.trimStart()}`;
}

async function streamReadingFanOut(body: FanOutBody, handlers: StreamHandlers): Promise<StreamResult> {
  let frontReply = "";
  let backReply = "";
  let meta: ReadingMeta | undefined;
  let metaDelivered = false;
  let pendingText: string | null = null;

  const emitCombined = () => {
    const combined = combineParts(frontReply, backReply);
    if (!metaDelivered) {
      pendingText = combined;
      return;
    }
    handlers.onText?.(combined);
  };

  const deliverMeta = (nextMeta: ReadingMeta) => {
    if (metaDelivered) return;
    meta = nextMeta;
    metaDelivered = true;
    handlers.onMeta?.(nextMeta);
    if (pendingText !== null) {
      handlers.onText?.(pendingText);
      pendingText = null;
    }
  };

  const front = streamReadingWithContinuations(
    { ...body, sectionGroup: "front" },
    {
      onMeta: deliverMeta,
      onText: (text) => {
        frontReply = text;
        emitCombined();
      },
    },
  );
  const back = streamReadingWithContinuations(
    { ...body, sectionGroup: "back" },
    {
      onText: (text) => {
        backReply = text;
        emitCombined();
      },
    },
  );

  const [frontResult, backResult] = await Promise.all([front, back]);
  meta = meta ?? frontResult.meta ?? backResult.meta;
  const reply = combineParts(frontResult.reply, backResult.reply);
  if (meta && !metaDelivered) handlers.onMeta?.(meta);
  handlers.onText?.(reply);
  return { meta, reply };
}

async function streamReadingWithContinuations(body: unknown, handlers: StreamHandlers = {}): Promise<StreamResult> {
  // 잘린 리딩(토큰 상한/네트워크 절단)을 최종본으로 확정하지 않는다. 완결될 때까지 지금까지
  // 받은 본문을 continueFrom으로 넘겨 "이어서" 생성하게 한다. UI에는 항상 누적 전문을 보여준다.
  let fullReply = "";
  let meta: ReadingMeta | undefined;

  for (let attempt = 0; attempt <= MAX_CONTINUATIONS; attempt++) {
    const isContinuation = fullReply.length > 0;
    const callBody = isContinuation ? { ...(body as Record<string, unknown>), continueFrom: fullReply } : body;

    const wrapped: StreamHandlers = {
      // 메타(계산 결과)는 첫 호출에서만 온다
      onMeta: isContinuation ? undefined : handlers.onMeta,
      onText: (accumulated) => handlers.onText?.(fullReply + accumulated),
    };

    const chunk = await streamChunkWithRetry(callBody, wrapped);
    if (!isContinuation) meta = chunk.meta;
    fullReply += chunk.reply;

    // 완결됐거나, 더 이어붙일 게 없으면(이번 호출에서 새 텍스트가 없음) 종료
    if (chunk.complete || chunk.reply.length === 0) break;
  }

  return { meta, reply: fullReply };
}

/**
 * 단일 스트림 호출 + 첫 토큰 도착 전 단절 시 1회 재시도.
 * (첫 토큰 도착 전 유휴 구간에서 프록시/모바일이 연결을 끊는 사례 방어)
 */
async function streamChunkWithRetry(body: unknown, handlers: StreamHandlers): Promise<StreamChunkResult> {
  let receivedAny = false;
  const wrapped: StreamHandlers = {
    onMeta: handlers.onMeta,
    onText: (accumulated) => {
      receivedAny = true;
      handlers.onText?.(accumulated);
    },
  };
  try {
    return await streamReadingInner(body, wrapped);
  } catch (err) {
    if (err instanceof NetworkDropError && !receivedAny) {
      return await streamReadingInner(body, wrapped);
    }
    throw err;
  }
}

async function streamReadingInner(body: unknown, handlers: StreamHandlers): Promise<StreamChunkResult> {
  let res: Response;
  try {
    res = await fetch("/api/reading", {
      method: "POST",
      headers: { "Content-Type": "application/json", Accept: "application/x-ndjson" },
      body: JSON.stringify(body),
    });
  } catch {
    throw networkError();
  }

  if (!res.ok) {
    const errBody = (await res.json().catch(() => ({}))) as { error?: unknown };
    const fallback =
      res.status === 504 ? "서버 응답 시간 초과(504). 다시 시도해보세요." : `요청 실패 (HTTP ${res.status})`;
    throw new Error(serverErrorText(errBody.error ?? errBody, fallback));
  }

  const contentType = res.headers.get("Content-Type") ?? "";

  // 구버전 서버(일괄 JSON) 호환
  if (!contentType.includes("application/x-ndjson")) {
    const data = (await res.json()) as { reply: string } & Partial<ReadingMeta>;
    const meta = data.userMessage
      ? { userMessage: data.userMessage, sajuChart: data.sajuChart, luckCycles: data.luckCycles, judgmentPack: data.judgmentPack }
      : undefined;
    if (meta) handlers.onMeta?.(meta);
    handlers.onText?.(data.reply);
    // 구버전 일괄 JSON 응답은 완결 여부를 알 수 없으므로 완결로 간주(이어쓰기 안 함)
    return { meta, reply: data.reply, complete: true };
  }

  if (!res.body) throw new Error("스트리밍 응답을 읽을 수 없습니다.");

  const reader = res.body.getReader();
  const decoder = new TextDecoder();
  let buffer = "";
  let reply = "";
  let meta: ReadingMeta | undefined;
  let done = false;
  let stopReason: string | null = null;

  const handleLine = (line: string) => {
    if (!line.trim()) return;
    const obj = JSON.parse(line) as {
      meta?: ReadingMeta;
      text?: string;
      done?: boolean;
      stopReason?: string | null;
      error?: unknown;
    };
    if (obj.error) throw new ServerReportedError(serverErrorText(obj.error, "서버가 오류를 반환했습니다."));
    if (obj.meta) {
      meta = obj.meta;
      handlers.onMeta?.(obj.meta);
    }
    if (obj.text) {
      reply += obj.text;
      handlers.onText?.(reply);
    }
    if (obj.done) {
      done = true;
      stopReason = obj.stopReason ?? null;
    }
  };

  try {
    for (;;) {
      const { done: readerDone, value } = await reader.read();
      if (readerDone) break;
      buffer += decoder.decode(value, { stream: true });
      let idx = buffer.indexOf("\n");
      while (idx >= 0) {
        handleLine(buffer.slice(0, idx));
        buffer = buffer.slice(idx + 1);
        idx = buffer.indexOf("\n");
      }
    }
    if (buffer.trim()) handleLine(buffer);
  } catch (err) {
    // 서버가 보낸 {"error"} 라인은 그대로 올리고, 그 외(스트림 중단/파싱 실패)는 네트워크 안내로
    if (err instanceof ServerReportedError) throw new Error(err.message);
    throw networkError();
  }

  // done 신호도 없고 받은 텍스트도 없으면 순수 네트워크 단절 → (첫 토큰 전이면) 재시도로 이어진다
  if (!done && reply.length === 0) throw networkError();

  // 완결 판정: done을 받았고 stopReason이 max_tokens가 아닐 때만 끝난 것으로 본다.
  // - done 없이 텍스트만 오다 끊긴 경우(네트워크 절단) → 미완결 → 상위에서 이어쓰기
  // - stopReason === "max_tokens"(토큰 상한) → 미완결 → 상위에서 이어쓰기
  const complete = done && stopReason !== "max_tokens";
  return { meta, reply, complete };
}
