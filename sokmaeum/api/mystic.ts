import type { VercelRequest, VercelResponse } from "@vercel/node";
import Anthropic from "@anthropic-ai/sdk";
import {
  MYSTIC_SYSTEM_PROMPT,
  buildMysticUserMessage,
  parseMysticResult,
} from "../src/prompts/mysticPrompt.js";
import { buildFallbackReading } from "../src/features/mystic-reading/buildFallbackReading.js";
import type { MysticEvidence } from "../src/types/index.js";

// 속마음 리딩 문장 생성 모델 (근거를 심리 문장으로 번역만 하는 작업)
const MODEL = process.env.MYSTIC_MODEL ?? "claude-sonnet-5";
const MAX_TOKENS = 4000;

interface MysticBody {
  evidence?: MysticEvidence;
}

/**
 * POST /api/mystic
 * body: { evidence: MysticEvidence } — 결정론적 엔진이 계산한 근거 데이터
 * 반환: { result: MysticReadingResult, source: "llm" | "fallback" }
 *
 * 오늘의 운세(api/fortune)와 동일한 설계: 근거 계산은 클라이언트/서버 어디서 돌려도
 * 동일(결정론적)하고, 이 함수는 "근거 → 심리 문장" 변환만 담당한다.
 */
export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (req.method !== "POST") {
    res.status(405).json({ error: "POST 요청만 지원합니다." });
    return;
  }

  const body = req.body as MysticBody;
  const evidence = body?.evidence;
  if (!evidence || typeof evidence !== "object" || !evidence.dayMaster || !Array.isArray(evidence.notes)) {
    res.status(400).json({ error: "evidence(근거 데이터)가 필요합니다." });
    return;
  }

  const apiKey = process.env.ANTHROPIC_API_KEY;
  // 키가 없으면 룰 기반 폴백으로라도 정상 응답한다
  if (!apiKey) {
    res.status(200).json({ result: buildFallbackReading(evidence), source: "fallback" });
    return;
  }

  try {
    const anthropic = new Anthropic({ apiKey });
    const response = await anthropic.messages.create({
      model: MODEL,
      max_tokens: MAX_TOKENS,
      system: MYSTIC_SYSTEM_PROMPT,
      messages: [
        { role: "user", content: buildMysticUserMessage(evidence) },
        { role: "assistant", content: "{" },
      ],
    });

    const text =
      "{" +
      response.content
        .filter((b): b is Anthropic.Messages.TextBlock => b.type === "text")
        .map((b) => b.text)
        .join("");

    const result = parseMysticResult(text);
    if (result) {
      res.status(200).json({ result, source: "llm" });
    } else {
      res.status(200).json({ result: buildFallbackReading(evidence), source: "fallback" });
    }
  } catch (err) {
    console.error(err);
    res.status(200).json({ result: buildFallbackReading(evidence), source: "fallback" });
  }
}
