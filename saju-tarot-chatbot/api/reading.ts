import type { VercelRequest, VercelResponse } from "@vercel/node";
import Anthropic from "@anthropic-ai/sdk";
import { checkSecurity, clampText, MAX_QUESTION_LEN, MAX_CONTEXT_FIELD_LEN } from "./_security.js";
import {
  READING_SYSTEM_PROMPT,
  buildCompareUserMessage,
  buildReadingJudgmentPack,
  buildReadingUserMessage,
  type CompareReadingInput,
} from "../src/prompts/systemPrompt.js";
import {
  buildJudgmentFallback,
  buildJudgmentRewritePrompt,
  finalizeJudgmentPackAudit,
  passOrNeedsRewrite,
  type JudgmentGateResult,
} from "../src/lib/judgmentGate.js";
import { validateOutputAgainstJudgmentPack, type JudgmentValidationResult } from "../src/lib/judgmentValidation.js";
import { buildContentRewritePrompt, contentNeedsRewrite, validateReadingContent } from "../src/lib/readingValidation.js";
import type { JudgmentPack } from "../src/lib/judgmentTypes.js";
import type {
  ChatMessage,
  CrossValidationReport,
  DrawnTarotCard,
  Gender,
  LuckCycles,
  PastValidationReport,
  ReadingContext,
  ReadingFocus,
  ReadingType,
  SajuChart,
} from "../src/types/index.js";

// 응답 스트리밍 활성화 (긴 리딩도 첫 토큰부터 바로 전송 → 게이트웨이 504 방지)
export const config = { supportsResponseStreaming: true };

// READING_MODEL 환경변수로 상위 모델 교체 가능 (프리미엄 리딩 등)
const MODEL = process.env.READING_MODEL ?? "claude-sonnet-5";
// A/B·속도 측정용: 요청별로 모델을 고를 수 있게 한다(허용목록만).
// body.model 필드가 없거나 목록에 없으면 기본(MODEL) 유지 → 프로덕션 무영향.
// 정확도는 결정론 엔진(4대 고전 근거)이 담보하므로 빠른 모델도 "번역"만 하면 되도록 설계됨.
const MODEL_ALLOWLIST: Record<string, string> = {
  haiku: "claude-haiku-4-5-20251001",
  draft: "claude-haiku-4-5-20251001",
  sonnet: "claude-sonnet-5",
  deep: "claude-sonnet-5",
};
function resolveModel(body: unknown): string {
  const raw = (body as { model?: unknown } | null)?.model;
  if (typeof raw === "string" && MODEL_ALLOWLIST[raw]) return MODEL_ALLOWLIST[raw];
  return MODEL;
}
// 스트리밍: 전문가 리딩이 문장 중간에 잘리지 않도록 여유 있게
const MAX_TOKENS_STREAM = 16000;
// 일괄 응답(구버전 클라이언트): 함수 시간 제한 안에서 완성돼야 하므로 보수적으로
const MAX_TOKENS_COMPLETE = 8192;

interface NewReadingBody {
  type: Exclude<ReadingType, never>;
  question: string;
  focus?: ReadingFocus;
  context?: ReadingContext;
  sectionGroup?: "front" | "back";
  // 개인정보 보호: 생년월일 원본(birthInfo)은 서버로 보내지 않는다. 사주 계산은 클라이언트에서
  // 끝내고, 그 계산 결과와 성별만 전달한다.
  gender?: Gender;
  sajuChart?: SajuChart;
  luckCycles?: LuckCycles;
  tarotCards?: DrawnTarotCard[];
  spreadNote?: string;
  // 과거 검증 결과. 계산은 클라이언트에서 끝내고 결과 값만 전달한다(서버는 통과만).
  pastValidation?: PastValidationReport;
  // 사주·자미두수 교차검증 결과. 자미두수 계산·대조는 클라이언트에서 끝내고 압축 리포트만 전달한다.
  crossValidation?: CrossValidationReport;
}

interface FollowUpBody {
  type: "followup";
  history: ChatMessage[];
  followUpMode?: "concise" | "deep";
}

interface CompareBody {
  type: "compare";
  readingA: CompareReadingInput;
  readingB: CompareReadingInput;
}

type RequestBody = NewReadingBody | FollowUpBody | CompareBody;

