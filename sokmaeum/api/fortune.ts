import type { VercelRequest, VercelResponse } from "@vercel/node";
import Anthropic from "@anthropic-ai/sdk";
import {
  FORTUNE_SYSTEM_PROMPT,
  buildFortuneUserMessage,
  parseFortuneContent,
} from "../src/prompts/fortunePrompt.js";
import { buildFallbackFortune } from "../src/lib/fortuneFallback.js";
import type { FortuneEvidence } from "../src/types/index.js";

// 오늘의 운세 문장 생성 모델 (근거 데이터를 문장화만 하는 가벼운 작업)
const MODEL = process.env.FORTUNE_MODEL ?? "claude-sonnet-5";
const MAX_TOKENS = 1500;

interface FortuneBody {
  evidence?: FortuneEvidence;
}

/**
 * POST /api/fortune
 * body: { evidence: FortuneEvidence }  — 결정론적 엔진이 계산한 근거 데이터
 * 반환: { content: FortuneContent, source: "llm" | "fallback" }
 *
 * 설계 메모: 이 앱은 서버 인증/DB가 없고 사용자 상태는 전부 클라이언트(localStorage)에
 * 있다. 따라서 (userId, 날짜) 캐싱과 자정(KST) 갱신은 클라이언트에서 처리하고, 이 함수는
 * "근거 → 문장" 변환만 담당한다. 근거 계산은 클라이언트/서버 어디서 돌려도 동일(결정론적).
 */
export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (req.method !== "POST") {
    res.status(405).json({ error: "POST 요청만 지원합니다." });
    return;
  }

  const body = req.body as FortuneBody;
  const evidence = body?.evidence;
  if (!evidence || typeof evidence !== "object" || !evidence.ganzhi || !evidence.categories) {
    res.status(400).json({ error: "evidence(근거 데이터)가 필요합니다." });
    return;
  }

  const apiKey = process.env.ANTHROPIC_API_KEY;
  // 키가 없으면 룰 기반 폴백으로라도 정상 응답한다 (엔진 결과만으로도 화면 구성 가능)
  if (!apiKey) {
    res.status(200).json({ content: buildFallbackFortune(evidence), source: "fallback" });
    return;
  }

  try {
    const anthropic = new Anthropic({ apiKey });
    const response = await anthropic.messages.create({
      model: MODEL,
      max_tokens: MAX_TOKENS,
      system: FORTUNE_SYSTEM_PROMPT,
      messages: [
        { role: "user", content: buildFortuneUserMessage(evidence) },
        // JSON으로 시작하도록 프리필 → 파싱 안정성 향상
        { role: "assistant", content: "{" },
      ],
    });

    const text =
      "{" +
      response.content
        .filter((b): b is Anthropic.Messages.TextBlock => b.type === "text")
        .map((b) => b.text)
        .join("");

    const content = parseFortuneContent(text);
    if (content) {
      res.status(200).json({ content, source: "llm" });
    } else {
      // 파싱 실패 → 폴백
      res.status(200).json({ content: buildFallbackFortune(evidence), source: "fallback" });
    }
  } catch (err) {
    console.error(err);
    // LLM 호출 실패 → 룰 기반 폴백으로 정상 응답
    res.status(200).json({ content: buildFallbackFortune(evidence), source: "fallback" });
  }
}
