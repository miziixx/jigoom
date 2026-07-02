import type { VercelRequest, VercelResponse } from "@vercel/node";
import Anthropic from "@anthropic-ai/sdk";
import { computeLuckCycles, computeSajuChart } from "../src/lib/saju.js";
import {
  READING_SYSTEM_PROMPT,
  buildCompareUserMessage,
  buildReadingUserMessage,
  type CompareReadingInput,
} from "../src/prompts/systemPrompt.js";
import type { BirthInfo, ChatMessage, DrawnTarotCard, ReadingFocus, ReadingType } from "../src/types/index.js";

// READING_MODEL 환경변수로 상위 모델 교체 가능 (프리미엄 리딩 등)
const MODEL = process.env.READING_MODEL ?? "claude-sonnet-5";
const MAX_TOKENS = 8192;

interface NewReadingBody {
  type: Exclude<ReadingType, never>;
  question: string;
  focus?: ReadingFocus;
  birthInfo?: BirthInfo;
  tarotCards?: DrawnTarotCard[];
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

  try {
    if (body.type === "followup") {
      if (!body.history || body.history.length === 0) {
        res.status(400).json({ error: "history가 필요합니다." });
        return;
      }
      const response = await anthropic.messages.create({
        model: MODEL,
        max_tokens: MAX_TOKENS,
        system: READING_SYSTEM_PROMPT,
        messages: body.history.map((m) => ({ role: m.role, content: m.content })),
      });
      const reply = extractText(response);
      res.status(200).json({ reply });
      return;
    }

    if (body.type === "compare") {
      if (!body.readingA?.reply || !body.readingB?.reply) {
        res.status(400).json({ error: "비교할 두 리딩(readingA, readingB)이 필요합니다." });
        return;
      }
      const response = await anthropic.messages.create({
        model: MODEL,
        max_tokens: MAX_TOKENS,
        system: READING_SYSTEM_PROMPT,
        messages: [{ role: "user", content: buildCompareUserMessage(body.readingA, body.readingB) }],
      });
      res.status(200).json({ reply: extractText(response) });
      return;
    }

    const { type, question, focus, birthInfo, tarotCards } = body;

    if ((type === "saju" || type === "combo") && !birthInfo) {
      res.status(400).json({ error: "birthInfo가 필요합니다." });
      return;
    }
    if ((type === "tarot" || type === "combo") && (!tarotCards || tarotCards.length === 0)) {
      res.status(400).json({ error: "tarotCards가 필요합니다." });
      return;
    }

    const sajuChart = birthInfo ? computeSajuChart(birthInfo) : undefined;
    const luckCycles = birthInfo ? computeLuckCycles(birthInfo) : undefined;
    const userMessage = buildReadingUserMessage({
      type,
      question,
      focus,
      birthInfo,
      sajuChart,
      luckCycles,
      tarotCards,
    });

    const response = await anthropic.messages.create({
      model: MODEL,
      max_tokens: MAX_TOKENS,
      system: READING_SYSTEM_PROMPT,
      messages: [{ role: "user", content: userMessage }],
    });
    const reply = extractText(response);

    res.status(200).json({ reply, userMessage, sajuChart, luckCycles });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: `리딩 생성 중 오류: ${describeError(err)}` });
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