function withContinuation(
  messages: Anthropic.Messages.MessageParam[],
  continueFrom: string,
): Anthropic.Messages.MessageParam[] {
  if (!continueFrom) return messages;
  const instruction = [
    "이전 응답이 아래 내용까지 작성된 상태에서 중단되었습니다.",
    "이미 쓴 내용을 반복하지 말고, 바로 다음 문장부터 자연스럽게 이어서 완성해라.",
    "",
    "[이전 응답]",
    continueFrom,
  ].join("\n");
  const last = messages[messages.length - 1];
  if (last?.role === "user") {
    return [...messages.slice(0, -1), { role: "user", content: `${last.content}\n\n${instruction}` }];
  }
  return [...messages, { role: "user", content: instruction }];
}

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
  options: { maxTokens?: number; model?: string } = {},
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
      model: options.model ?? MODEL,
      max_tokens: options.maxTokens ?? MAX_TOKENS_STREAM,
      system: [{ type: "text", text: READING_SYSTEM_PROMPT, cache_control: { type: "ephemeral" } }],
      messages,
    });
    // stop_reason이 "max_tokens"면 아직 다 못 쓴 것 → 클라이언트가 이어쓰기(continue)를 요청한다.
    let stopReason: string | null = null;
    for await (const event of stream) {
      if (event.type === "content_block_delta" && event.delta.type === "text_delta") {
        res.write(JSON.stringify({ text: event.delta.text }) + "\n");
      } else if (event.type === "message_delta" && event.delta.stop_reason) {
        stopReason = event.delta.stop_reason;
      }
    }
    res.write(JSON.stringify({ done: true, stopReason }) + "\n");
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
  options: { maxTokens?: number; model?: string } = {},
): Promise<string> {
  const response = await anthropic.messages.create({
    model: options.model ?? MODEL,
    max_tokens: options.maxTokens ?? MAX_TOKENS_COMPLETE,
    system: READING_SYSTEM_PROMPT,
    messages,
  });
  return extractText(response);
}

/**
 * 게이트 결과에서 PII 없는 이유 코드만 추출한다 (Quality Dashboard 관찰용).
 * rewrite/fallback으로 escalation된 원인(첫 검증·재작성 검증 이슈 code)만 담는다. 절대 throw하지 않는다.
 */
function gateReasonCodes(gate: JudgmentGateResult): string[] {
  try {
    const codes = new Set<string>();
    const g = gate as {
      firstValidation?: { issues?: { code: string }[] };
      rewriteValidation?: { issues?: { code: string }[] };
    };
    for (const issue of g.firstValidation?.issues ?? []) codes.add(issue.code);
    for (const issue of g.rewriteValidation?.issues ?? []) codes.add(issue.code);
    return [...codes];
  } catch {
    return [];
  }
}

/** done 라인/JSON에 실을 PII 없는 게이트 신호 */
function gateSignal(gate: JudgmentGateResult): { status: string; reasonCodes: string[] } {
  return { status: gate.status, reasonCodes: gateReasonCodes(gate) };
}

/**
 * 1차 응답이 Evidence Gate 검증에 실패했을 때만 호출되는 재작성 경로.
 * 대다수 리딩은 이 함수를 타지 않고 1차 생성만으로 끝난다 — API 호출은 여기서만 추가로 발생한다.
 */
async function rewriteAfterFailedGate(
  anthropic: Anthropic,
  firstReply: string,
  firstValidation: JudgmentValidationResult,
  judgmentPack: JudgmentPack,
  model: string = MODEL,
): Promise<{ reply: string; gate: JudgmentGateResult }> {
  const rewritePrompt = buildJudgmentRewritePrompt({ originalReply: firstReply, validation: firstValidation, pack: judgmentPack });
  const rewriteReply = await completeMessages(anthropic, [{ role: "user", content: rewritePrompt }], { maxTokens: 7000, model });
  const rewriteValidation = validateOutputAgainstJudgmentPack({ reply: rewriteReply, pack: judgmentPack });
  if (rewriteValidation.ok) {
    const gate: JudgmentGateResult = {
      status: "rewrite",
      reply: rewriteReply,
      validation: rewriteValidation,
      firstValidation,
      rewriteAttempted: true,
      fallbackUsed: false,
    };
    return { reply: rewriteReply, gate };
  }

  const fallbackReply = buildJudgmentFallback(judgmentPack);
  const fallbackValidation = validateOutputAgainstJudgmentPack({ reply: fallbackReply, pack: judgmentPack });
  const gate: JudgmentGateResult = {
    status: "fallback",
    reply: fallbackReply,
    validation: fallbackValidation,
    firstValidation,
    rewriteValidation,
    rewriteAttempted: true,
    fallbackUsed: true,
  };
  return { reply: fallbackReply, gate };
}

