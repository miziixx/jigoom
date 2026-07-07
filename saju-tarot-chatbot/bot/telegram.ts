// 텔레그램 Bot API 최소 클라이언트 (롱폴링). 외부 의존성 없이 Node 18+ 내장 fetch 사용.

const TOKEN = process.env.TELEGRAM_BOT_TOKEN;
if (!TOKEN) {
  console.error("TELEGRAM_BOT_TOKEN 환경변수가 필요합니다. @BotFather 에서 봇을 만들고 토큰을 설정하세요.");
  process.exit(1);
}
const API = `https://api.telegram.org/bot${TOKEN}`;

export interface TgMessage {
  message_id: number;
  from?: { id: number; first_name?: string; username?: string };
  chat: { id: number; type: string };
  text?: string;
}

export interface TgUpdate {
  update_id: number;
  message?: TgMessage;
}

async function call<T>(method: string, params: Record<string, unknown>): Promise<T> {
  const res = await fetch(`${API}/${method}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(params),
  });
  const json = (await res.json()) as { ok: boolean; result?: T; description?: string };
  if (!json.ok) throw new Error(`Telegram ${method} 실패: ${json.description}`);
  return json.result as T;
}

export async function getUpdates(offset: number): Promise<TgUpdate[]> {
  return call<TgUpdate[]>("getUpdates", {
    offset,
    timeout: 50,
    allowed_updates: ["message"],
  });
}

export async function sendTyping(chatId: number): Promise<void> {
  try {
    await call("sendChatAction", { chat_id: chatId, action: "typing" });
  } catch {
    // 표시용 액션이라 실패해도 무시
  }
}

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
 * 메시지 전송. 기본은 Markdown으로 먼저 시도하고, 파싱 오류(짝 안 맞는 * 등)면 일반 텍스트로 재전송한다.
 * `plain: true`면 Markdown 시도 없이 바로 일반 텍스트로 보낸다 (스트리밍 중간 갱신용).
 * 첫 청크의 message_id를 반환한다 (스트리밍 편집용).
 */
export async function sendMessage(
  chatId: number,
  text: string,
  opts?: { plain?: boolean },
): Promise<number | undefined> {
  let firstMessageId: number | undefined;
  for (const chunk of splitChunks(text)) {
    let msg: TgMessage | undefined;
    if (opts?.plain) {
      msg = await call<TgMessage>("sendMessage", { chat_id: chatId, text: chunk });
    } else {
      try {
        msg = await call<TgMessage>("sendMessage", { chat_id: chatId, text: chunk, parse_mode: "Markdown" });
      } catch {
        msg = await call<TgMessage>("sendMessage", { chat_id: chatId, text: chunk });
      }
    }
    if (!firstMessageId && msg?.message_id) {
      firstMessageId = msg.message_id;
    }
  }
  return firstMessageId;
}

/**
 * 이미 보낸 메시지를 편집한다 (스트리밍 업데이트용).
 * 성공/"내용 동일(not modified)"이면 true, 편집 자체가 실패하면 false를 반환한다.
 * `plain: true`면 Markdown 시도 없이 일반 텍스트로만 편집한다.
 */
export async function editMessageText(
  chatId: number,
  text: string,
  messageId?: number,
  opts?: { plain?: boolean },
): Promise<boolean> {
  if (messageId == null) return false;
  const tryEdit = async (useMarkdown: boolean): Promise<boolean> => {
    try {
      await call("editMessageText", {
        chat_id: chatId,
        message_id: messageId,
        text,
        ...(useMarkdown ? { parse_mode: "Markdown" } : {}),
      });
      return true;
    } catch (err) {
      // 바꿀 내용이 없으면(이미 같은 텍스트) 성공으로 본다.
      const m = err instanceof Error ? err.message : String(err);
      if (m.includes("not modified")) return true;
      return false;
    }
  };
  if (!opts?.plain && (await tryEdit(true))) return true;
  return tryEdit(false);
}
