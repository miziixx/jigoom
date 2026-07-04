import type { VercelRequest, VercelResponse } from "@vercel/node";
import Anthropic from "@anthropic-ai/sdk";
import {
  buildNamingRecommendMessage,
  buildNamingUserMessage,
  NAMING_RECOMMEND_SYSTEM_PROMPT,
  NAMING_SYSTEM_PROMPT,
} from "../src/prompts/namingPrompt.js";
import type { NameComparison, NameEvaluation, NamingBrief, NamingRecommendOptions } from "../src/lib/naming.js";

const MODEL = process.env.READING_MODEL ?? "claude-sonnet-5";
// 비스트리밍 응답이라 생성 시간이 곧 응답 지연이다. 서버리스 제한시간 안에 확실히
// 끝나도록 토큰을 절제한다(검증된 fortune=1500 수준).
const MAX_TOKENS = 1800;

interface NamingBody {
  mode?: "evaluate" | "recommend";
  evaluation?: NameEvaluation;
  comparison?: NameComparison | null;
  brief?: NamingBrief;
  options?: NamingRecommendOptions;
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

  try {
    const rawBody = (typeof req.body === "string" ? JSON.parse(req.body) : (req.body ?? {})) as NamingBody;
    const { mode, evaluation, comparison, brief, options } = rawBody;
    const isRecommend = mode === "recommend";

    let system: string;
    let userMessage: string;
    if (isRecommend) {
      if (!brief?.neededElement || !options?.purpose) {
        res.status(400).json({ error: "이름 추천에 필요한 사주 보완 근거가 없습니다." });
        return;
      }
      system = NAMING_RECOMMEND_SYSTEM_PROMPT;
      userMessage = buildNamingRecommendMessage(brief, options);
    } else {
      if (!evaluation?.name || !evaluation.sound || !evaluation.fit) {
        res.status(400).json({ error: "이름 감정 계산 결과가 필요합니다." });
        return;
      }
      system = NAMING_SYSTEM_PROMPT;
      userMessage = buildNamingUserMessage(evaluation, comparison);
    }

    const anthropic = new Anthropic({ apiKey });
    const response = await anthropic.messages.create({
      model: MODEL,
      max_tokens: MAX_TOKENS,
      system,
      messages: [{ role: "user", content: userMessage }],
    });
    res.status(200).json({ reply: extractText(response) });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: `이름 해석 생성 중 오류: ${describeError(err)}` });
  }
}

function extractText(response: Anthropic.Messages.Message): string {
  return response.content
    .filter((block): block is Anthropic.Messages.TextBlock => block.type === "text")
    .map((block) => block.text)
    .join("\n");
}

function describeError(err: unknown): string {
  if (err instanceof Anthropic.APIError) {
    const detail = err.message;
    if (err.status === 401) return `API 키 인증 실패 (401). ANTHROPIC_API_KEY 값을 확인하세요. — ${detail}`;
    if (err.status === 400 && detail.includes("credit"))
      return `Anthropic 크레딧 부족 (400). console.anthropic.com > Billing 에서 충전하세요. — ${detail}`;
    if (err.status === 404) return `모델을 찾을 수 없음 (404). READING_MODEL 설정을 확인하세요. — ${detail}`;
    if (err.status === 429) return `요청 한도 초과 (429). 잠시 후 다시 시도하세요. — ${detail}`;
    if (err.status === 529) return "Anthropic 서버 과부하 (529). 잠시 후 다시 시도하세요.";
    return `Anthropic API 오류 (${err.status}): ${detail}`;
  }
  return err instanceof Error ? err.message : String(err);
}