/**
 * rewriteAfterFailedGate의 스트리밍판. NDJSON 스트림 경로(streamJudgmentGatedReply)에서만 쓴다.
 * 재작성 호출을 completeMessages(블로킹)로 기다리는 대신 그대로 스트리밍해서, 드물게 게이트에
 * 걸리는 경우에도 화면이 멈춘 것처럼 보이지 않고 텍스트가 계속 흐르게 한다.
 * 클라이언트에는 먼저 {text:"", replace:true}로 1차 응답을 비우고, 그 뒤 델타를 이어붙이게 한다.
 * 재작성도 검증에 실패하면 결정론적 fallback(API 호출 없음)으로 즉시 교체한다.
 */
async function streamRewriteAfterFailedGate(
  res: VercelResponse,
  anthropic: Anthropic,
  firstReply: string,
  firstValidation: JudgmentValidationResult,
  judgmentPack: JudgmentPack,
  model: string = MODEL,
): Promise<{ reply: string; gate: JudgmentGateResult }> {
  const rewritePrompt = buildJudgmentRewritePrompt({ originalReply: firstReply, validation: firstValidation, pack: judgmentPack });
  res.write(JSON.stringify({ text: "", replace: true }) + "\n");

  let rewriteReply = "";
  const stream = anthropic.messages.stream({
    model,
    max_tokens: 7000,
    system: [{ type: "text", text: READING_SYSTEM_PROMPT, cache_control: { type: "ephemeral" } }],
    messages: [{ role: "user", content: rewritePrompt }],
  });
  for await (const event of stream) {
    if (event.type === "content_block_delta" && event.delta.type === "text_delta") {
      rewriteReply += event.delta.text;
      res.write(JSON.stringify({ text: event.delta.text }) + "\n");
    }
  }

  const rewriteValidation = validateOutputAgainstJudgmentPack({ reply: rewriteReply, pack: judgmentPack });
  if (rewriteValidation.ok) {
    const gate: JudgmentGateResult = {
      status: "rewrite",
      reply: rewriteReply,
      validation: rewriteValidation,
      firstValidation,
      rewriteAttempted: true,
      fallbackUsed: false,
    };
    return { reply: rewriteReply, gate };
  }

  const fallbackReply = buildJudgmentFallback(judgmentPack);
  const fallbackValidation = validateOutputAgainstJudgmentPack({ reply: fallbackReply, pack: judgmentPack });
  res.write(JSON.stringify({ text: fallbackReply, replace: true }) + "\n");
  const gate: JudgmentGateResult = {
    status: "fallback",
    reply: fallbackReply,
    validation: fallbackValidation,
    firstValidation,
    rewriteValidation,
    rewriteAttempted: true,
    fallbackUsed: true,
  };
  return { reply: fallbackReply, gate };
}

async function completeJudgmentGatedReply(
  anthropic: Anthropic,
  messages: Anthropic.Messages.MessageParam[],
  judgmentPack: JudgmentPack,
  model: string = MODEL,
): Promise<{ reply: string; judgmentPack: JudgmentPack; gate: JudgmentGateResult }> {
  const firstReply = await completeMessages(anthropic, messages, { model });
  const firstPass = passOrNeedsRewrite(firstReply, judgmentPack);
  if (firstPass.status === "pass") {
    return { reply: firstPass.reply, judgmentPack: finalizeJudgmentPackAudit(judgmentPack, firstPass), gate: firstPass };
  }
  const gated = await rewriteAfterFailedGate(anthropic, firstReply, firstPass.validation, judgmentPack, model);
  return { reply: gated.reply, judgmentPack: finalizeJudgmentPackAudit(judgmentPack, gated.gate), gate: gated.gate };
}

