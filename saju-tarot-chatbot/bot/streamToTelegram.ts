// Claude 토큰을 실시간으로 Telegram에 스트리밍하는 로직.
// editMessageText로 이미 보낸 메시지를 점진적으로 업데이트한다.

import { sendMessage, editMessageText, type TgMessage } from "./telegram.js";

interface StreamBuffer {
  chatId: number;
  messageId?: number;
  buffer: string;
  lastUpdateTime: number;
  chunks: string[];
  sentChunks: number; // 몇 개 청크를 이미 보냈는지 추적
}

const buffers = new Map<number, StreamBuffer>();

const UPDATE_INTERVAL_MS = 500; // 0.5초마다 업데이트
const CHUNK_SIZE = 100; // 100 토큰마다 한 번은 확인

/** Telegram에 부분 텍스트를 전송하거나 업데이트한다 */
export async function emitPartial(chatId: number, partialText: string): Promise<void> {
  let buffer = buffers.get(chatId);
  if (!buffer) {
    buffer = { chatId, buffer: "", lastUpdateTime: Date.now(), chunks: [], sentChunks: 0 };
    buffers.set(chatId, buffer);
  }

  buffer.buffer = partialText;
  const now = Date.now();

  // 충분히 시간이 지났거나 텍스트가 충분히 쌓였으면 전송
  const timeSinceLastUpdate = now - buffer.lastUpdateTime;
  const currentLength = buffer.chunks.join("").length;
  const shouldUpdate = timeSinceLastUpdate >= UPDATE_INTERVAL_MS || partialText.length > currentLength + CHUNK_SIZE;

  if (!shouldUpdate) {
    return;
  }

  buffer.lastUpdateTime = now;

  // Telegram 4096자 한계 대응: 이전 청크들과 현재 청크 분리
  const chunks = splitChunks(partialText, 3900);

  // 첫 청크: 메시지 생성 또는 업데이트
  if (chunks.length > 0) {
    const firstChunk = chunks[0];
    if (!buffer.messageId) {
      // 첫 메시지 생성
      try {
        const msgId = await sendMessage(chatId, firstChunk);
        if (msgId) {
          buffer.messageId = msgId;
        }
      } catch (err) {
        console.error("스트림 첫 메시지 전송 실패:", err);
        return;
      }
    } else {
      // 첫 청크 업데이트 (message_id가 있으면)
      try {
        await editMessageText(chatId, firstChunk, buffer.messageId);
      } catch (err) {
        console.error("스트림 메시지 업데이트 실패:", err);
        // 실패해도 무시 — 타이핑 표시가 있으니 괜찮음
      }
    }
  }

  // 추가 청크들: 새 메시지로 전송 (이전에 보내지 않은 청크만)
  for (let i = buffer.sentChunks; i < chunks.length; i++) {
    try {
      await sendMessage(chatId, chunks[i]);
    } catch (err) {
      console.error(`스트림 추가 청크 ${i} 전송 실패:`, err);
    }
  }

  buffer.chunks = chunks;
  buffer.sentChunks = chunks.length;
}

/** 스트리밍 완료 후 버퍼 정리 */
export async function flushStream(chatId: number): Promise<void> {
  const buffer = buffers.get(chatId);
  if (buffer && buffer.buffer) {
    // 마지막 업데이트 (아직 전송되지 않은 부분)
    await emitPartial(chatId, buffer.buffer);
  }
  buffers.delete(chatId);
}

/** 텔레그램 4096자 한계에 맞춰 문단 경계에서 나눈다 */
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
