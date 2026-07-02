import type { VercelRequest, VercelResponse } from "@vercel/node";
import Anthropic from "@anthropic-ai/sdk";
import { computeLuckCycles, computeSajuChart } from "../src/lib/saju";
import {
  READING_SYSTEM_PROMPT,
  buildCompareUserMessage,
  buildReadingUserMessage,
  type CompareReadingInput,
} from "../src/prompts/systemPrompt";
import type { BirthInfo, ChatMessage, DrawnTarotCard, ReadingFocus, ReadingType } from "../src/types";

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
    res.status(500).json({ error: "리딩 생성 중 오류가 발생했습니다." });
  }
}

function extractText(response: Anthropic.Messages.Message): string {
  return response.content
    .filter((block): block is Anthropic.Messages.TextBlock => block.type === "text")
    .map((block) => block.text)
    .join("\n");
}
