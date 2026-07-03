import type { LuckCycles, SajuChart } from "../types";

export interface ReadingMeta {
  userMessage: string;
  sajuChart?: SajuChart;
  luckCycles?: LuckCycles;
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

/** 스트림 라인으로 전달된 서버 측 오류 (네트워크 단절과 구분용) */
class ServerReportedError extends Error {}

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
    // 아직 아무 텍스트도 받지 못한 채 연결이 끊긴 경우에만 1회 자동 재시도한다.
    // (첫 토큰 도착 전 유휴 구간에서 프록시/모바일이 연결을 끊는 사례 방어)
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
  } finally {
    wakeLock?.release().catch(() => {});
  }
}

async function streamReadingInner(body: unknown, handlers: StreamHandlers): Promise<StreamResult> {
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
    const errBody = await res.json().catch(() => ({} as { error?: string }));
    throw new Error(
      errBody.error ??
        (res.status === 504 ? "서버 응답 시간 초과(504). 다시 시도해보세요." : `요청 실패 (HTTP ${res.status})`),
    );
  }

  const contentType = res.headers.get("Content-Type") ?? "";

  // 구버전 서버(일괄 JSON) 호환
  if (!contentType.includes("application/x-ndjson")) {
    const data = (await res.json()) as { reply: string } & Partial<ReadingMeta>;
    const meta = data.userMessage
      ? { userMessage: data.userMessage, sajuChart: data.sajuChart, luckCycles: data.luckCycles }
      : undefined;
    if (meta) handlers.onMeta?.(meta);
    handlers.onText?.(data.reply);
    return { meta, reply: data.reply };
  }

  if (!res.body) throw new Error("스트리밍 응답을 읽을 수 없습니다.");

  const reader = res.body.getReader();
  const decoder = new TextDecoder();
  let buffer = "";
  let reply = "";
  let meta: ReadingMeta | undefined;
  let done = false;

  const handleLine = (line: string) => {
    if (!line.trim()) return;
    const obj = JSON.parse(line) as { meta?: ReadingMeta; text?: string; done?: boolean; error?: string };
    if (obj.error) throw new ServerReportedError(obj.error);
    if (obj.meta) {
      meta = obj.meta;
      handlers.onMeta?.(obj.meta);
    }
    if (obj.text) {
      reply += obj.text;
      handlers.onText?.(reply);
    }
    if (obj.done) done = true;
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

  // done 신호 없이 스트림이 끝난 경우 (함수 시간 초과 등)
  if (!done && reply.length === 0) throw networkError();

  return { meta, reply };
}