/**
 * 판단 팩(JudgmentPack) 검증이 걸린 새 리딩을 실시간 스트리밍으로 생성한다.
 * 이전 버전은 전체 응답을 버퍼링(non-streaming)한 뒤에야 클라이언트로 보내
 * 리딩 하나가 통째로 끝날 때까지 화면에 아무것도 안 보였다(체감 지연의 핵심 원인).
 * 이제는 1차 생성을 그대로 스트리밍하고, 검증은 API 호출 없는 로컬 연산이라 지연이 없다.
 * 검증에 실패하는 드문 경우에만 재작성(2차 API 호출)을 하고, 이미 보여준 텍스트를 안전한
 * 최종본으로 교체(replace)하는 라인을 한 번 더 보낸다.
 */
async function streamJudgmentGatedReply(
  res: VercelResponse,
  anthropic: Anthropic,
  messages: Anthropic.Messages.MessageParam[],
  meta: Record<string, unknown> | undefined,
  judgmentPack: JudgmentPack,
  model: string = MODEL,
): Promise<void> {
  res.status(200);
  res.setHeader("Content-Type", "application/x-ndjson; charset=utf-8");
  res.setHeader("Cache-Control", "no-cache, no-transform");
  res.setHeader("X-Accel-Buffering", "no");
  if (meta) res.write(JSON.stringify({ meta }) + "\n");

  const heartbeat = setInterval(() => {
    try {
      res.write(JSON.stringify({ heartbeat: true }) + "\n");
    } catch {
      // 이미 닫힌 연결
    }
  }, 10000);

  try {
    let reply = "";
    const stream = anthropic.messages.stream({
      model,
      max_tokens: MAX_TOKENS_STREAM,
      system: [{ type: "text", text: READING_SYSTEM_PROMPT, cache_control: { type: "ephemeral" } }],
      messages,
    });
    let stopReason: string | null = null;
    for await (const event of stream) {
      if (event.type === "content_block_delta" && event.delta.type === "text_delta") {
        reply += event.delta.text;
        res.write(JSON.stringify({ text: event.delta.text }) + "\n");
      } else if (event.type === "message_delta" && event.delta.stop_reason) {
        stopReason = event.delta.stop_reason;
      }
    }

    const firstPass = passOrNeedsRewrite(reply, judgmentPack);
    if (firstPass.status === "pass") {
      res.write(JSON.stringify({ done: true, stopReason, gate: gateSignal(firstPass) }) + "\n");
    } else {
      const gated = await streamRewriteAfterFailedGate(res, anthropic, reply, firstPass.validation, judgmentPack, model);
      res.write(JSON.stringify({ done: true, stopReason: "end_turn", gate: gateSignal(gated.gate) }) + "\n");
    }
  } catch (err) {
    console.error(err);
    res.write(JSON.stringify({ error: `리딩 생성 중 오류: ${describeError(err)}` }) + "\n");
  } finally {
    clearInterval(heartbeat);
  }
  res.end();
}

/**
 * 깊은 리딩(사주·통합, 판단게이트 없는 경로)용 내용 자가교정 게이트.
 * streamMessages처럼 스트리밍한 뒤, 내용 검증(단정 예언 등 error)에 걸리면 1회 교정 호출로 고쳐
 * {replace:true}로 교체한다. 위반이 없으면(대부분) 추가 호출 없이 그대로 끝낸다.
 * (라이트 판단게이트 streamJudgmentGatedReply의 내용판 미러.)
 */
