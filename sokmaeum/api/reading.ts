import type { VercelRequest, VercelResponse } from "@vercel/node";
import Anthropic from "@anthropic-ai/sdk";
import { computeLuckCycles, computeSajuChart } from "../src/lib/saju.js";
import {
  READING_SYSTEM_PROMPT,
  buildCompareUserMessage,
  buildReadingUserMessage,
  type CompareReadingInput,
} from "../src/prompts/systemPrompt.js";
import type {
  BirthInfo,
  ChatMessage,
  DrawnTarotCard,
  ReadingContext,
  ReadingFocus,
  ReadingType,
} from "../src/types/index.js";

// 응답 스트리밍 활성화 (긴 리딩도 첫 토큰부터 바로 전송 → 게이트웨이 504 방지)
export const config = { supportsResponseStreaming: true };

// READING_MODEL 환경변수로 상위 모델 교체 가능 (프리미엄 리딩 등)
const MODEL = process.env.READING_MODEL ?? "claude-sonnet-5";
// 스트리밍: 전문가 리딩이 문장 중간에 잘리지 않도록 여유 있게
const MAX_TOKENS_STREAM = 16000;
// 일괄 응답(구버전 클라이언트): 함수 시간 제한 안에서 완성돼야 하므로 보수적으로
const MAX_TOKENS_COMPLETE = 8192;

interface NewReadingBody {
  type: Exclude<ReadingType, never>;
  question: string;
  focus?: ReadingFocus;
  context?: ReadingContext;
  birthInfo?: BirthInfo;
  tarotCards?: DrawnTarotCard[];
  spreadNote?: string;
}

interface FollowUpBody {
  type: "followup";
  history: ChatMessage[];
}

interface CompareBody {
  type: "compare";
  readingA: CompareReadingInput;
  readingB: CompareReadingInput;
}

type RequestBody = NewReadingBody | FollowUpBody | CompareBody;

/** 클라이언트가 NDJSON 스트리밍을 받을 수 있다고 알렸는지 (구버전 클라이언트는 JSON 일괄 응답 유지) */
function wantsStream(req: VercelRequest): boolean {
  return (req.headers.accept ?? "").includes("application/x-ndjson");
}

/**
 * Anthropic 스트림을 NDJSON 라인으로 흘려보낸다.
 * 라인 형식: {"meta":{...}} → {"text":"..."}* → {"done":true} / 실패 시 {"error":"..."}
 */
async function streamMessages(
  res: VercelResponse,
  anthropic: Anthropic,
  messages: Anthropic.Messages.MessageParam[],
  meta?: Record<string, unknown>,
): Promise<void> {
  res.status(200);
  res.setHeader("Content-Type", "application/x-ndjson; charset=utf-8");
  res.setHeader("Cache-Control", "no-cache, no-transform");
  // 프록시(nginx 등)가 응답을 버퍼링하지 않고 즉시 흘려보내도록 한다
  res.setHeader("X-Accel-Buffering", "no");
  if (meta) res.write(JSON.stringify({ meta }) + "\n");

  // 생성 시작 전(모델 지연)·토큰 사이 유휴 구간에 게이트웨이/모바일이 연결을 끊지
  // 않도록 주기적으로 하트비트를 보낸다. 클라이언트는 알 수 없는 필드를 무시한다.
  const heartbeat = setInterval(() => {
    try {
      res.write(JSON.stringify({ heartbeat: true }) + "\n");
    } catch {
      // 이미 닫힌 연결
    }
  }, 10000);

  try {
    const stream = anthropic.messages.stream({
      model: MODEL,
      max_tokens: MAX_TOKENS_STREAM,
      system: READING_SYSTEM_PROMPT,
      messages,
    });
    for await (const event of stream) {
      if (event.type === "content_block_delta" && event.delta.type === "text_delta") {
        res.write(JSON.stringify({ text: event.delta.text }) + "\n");
      }
    }
    res.write(JSON.stringify({ done: true }) + "\n");
  } catch (err) {
    console.error(err);
    res.write(JSON.stringify({ error: `리딩 생성 중 오류: ${describeError(err)}` }) + "\n");
  } finally {
    clearInterval(heartbeat);
  }
  res.end();
}

/** 스트리밍 미지원 클라이언트용 일괄 응답 */
async function completeMessages(
  anthropic: Anthropic,
  messages: Anthropic.Messages.MessageParam[],
): Promise<string> {
  const response = await anthropic.messages.create({
    model: MODEL,
    max_tokens: MAX_TOKENS_COMPLETE,
    system: READING_SYSTEM_PROMPT,
    messages,
  });
  return extractText(response);
}

