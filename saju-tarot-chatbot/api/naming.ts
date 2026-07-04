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
// 이름 리포트/추천은 후보·근거가 있어 분량이 있다. 함수 maxDuration(120초) 안에서
// 끝까지 생성되도록 넉넉히 잡는다.
const MAX_TOKENS = 4500;

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

  // 입력 파싱 (문자열 바디도 안전 처리)
  let body: NamingBody;
  try {
    body = (typeof req.body === "string" ? JSON.parse(req.body) : (req.body ?? {})) as NamingBody;
  } catch {
    res.status(400).json({ error: "요청 본문을 해석할 수 없습니다." });
    return;
  }

  const { mode, evaluation, comparison, brief, options } = body;
  const isRecommend = mode === "recommend";

  // 근거 데이터 검증
  if (isRecommend) {
    if (!brief?.neededElement || !options?.purpose) {
      res.status(400).json({ error: "이름 추천에 필요한 사주 보완 근거가 없습니다." });
      return;
    }
  } else if (!evaluation?.name || !evaluation.sound || !evaluation.fit) {
    res.status(400).json({ error: "이름 감정 계산 결과가 필요합니다." });
    return;
  }

  // 룰 기반 폴백: LLM이 실패해도 계산 근거만으로 항상 결과를 돌려준다 (fortune 패턴).
  const fallbackReply = () =>
    isRecommend ? fallbackRecommend(brief!, options!) : fallbackEvaluation(evaluation!);

  const apiKey = process.env.ANTHROPIC_API_KEY;
  if (!apiKey) {
    res.status(200).json({ reply: withNotice(fallbackReply(), "서버에 API 키가 없어 기본 리포트로 표시합니다."), source: "fallback" });
    return;
  }

  try {
    const system = isRecommend ? NAMING_RECOMMEND_SYSTEM_PROMPT : NAMING_SYSTEM_PROMPT;
    const userMessage = isRecommend
      ? buildNamingRecommendMessage(brief!, options!)
      : buildNamingUserMessage(evaluation!, comparison);

    const anthropic = new Anthropic({ apiKey });
    const response = await anthropic.messages.create({
      model: MODEL,
      max_tokens: MAX_TOKENS,
      system: [{ type: "text", text: system }],
      messages: [{ role: "user", content: userMessage }],
    });
    const text = extractText(response);
    if (text.trim()) {
      // 추천 응답은 JSON이라 뒤에 안내 문구를 붙이면 파싱이 깨진다 → 원문 그대로 반환.
      // 감정 응답만 길이 제한(max_tokens) 시 짧게 알린다.
      const reply =
        !isRecommend && response.stop_reason === "max_tokens"
          ? `${text}\n\n(※ 길이 제한으로 일부 생략되었어요. '다시 추천받기'로 새로 받을 수 있어요.)`
          : text;
      res.status(200).json({ reply, source: "llm" });
    } else {
      // 빈 응답 진단: 어떤 모델이 어떤 stop_reason/블록으로 비었는지 노출한다.
      const blocks = response.content.map((b) => b.type).join(",") || "none";
      const diag = `AI 응답이 비어 기본 리포트로 표시합니다. (모델 ${MODEL} / stop=${response.stop_reason} / blocks=${blocks})`;
      res.status(200).json({ reply: withNotice(fallbackReply(), diag), source: "fallback" });
    }
  } catch (err) {
    console.error(err);
    // LLM 호출 실패 → 500 대신 룰 기반 폴백으로 정상 응답. 사유는 화면에 함께 표기(진단용).
    res.status(200).json({
      reply: withNotice(fallbackReply(), `AI 상세 생성 일시 오류: ${describeError(err)}`),
      source: "fallback",
    });
  }
}

function withNotice(report: string, notice: string): string {
  return `${report}\n\n──────────\n※ ${notice}`;
}

/** 이름 감정 룰 기반 리포트 (계산 근거만으로 구성) */
function fallbackEvaluation(ev: NameEvaluation): string {
  const lines: string[] = [];
  lines.push(`# 한 줄 결론`, ev.headline, "");
  lines.push(`# 소리의 기운 (발음오행)`);
  for (const s of ev.sound.syllables) lines.push(`- ${s.syllable}: 초성 ${s.choseong} · ${s.elementLabel} 기운`);
  lines.push(`흐름: ${ev.sound.harmony}. ${ev.sound.note}`, "");
  lines.push(`# 내 사주와의 궁합`);
  lines.push(`- 보완하면 좋은 기운: ${ev.fit.neededLabel}${ev.fit.avoidLabel ? ` / 과하면 부담이 되는 기운: ${ev.fit.avoidLabel}` : ""}`);
  lines.push(`- 적합도: ${ev.fit.level}. ${ev.fit.note}`, "");
  if (ev.suri) {
    lines.push(`# 획수 수리 (참고)`);
    for (const l of ev.suri.levels) lines.push(`- ${l.name}: ${l.total}획 (${l.level})`);
    lines.push(ev.suri.summary, "");
  }
  lines.push(
    `# 참고`,
    `이 리포트는 발음오행·사주 보완·수리 계산 근거로 만든 기본 요약입니다. 어떤 이름도 "나쁜 이름"으로 단정하지 않으며, 절대적인 길흉 예언이 아니라 참고 자료입니다.`,
  );
  return lines.join("\n");
}

/** 이름 추천 룰 기반 리포트 (사주 보완 근거 방향 안내) */
function fallbackRecommend(brief: NamingBrief, options: NamingRecommendOptions): string {
  const lines: string[] = [];
  lines.push(`# 이름을 이렇게 고르면 좋아요`, brief.note, "");
  lines.push(`# 어울리는 소리 (발음오행)`);
  lines.push(`- 직접 담으면 좋은 초성: ${brief.recommendedChoseong.join(", ")} (${brief.neededLabel} 기운)`);
  if (brief.supportingChoseong.length) {
    lines.push(`- 살려주는 초성: ${brief.supportingChoseong.join(", ")} (${brief.supportingLabel} 기운)`);
  }
  if (brief.avoidLabel && brief.cautionChoseong.length) {
    lines.push(`- 너무 몰리지 않게 할 초성: ${brief.cautionChoseong.join(", ")} (${brief.avoidLabel} 기운)`);
  }
  lines.push("");
  const cond: string[] = [];
  if (options.surname?.trim()) cond.push(`성 '${options.surname.trim()}'`);
  cond.push(`이름 ${options.syllableCount ?? 2}글자`);
  if (options.gender?.trim()) cond.push(options.gender.trim());
  if (options.purpose.desiredImage?.trim()) cond.push(`이미지 "${options.purpose.desiredImage.trim()}"`);
  lines.push(`# 조건`, `- ${cond.join(" · ")}`, "");
  lines.push(
    `# 참고`,
    `위 초성(소리) 방향에 맞춰 이름을 지으면 사주 보완에 어울립니다. 한자 뜻까지 포함한 구체적인 이름 후보 자동 추천은 잠시 후 다시 시도하면 제공됩니다. 인명용 한자·획수·등록 요건은 실제 등록 전 별도 확인이 필요합니다.`,
  );
  return lines.join("\n");
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