async function streamContentGatedReply(
  res: VercelResponse,
  anthropic: Anthropic,
  messages: Anthropic.Messages.MessageParam[],
  meta: Record<string, unknown> | undefined,
  evidenceUserMessage: string,
  model: string = MODEL,
): Promise<void> {
  res.status(200);
  res.setHeader("Content-Type", "application/x-ndjson; charset=utf-8");
  res.setHeader("Cache-Control", "no-cache, no-transform");
  res.setHeader("X-Accel-Buffering", "no");
  if (meta) res.write(JSON.stringify({ meta }) + "\n");

  const heartbeat = setInterval(() => {
    try {
      res.write(JSON.stringify({ heartbeat: true }) + "\n");
    } catch {
      // 이미 닫힌 연결
    }
  }, 10000);

  try {
    let reply = "";
    const stream = anthropic.messages.stream({
      model,
      max_tokens: MAX_TOKENS_STREAM,
      system: [{ type: "text", text: READING_SYSTEM_PROMPT, cache_control: { type: "ephemeral" } }],
      messages,
    });
    let stopReason: string | null = null;
    for await (const event of stream) {
      if (event.type === "content_block_delta" && event.delta.type === "text_delta") {
        reply += event.delta.text;
        res.write(JSON.stringify({ text: event.delta.text }) + "\n");
      } else if (event.type === "message_delta" && event.delta.stop_reason) {
        stopReason = event.delta.stop_reason;
      }
    }

    // 이어쓰기가 필요한(max_tokens로 잘린) 응답은 아직 미완성이라 교정하지 않고 그대로 넘긴다.
    const issues = stopReason === "max_tokens" ? [] : validateReadingContent(reply);
    if (!contentNeedsRewrite(issues)) {
      res.write(JSON.stringify({ done: true, stopReason, contentGate: { status: "pass", codes: issues.map((i) => i.code) } }) + "\n");
    } else {
      // 재작성도 completeMessages(블로킹) 대신 스트리밍해서, 걸리는 드문 경우에도 화면이 멈추지 않게 한다.
      const rewritePrompt = buildContentRewritePrompt({ originalReply: reply, issues, evidenceUserMessage });
      res.write(JSON.stringify({ text: "", replace: true }) + "\n");
      let corrected = "";
      const rewriteStream = anthropic.messages.stream({
        model,
        max_tokens: MAX_TOKENS_STREAM,
        system: [{ type: "text", text: READING_SYSTEM_PROMPT, cache_control: { type: "ephemeral" } }],
        messages: [{ role: "user", content: rewritePrompt }],
      });
      for await (const event of rewriteStream) {
        if (event.type === "content_block_delta" && event.delta.type === "text_delta") {
          corrected += event.delta.text;
          res.write(JSON.stringify({ text: event.delta.text }) + "\n");
        }
      }
      const remaining = validateReadingContent(corrected);
      res.write(
        JSON.stringify({
          done: true,
          stopReason: "end_turn",
          contentGate: { status: contentNeedsRewrite(remaining) ? "rewrite-partial" : "rewrite", codes: issues.map((i) => i.code) },
        }) + "\n",
      );
    }
  } catch (err) {
    console.error(err);
    res.write(JSON.stringify({ error: `리딩 생성 중 오류: ${describeError(err)}` }) + "\n");
  } finally {
    clearInterval(heartbeat);
  }
  res.end();
}

