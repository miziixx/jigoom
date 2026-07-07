// Claude 답변을 생성되는 동안 실시간으로 Telegram에 반영한다.
// 생성 중에는 "첫 메시지 한 개"만 editMessageText로 계속 갱신하고(일반 텍스트),
// 생성이 끝나면 finalizeStream이 최종 텍스트를 마크다운으로 확정 표시한다.
// 이렇게 하면 한 답변이 정확히 한 번만 최종 형태로 남는다(중복 전송 없음).

import { sendMessage, editMessageText } from "./telegram.js";

interface StreamBuffer {
  messageId?: number; // 갱신 대상 첫 메시지 (스트리밍 중 편집)
  displayedLen: number; // 마지막으로 표시한 길이
  lastEditAt: number; // 마지막 편집 시각 (rate limit 여유용)
}

const buffers = new Map<number, StreamBuffer>();

// 텔레그램 편집 rate limit 여유 + 화면 깜빡임 최소화. 이 간격 안에는 갱신하지 않는다.
const MIN_EDIT_INTERVAL_MS = 1200;
// 이만큼(글자) 늘어났을 때만 갱신 (자잘한 편집 호출 억제)
const MIN_GROWTH = 60;

/** 텔레그램 메시지 상한(4096자)에 맞춰 문단 경계에서 나눈다 */
function splitChunks(text: string, limit = 3900): string[] {
  if (text.length <= limit) return [text];
  const chunks: string[] = [];
  let rest = text;
  while (rest.length > limit) {
    let cut = rest.lastIndexOf("\n\n", limit);
    if (cut < limit * 0.5) cut = rest.lastIndexOf("\n", limit);
    if (cut < limit * 0.5) cut = limit;
    chunks.push(rest.slice(0, cut));
    rest = rest.slice(cut).replace(/^\n+/, "");
  }
  if (rest) chunks.push(rest);
  return chunks;
}

/**
 * 생성 중 부분 텍스트를 화면에 반영한다 (베스트 에포트, 일반 텍스트).
 * 스로틀에 걸리거나 전송 실패해도 조용히 넘어간다 — 최종 표시는 finalizeStream이 보장한다.
 * 스트리밍 중에는 "첫 청크(첫 3900자)"만 갱신한다. 그보다 길어지면 머리 부분만 계속 보이고,
 * 나머지는 finalizeStream이 확정 전송한다(중복 방지).
 */
export async function emitPartial(chatId: number, partialText: string): Promise<void> {
  if (!partialText.trim()) return;

  let buf = buffers.get(chatId);
  if (!buf) {
    buf = { displayedLen: 0, lastEditAt: 0 };
    buffers.set(chatId, buf);
  }

  const now = Date.now();
  if (now - buf.lastEditAt < MIN_EDIT_INTERVAL_MS) return;
  if (partialText.length - buf.displayedLen < MIN_GROWTH) return;

  // 동시 호출 경합 방지: 네트워크 대기 전에 먼저 스로틀 값을 갱신한다.
  buf.lastEditAt = now;
  buf.displayedLen = partialText.length;

  const head = splitChunks(partialText)[0];
  try {
    if (buf.messageId == null) {
      const id = await sendMessage(chatId, head, { plain: true });
      if (id != null) buf.messageId = id;
    } else {
      await editMessageText(chatId, head, buf.messageId, { plain: true });
    }
  } catch {
    // 표시용이라 실패해도 무시
  }
}

/**
 * 최종 텍스트를 확실히 표시하고 스트림 버퍼를 정리한다 (마크다운 적용).
 * 스트리밍으로 이미 만든 첫 메시지가 있으면 그걸 편집하고, 없으면 새로 보낸다.
 * 길이가 넘치면 첫 청크는 편집/전송하고 나머지 청크는 새 메시지로 이어 보낸다.
 * 반드시 runStream이 스트리밍을 끝낸 뒤(진행 중 emitPartial이 남아있지 않을 때) 호출해야 한다.
 */
export async function finalizeStream(chatId: number, finalText: string): Promise<void> {
  const buf = buffers.get(chatId);
  buffers.delete(chatId);

  const chunks = splitChunks(finalText);

  // 첫 청크: 기존 스트리밍 메시지를 마크다운으로 확정. 편집이 완전히 실패하면 새로 보낸다.
  if (buf?.messageId != null) {
    const ok = await editMessageText(chatId, chunks[0], buf.messageId);
    if (!ok) await sendMessage(chatId, chunks[0]);
  } else {
    await sendMessage(chatId, chunks[0]);
  }

  // 나머지 청크: 스트리밍 중에는 첫 청크만 보였으므로, 여기서만 이어 보낸다(중복 없음).
  for (let i = 1; i < chunks.length; i++) {
    await sendMessage(chatId, chunks[i]);
  }
}