export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (req.method !== "POST") {
    res.status(405).json({ error: "POST 요청만 지원합니다." });
    return;
  }

  const apiKey = process.env.ANTHROPIC_API_KEY;
  if (!apiKey) {
    res.status(500).json({ error: "서버에 ANTHROPIC_API_KEY가 설정되어 있지 않습니다." });
    return;
  }

  const body = req.body as RequestBody;
  const anthropic = new Anthropic({ apiKey });
  const streaming = wantsStream(req);

  try {
    if (body.type === "followup") {
      if (!body.history || body.history.length === 0) {
        res.status(400).json({ error: "history가 필요합니다." });
        return;
      }
      const messages = body.history.map((m) => ({ role: m.role, content: m.content }));
      if (streaming) {
        await streamMessages(res, anthropic, messages);
      } else {
        res.status(200).json({ reply: await completeMessages(anthropic, messages) });
      }
      return;
    }

    if (body.type === "compare") {
      if (!body.readingA?.reply || !body.readingB?.reply) {
        res.status(400).json({ error: "비교할 두 리딩(readingA, readingB)이 필요합니다." });
        return;
      }
      const messages: Anthropic.Messages.MessageParam[] = [
        { role: "user", content: buildCompareUserMessage(body.readingA, body.readingB) },
      ];
      if (streaming) {
        await streamMessages(res, anthropic, messages);
      } else {
        res.status(200).json({ reply: await completeMessages(anthropic, messages) });
      }
      return;
    }

    const { type, question, focus, context, birthInfo, tarotCards, spreadNote } = body;

    if ((type === "saju" || type === "combo" || type === "today" || type === "flow") && !birthInfo) {
      res.status(400).json({ error: "birthInfo가 필요합니다." });
      return;
    }
    if ((type === "tarot" || type === "combo") && (!tarotCards || tarotCards.length === 0)) {
      res.status(400).json({ error: "tarotCards가 필요합니다." });
      return;
    }

    const sajuChart = birthInfo ? computeSajuChart(birthInfo) : undefined;
    const luckCycles = birthInfo
      ? computeLuckCycles(birthInfo, new Date(), { includeMonthlyFlow: type === "flow" })
      : undefined;
    const userMessage = buildReadingUserMessage({
      type,
      question,
      focus,
      context,
      birthInfo,
      sajuChart,
      luckCycles,
      tarotCards,
      spreadNote,
    });

    const messages: Anthropic.Messages.MessageParam[] = [{ role: "user", content: userMessage }];
    if (streaming) {
      await streamMessages(res, anthropic, messages, { userMessage, sajuChart, luckCycles });
    } else {
      const reply = await completeMessages(anthropic, messages);
      res.status(200).json({ reply, userMessage, sajuChart, luckCycles });
    }
  } catch (err) {
    console.error(err);
    if (!res.headersSent) {
      res.status(500).json({ error: `리딩 생성 중 오류: ${describeError(err)}` });
    } else {
      res.end();
    }
  }
}

/** Anthropic API 에러를 사용자가 조치할 수 있는 메시지로 변환 */
function describeError(err: unknown): string {
  if (err instanceof Anthropic.APIError) {
    const detail = err.message;
    if (err.status === 401) return `API 키 인증 실패 (401). ANTHROPIC_API_KEY 값을 확인하세요. — ${detail}`;
    if (err.status === 400 && detail.includes("credit"))
      return `Anthropic 크레딧 부족 (400). console.anthropic.com > Billing 에서 충전하세요. — ${detail}`;
    if (err.status === 404) return `모델을 찾을 수 없음 (404). READING_MODEL 설정을 확인하세요. — ${detail}`;
    if (err.status === 429) return `요청 한도 초과 (429). 잠시 후 다시 시도하세요. — ${detail}`;
    if (err.status === 529) return `Anthropic 서버 과부하 (529). 잠시 후 다시 시도하세요.`;
    return `Anthropic API 오류 (${err.status}): ${detail}`;
  }
  return err instanceof Error ? err.message : String(err);
}

function extractText(response: Anthropic.Messages.Message): string {
  return response.content
    .filter((block): block is Anthropic.Messages.TextBlock => block.type === "text")
    .map((block) => block.text)
    .join("\n");
}