export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (req.method !== "POST") {
    res.status(405).json({ error: "POST 요청만 지원합니다." });
    return;
  }

  // P0: API 남용 방어 (Origin 검증 + 본문 크기 + rate limit).
  const verdict = await checkSecurity(req);
  if (!verdict.ok) {
    for (const [k, v] of Object.entries(verdict.headers ?? {})) res.setHeader(k, v);
    res.status(verdict.status ?? 403).json({ error: verdict.message });
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
  // A/B·측정용 요청별 모델(허용목록만, 없으면 기본 MODEL). 이 요청의 모든 생성/재작성이 같은 모델을 쓴다.
  let model = resolveModel(req.body);

  // 이어쓰기(continue): 앞선 응답이 토큰 상한/네트워크 절단으로 잘렸을 때, 지금까지 받은 본문을
  // 사용자 메시지에 합쳐 "반복 없이 이어서" 쓰게 한다. 일부 Claude 모델은 assistant 프리필을
  // 지원하지 않으므로 대화는 항상 user 메시지로 끝나게 유지한다.
  const continueFromRaw = (req.body as { continueFrom?: unknown }).continueFrom;
  const continueFrom = typeof continueFromRaw === "string" ? continueFromRaw.trimEnd() : "";

  try {
    if (body.type === "followup") {
      if (!body.history || body.history.length === 0) {
        res.status(400).json({ error: "history가 필요합니다." });
        return;
      }
      const mode = body.followUpMode ?? "concise";
      const history = mode === "concise" ? withConciseFollowUpInstruction(body.history) : body.history;
      const messages = withContinuation(
        history.map((m) => ({ role: m.role, content: m.content })),
        continueFrom,
      );
      if (streaming) {
        await streamMessages(res, anthropic, messages, undefined, { model, ...(mode === "concise" ? { maxTokens: 2200 } : {}) });
      } else {
        res.status(200).json({
          reply: await completeMessages(anthropic, messages, { model, ...(mode === "concise" ? { maxTokens: 2200 } : {}) }),
        });
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
        await streamMessages(res, anthropic, messages, undefined, { model });
      } else {
        res.status(200).json({ reply: await completeMessages(anthropic, messages, { model }) });
      }
      return;
    }

    const { type, question, focus, context, sectionGroup, gender, sajuChart, luckCycles, tarotCards, spreadNote, pastValidation, crossValidation } = body;

    // 토픽 심화(topicDeep, 재기획안 §6): 원가 통제를 클라이언트가 보낸 body.model에 맡기지 않고
    // 서버에서 강제한다. 판단(정확성)은 JudgmentPack이 이미 담보하므로 문장화는 Haiku로 충분하다.
    if (context?.analysisMode === "topicDeep") model = MODEL_ALLOWLIST.haiku;

    if ((type === "saju" || type === "combo" || type === "today" || type === "flow") && !sajuChart) {
      res.status(400).json({ error: "sajuChart(계산 결과)가 필요합니다." });
      return;
    }
    if ((type === "tarot" || type === "combo") && (!tarotCards || tarotCards.length === 0)) {
      res.status(400).json({ error: "tarotCards가 필요합니다." });
      return;
    }

    // 사용자 자유입력은 상한 길이로 절삭한다(과도한 토큰 소모·인젝션 완화). 계산값은 손대지 않는다.
    const safeContext = context
      ? {
          ...context,
          concernArea: clampText(context.concernArea, MAX_CONTEXT_FIELD_LEN) ?? context.concernArea,
          optionsText: clampText(context.optionsText, MAX_CONTEXT_FIELD_LEN) ?? context.optionsText,
          recentContext: clampText(context.recentContext, MAX_CONTEXT_FIELD_LEN) ?? context.recentContext,
          fearPoint: clampText(context.fearPoint, MAX_CONTEXT_FIELD_LEN) ?? context.fearPoint,
          styleHint: clampText(context.styleHint, MAX_CONTEXT_FIELD_LEN) ?? context.styleHint,
          selfCheck: context.selfCheck
            ? {
                recentThought: clampText(context.selfCheck.recentThought, MAX_CONTEXT_FIELD_LEN) ?? context.selfCheck.recentThought,
                procrastinating: clampText(context.selfCheck.procrastinating, MAX_CONTEXT_FIELD_LEN) ?? context.selfCheck.procrastinating,
                angerStyle: clampText(context.selfCheck.angerStyle, MAX_CONTEXT_FIELD_LEN) ?? context.selfCheck.angerStyle,
                hurtStyle: clampText(context.selfCheck.hurtStyle, MAX_CONTEXT_FIELD_LEN) ?? context.selfCheck.hurtStyle,
                moneyFeeling: clampText(context.selfCheck.moneyFeeling, MAX_CONTEXT_FIELD_LEN) ?? context.selfCheck.moneyFeeling,
                tiredStyle: clampText(context.selfCheck.tiredStyle, MAX_CONTEXT_FIELD_LEN) ?? context.selfCheck.tiredStyle,
              }
            : context.selfCheck,
          partnerCheck: context.partnerCheck
            ? {
                whoContacts: clampText(context.partnerCheck.whoContacts, MAX_CONTEXT_FIELD_LEN) ?? context.partnerCheck.whoContacts,
                onlineOfflineGap: clampText(context.partnerCheck.onlineOfflineGap, MAX_CONTEXT_FIELD_LEN) ?? context.partnerCheck.onlineOfflineGap,
                makesPlans: clampText(context.partnerCheck.makesPlans, MAX_CONTEXT_FIELD_LEN) ?? context.partnerCheck.makesPlans,
                wordsMatchActions: clampText(context.partnerCheck.wordsMatchActions, MAX_CONTEXT_FIELD_LEN) ?? context.partnerCheck.wordsMatchActions,
                publicness: clampText(context.partnerCheck.publicness, MAX_CONTEXT_FIELD_LEN) ?? context.partnerCheck.publicness,
                knownDuration: clampText(context.partnerCheck.knownDuration, MAX_CONTEXT_FIELD_LEN) ?? context.partnerCheck.knownDuration,
                recentMood: clampText(context.partnerCheck.recentMood, MAX_CONTEXT_FIELD_LEN) ?? context.partnerCheck.recentMood,
              }
            : context.partnerCheck,
          // 상대 완전분석 근거 블록(클라이언트 조립). 여러 블록이라 개별 필드보다 크게 잡되 상한은 둔다.
          counterpart: clampText(context.counterpart, 8000) ?? context.counterpart,
        }
      : context;

    const readingFacts = {
      type,
      question: clampText(question, MAX_QUESTION_LEN) ?? question,
      focus,
      context: safeContext,
      sectionGroup,
      gender,
      sajuChart,
      luckCycles,
      tarotCards,
      spreadNote,
      pastValidation,
      crossValidation,
    };
    const judgmentPack = buildReadingJudgmentPack(readingFacts);
    const userMessage = buildReadingUserMessage(readingFacts, judgmentPack);
    // 병렬 생성용 sectionGroup 지시는 Claude 호출에만 쓰고, 세션/후속질문 히스토리에는 남기지 않는다.
    const metaUserMessage = sectionGroup
      ? buildReadingUserMessage({ ...readingFacts, sectionGroup: undefined }, buildReadingJudgmentPack({ ...readingFacts, sectionGroup: undefined }))
      : userMessage;

    const messages = withContinuation([{ role: "user", content: userMessage }], continueFrom);
    // 이어쓰기 호출에는 계산 메타(meta)를 다시 실어 보내지 않는다 (이미 첫 호출에서 전달됨).
    const meta = continueFrom ? undefined : { userMessage: metaUserMessage, sajuChart, luckCycles, judgmentPack };
    if (streaming) {
      if (judgmentPack && !continueFrom) {
        await streamJudgmentGatedReply(res, anthropic, messages, meta, judgmentPack, model);
      } else if (!continueFrom && (type === "saju" || type === "combo")) {
        // 깊은 사주·통합 리딩: 판단게이트가 없는 경로라 내용 자가교정 게이트를 적용한다.
        await streamContentGatedReply(res, anthropic, messages, meta, userMessage, model);
      } else {
        await streamMessages(res, anthropic, messages, meta, { model });
      }
    } else {
      if (judgmentPack && !continueFrom) {
        const gated = await completeJudgmentGatedReply(anthropic, messages, judgmentPack, model);
        res.status(200).json({ reply: gated.reply, userMessage, sajuChart, luckCycles, judgmentPack: gated.judgmentPack, gate: gateSignal(gated.gate) });
      } else {
        const reply = await completeMessages(anthropic, messages, { model });
        res.status(200).json({ reply, userMessage, sajuChart, luckCycles, judgmentPack });
      }
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

function withConciseFollowUpInstruction(history: ChatMessage[]): ChatMessage[] {
  const lastUserIndex = history.map((m) => m.role).lastIndexOf("user");
  if (lastUserIndex < 0) return history;
  return history.map((m, index) => {
    if (index !== lastUserIndex) return m;
    return {
      ...m,
      content: [
        "[후속 질문 답변 방식]",
        "이번 답변은 전체 리딩을 새로 쓰지 말고, 사용자가 방금 물은 질문에만 직접 답해라.",
        "분량은 공백 포함 900~1400자 안팎으로 제한한다.",
        "출력 구조:",
        "1. 바로 답변 — 핵심 판단을 2~4문장으로 분명히 말한다.",
        "2. 사주/타로상 근거 — 기존 리딩과 계산 근거에서 확인되는 것만 2~3개로 요약한다.",
        "3. 현실에서 보이는 모습 — 사용자가 생활에서 알아볼 수 있는 예시 2~3개.",
        "4. 지금 할 수 있는 행동 — 오늘/이번 주에 할 행동 1~3개.",
        "5. 더 깊게 볼까요? — 더 깊은 분석이 필요하면 어떤 주제로 물으면 좋은지 한 줄로 안내한다.",
        "전문 용어는 본문에 그대로 던지지 말고 쉬운 말로 번역하되, 꼭 필요한 용어는 괄호로 짧게만 붙인다.",
        "결혼·이별·퇴사·투자·질병처럼 위험한 판단은 단정하지 말고 선택 기준으로 답한다.",
        "",
        `[사용자 후속 질문] ${m.content}`,
      ].join("\n"),
    };
  });
}

function extractText(response: Anthropic.Messages.Message): string {
  return response.content
    .filter((block): block is Anthropic.Messages.TextBlock => block.type === "text")
    .map((block) => block.text)
    .join("\n");
}
