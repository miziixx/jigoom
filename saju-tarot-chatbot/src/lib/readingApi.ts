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

/**
 * /api/reading을 NDJSON 스트리밍으로 호출한다.
 * 첫 토큰부터 바로 받아 그리므로 긴 리딩에서도 게이트웨이 타임아웃(504)이 나지 않는다.
 * 서버가 스트리밍을 지원하지 않으면(JSON 응답) 자동으로 일괄 응답을 처리한다.
 */
export async function streamReading(body: unknown, handlers: StreamHandlers = {}): Promise<StreamResult> {
  const res = await fetch("/api/reading", {
    method: "POST",
    headers: { "Content-Type": "application/json", Accept: "application/x-ndjson" },
    body: JSON.stringify(body),
  });

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
    if (obj.error) throw new Error(obj.error);
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

  // done 신호 없이 스트림이 끊긴 경우 (함수 시간 초과 등) — 부분 결과라도 살리되 알림
  if (!done && reply.length === 0) {
    throw new Error("서버 연결이 끊겼습니다. 다시 시도해보세요.");
  }

  return { meta, reply };
}
