import Anthropic from "@anthropic-ai/sdk";
import { randomUUID } from "node:crypto";
import type { ChatTurn } from "./storeTypes.js";
import { buildNatalEvidence, buildTodayEvidence, buildFlowEvidence, type ChartSource } from "./evidence.js";
import { emitPartial, finalizeStream, hasStreamStarted, resetStreamBuffer } from "./streamToTelegram.js";
import { logError, logRequest } from "./logSafe.js";
import { detectUngroundedSajuClaims, formatGroundingWarning } from "../src/lib/factGrounding.js";
import { shouldUseChatModel } from "./chatModelPolicy.js";
import { isTransientApiError, retryBackoffMs, MAX_STREAM_ATTEMPTS } from "./retryPolicy.js";

const sleep = (ms: number): Promise<void> => new Promise((resolve) => setTimeout(resolve, ms));

// BOT_MODEL 환경변수로 교체 가능. 기본은 비용 대비 해석 품질이 좋은 Sonnet 5.
// (더 깊게: BOT_MODEL=claude-opus-4-8 / 더 싸게: claude-haiku-4-5. Fable 5는
//  thinking:{type:"disabled"}를 거부하므로 아래 thinking 처리와 호환되지 않는다.)
const MODEL = process.env.BOT_MODEL ?? "claude-sonnet-5";

// 순수 잡담(generalChat)은 값싼 모델로 태워 비용을 아낀다. 사주/타로 해석은 MODEL 그대로.
// BOT_CHAT_MODEL로 교체 가능(같은 값으로 두면 분리 해제).
const CHAT_MODEL = process.env.BOT_CHAT_MODEL ?? "claude-haiku-4-5-20251001";

/**
 * teacher 경로에서 이 질문에 쓸 모델을 고른다.
 * generalChat(순수 잡담)이고 사주 용어가 없으면 값싼 CHAT_MODEL, 그 외엔 기본 MODEL.
 * 판단부는 chatModelPolicy.ts(순수)에 있다.
 */
export function pickTeacherModel(intent: string, question: string): string {
  return shouldUseChatModel(intent, question) ? CHAT_MODEL : MODEL;
}
// BOT_VERBOSITY로 답변 길이 상한 제어. 기본은 채팅답게 짧게(normal).
// 텔레그램은 수다처럼 짧게 티키타카가 원칙이라 상한을 낮게 둔다. detailed만 깊은 설명용.
const BOT_VERBOSITY = (process.env.BOT_VERBOSITY ?? "normal") as "brief" | "normal" | "detailed";
// (선택) 온도 오버라이드. 미설정 시 SDK 기본값 사용.
const BOT_TEMPERATURE = process.env.BOT_TEMPERATURE ? Number(process.env.BOT_TEMPERATURE) : undefined;
// LLM 스트림 상한(ms). Vercel 웹훅 maxDuration(300s)보다 훨씬 짧게 잡아, 스트림이 멈춰도
// 함수가 5분 통째로 매달렸다 죽는 것(FUNCTION_INVOCATION_TIMEOUT → 텔레그램 무한 재시도)을 막는다.
const BOT_STREAM_TIMEOUT_MS = Number(process.env.BOT_STREAM_TIMEOUT_MS ?? "120000") || 120000;
const VERBOSITY_TOKENS = {
  brief: 900,
  normal: 1800,
  detailed: 6000,
} as const;
type Verbosity = "brief" | "normal" | "detailed";

if (!process.env.ANTHROPIC_API_KEY) {
  console.error("ANTHROPIC_API_KEY 환경변수가 필요합니다. console.anthropic.com 에서 발급하세요.");
  process.exit(1);
}
// 클라이언트 레벨 타임아웃도 백업으로 건다(스트림은 AbortSignal이 1차 방어). 재시도는 1회로
// 줄여, 실패 시 재시도 지연이 Vercel maxDuration까지 쌓이지 않게 한다.
const client = new Anthropic({ timeout: BOT_STREAM_TIMEOUT_MS + 30_000, maxRetries: 1 }); // ANTHROPIC_API_KEY 환경변수 사용

// 사주 선생님의 전체 시스템 프롬프트. 길이 지시는 verbosity에 따라 달라진다.
// 핵심: 텔레그램 채팅이니 짧게 티키타카. 안 물어본 걸 먼저 갖다붙이지 않는다.
const buildTeacherSystem = (verbosity: Verbosity = "normal"): string => {
  const lengthRule =
    verbosity === "detailed"
      ? "- 지금은 사용자가 *자세히* 원합니다. 기초 원리부터 차근차근, 길고 깊게 설명해도 됩니다."
      : verbosity === "brief"
        ? "- 지금은 *아주 짧게*. 한두 문장으로 끝내세요. 군더더기 금지."
        : "- 기본은 짧게. 2~4문장으로 핵심만. 물어본 것만 답하고 멈추세요.";

  return `당신은 사주를 아주 잘 보는 사람인데, 지금은 텔레그램에서 친한 친구랑 톡하듯 수다 떠는 중입니다. 문자 주고받듯, 짧고 자연스럽게. 상담사 말투나 리포트 톤이 아니라 그냥 아는 사람이랑 얘기하는 느낌으로.

[제일 중요 — 진짜 사람처럼]
${lengthRule}
- 상대 말투에 맞추세요. 반말로 오면 반말, 존댓말로 오면 존댓말. 기본은 편한 반말~해요체.
- 사용자를 부를 땐 반드시 *"선생님"*이라고 호칭하세요. "누나·오빠·형·언니·님" 같은 호칭이나 성별을 추측한 호칭은 절대 쓰지 마세요.
- 먼저 상대 말에 짧게 반응(맞장구·공감·"오 그건~")하고 이어가세요. 인사엔 인사로, 농담엔 농담으로. 곧장 사주 분석부터 들이대지 마세요.
- 물어본 것 딱 그것만. 안 물어본 사주 얘기(대운·격국·신살·오늘 운세 등)를 스스로 줄줄이 붙이지 마세요. 한 답에 개념 하나면 충분.
- 결론→근거→현실→조언 같은 정해진 틀, 소제목, 번호 목록으로 각 잡지 마세요. 그냥 말로 풀어서 대화하세요.
- "왜/자세히/더 설명"처럼 깊이 요청할 때만 길게. 그 전엔 짧게.

[말귀 알아듣기 — 맥락과 의도]
- 지금까지 대화를 반드시 읽고 이어가세요. 방금 한 얘기를 처음 듣는 척하거나 앞 맥락을 무시하지 마세요. 이미 푼 용어를 또 풀지 마세요.
- 짧은 후속("그럼? 왜? 그건?")은 직전 얘기를 이어가는 거예요. 되묻지 말고 자연스럽게 이어 답하세요.
- 잡담이면 잡담으로, 이론 질문이면 이론으로, 자기 사주 질문이면 데이터로. *모든 말을 "네 사주가 어쩌구"로 끌고 가지 마세요.*
- 오늘 일진/운세는 "오늘·일진·지금 어때"처럼 직접 물었을 때만. 안 물으면 먼저 붙이지 마세요.

[근거 — 지어내지 않기]
- 첨부된 [원국 계산 데이터] 등은 프로그램이 만세력으로 정확히 계산한 값입니다. 사주 해석은 이 데이터 안의 값만 근거로 하세요. 없는 간지·신살·운을 지어내지 마세요.
- 데이터로 확인 안 되는 걸 물으면 "그건 계산에 안 잡혀서 단정 못 하겠다"고 솔직히 말하세요.
- 출생 시간을 모르는 사주(시주 없음)면 시간 관련(시주) 얘긴 하지 말고 그 한계를 짧게 언급하세요.
- 사주 등록 전이면 개인 데이터가 없다는 뜻. 일반 이론 질문("지장간이 뭐야")엔 그냥 아는 지식으로 답하고, 개인 사주가 있어야 답할 질문("내 신강신약은?")이면 짧게 생년월일시 등록을 권하세요.
- 사용자가 말 안 한 개인사(직업·연애 상태·특정 사건)를 아는 척 단정하거나 맞히려 하지 마세요. 근거는 계산 데이터와 사용자가 실제로 한 말뿐입니다.
- [궁합 계산 데이터]가 붙으면 점수만 읊지 말고 두 사람 일간·지지 합충·일지(배우자궁)를 짚어 잘 맞는 점/부딪히는 점을 나눠 풀되, 좋다/나쁘다로 단정하진 마세요.

[말투·안전]
- *항상 한국어로 답하세요.* 사용자가 다른 언어로 물어도 한국어로 답합니다.
- 쉬운 일상말로. 사주 용어는 꼭 필요할 때만, 쓰면 그 자리서 한마디로 풀어주세요.
- 겁주는 말·단정적 예언("반드시 ~된다")·운명론 금지. 불확실한 건 "~할 수도 있어" 정도로.
- 건강은 컨디션·생활 리듬까지만(질병 진단 금지). 결혼·이혼·퇴사·투자 같은 큰 결정은 단정하지 말고 판단 기준만 주세요.
- 유파에 따라 갈리는 판정(신강신약·격국·용신)이나 시주 불명 같은 한계는 얼버무리지 말고 그대로 밝히세요.
- 텔레그램이라 표·소제목·번호 목록·긴 서식 없이 짧은 문장으로, 말하듯이. 굵게는 *별표* 한 쌍만, 정말 필요할 때만.`;
};

export interface AskOptions {
  source: ChartSource | null;
  history: ChatTurn[];
  question: string;
  chatId?: number; // 스트리밍용 (웹훅 모드)
  verbosityOverride?: "brief" | "normal" | "detailed"; // 자연어 힌트에서 추출됨
  /** astrologyReading/combinedReading일 때만 첨부하는 점성술 근거 텍스트 블록 */
  astrologyEvidence?: string;
  /** 이 답변에 쓸 모델(생략 시 기본 MODEL). 잡담은 pickTeacherModel로 값싼 모델을 넘긴다. */
  modelOverride?: string;
}

/**
 * 오늘 일진 데이터를 이 질문에 붙일지 판단한다.
 * 사용자가 "오늘/일진/지금" 등을 직접 물었을 때만 붙인다 — 안 그러면 봇이 매 답변마다
 * 오늘의 운세를 억지로 갖다붙이게 된다(사용자 불만의 핵심).
 */
function questionAsksAboutToday(question: string): boolean {
  return /오늘|일진|지금\s*(어때|어떄|운|흐름|뭐)|오늘의|하루\s*운/.test(question);
}

/**
 * 올해 월별 흐름 데이터를 이 질문에 붙일지 판단한다.
 * 흐름·월운·올해·몇 월 등을 물을 때만 붙여, 평소 대화엔 큰 월별 배열을 싣지 않는다.
 */
function questionAsksAboutFlow(question: string): boolean {
  return /흐름|올해|한\s*해|월별|달별|몇\s*월|[1-9]\s*월|이번\s*달|다음\s*달|상반기|하반기|월운|연운|세운/.test(question);
}

/** 계산 근거 + 대화 맥락을 실어 Claude에게 해석을 요청한다 */
export async function askTeacher({ source, history, question, chatId, verbosityOverride, astrologyEvidence, modelOverride }: AskOptions): Promise<string> {
  const historyMessages = history.map((t) => ({ role: t.role, content: t.content }) as Anthropic.Messages.MessageParam);

  // 오늘 일진은 사용자가 오늘을 직접 물었을 때만 첨부한다(평소엔 원국 데이터만).
  const evidenceBlocks: string[] = [];
  if (source && questionAsksAboutToday(question)) evidenceBlocks.push(buildTodayEvidence(source));
  if (source && questionAsksAboutFlow(question)) evidenceBlocks.push(buildFlowEvidence(source));
  if (astrologyEvidence) evidenceBlocks.push(astrologyEvidence);
  const finalUserContent = evidenceBlocks.length > 0 ? `${evidenceBlocks.join("\n\n")}\n\n[질문]\n${question}` : `[질문]\n${question}`;

  const natalEvidence = source ? buildNatalEvidence(source) : null;
  // 근거 점검용 텍스트: 원국 + 이번 턴에 첨부된 추가 근거(오늘 일진 등).
  // 일진 간지처럼 이번 턴 근거에만 있는 값이 오탐되지 않도록 합쳐서 넘긴다.
  const groundingEvidence = natalEvidence ? [natalEvidence, ...evidenceBlocks].join("\n\n") : undefined;

  const messages: Anthropic.Messages.MessageParam[] = source
    ? [
        {
          role: "user",
          // 원국·운 계산 데이터는 대화 내내 고정이라 프롬프트 캐시에 태운다.
          // 같은 사람과 이어지는 턴에서는 이 큰 JSON을 원가로 재전송하지 않고 캐시에서 읽어 토큰값을 아낀다.
          content: [
            {
              type: "text",
              text: `${natalEvidence}\n\n위 데이터가 이 대화 전체에서 해석의 근거가 되는 내 사주입니다. 사용자가 실제로 물어본 것에만 답하고, 안 물어본 항목(오늘 운세·대운 등)은 먼저 꺼내지 마세요.`,
              cache_control: { type: "ephemeral", ttl: "1h" },
            },
          ],
        },
        { role: "assistant", content: "네, 데이터 확인했어요. 물어보는 것만 짧게 답할게요. 뭐가 궁금해요?" },
        ...historyMessages,
        {
          role: "user",
          content: finalUserContent,
        },
      ]
    : [
        {
          role: "user",
          content:
            "아직 제 생년월일시를 등록하지 않았습니다. 개인 사주 데이터 없이도 답할 수 있는 명리학 일반 이론 질문에는 알고 있는 지식으로 답해주시고, 제 사주가 있어야만 답할 수 있는 질문이 오면 먼저 생년월일시를 등록해달라고 자연스럽게 안내해주세요.",
        },
        {
          role: "assistant",
          content: "알겠습니다. 사주 등록 전이니 일반 이론 질문은 바로 답하고, 개인 차트가 필요한 질문이면 등록을 안내할게요. 무엇이 궁금하신가요?",
        },
        ...historyMessages,
        { role: "user", content: question },
      ];

  return runStream(messages, chatId, verbosityOverride, "teacher", undefined, groundingEvidence, modelOverride);
}

/**
 * 공통 스트리밍 호출. askTeacher·askCompatibility가 함께 쓴다.
 *
 * chatId가 주어지면: 생성되는 대로 텍스트를 Telegram에 실시간 반영하고, 끝나면 최종본을
 * 확정 표시한다(finalizeStream). 이 경우 답을 이미 화면에 띄웠으니, 호출부는 반환값을
 * "다시 전송"하면 안 되고 히스토리 저장에만 쓴다.
 * chatId가 없으면: 화면 표시 없이 최종 텍스트만 반환한다(호출부가 직접 sendMessage).
 */
export async function runStream(
  messages: Anthropic.Messages.MessageParam[],
  chatId?: number,
  verbosityOverride?: "brief" | "normal" | "detailed",
  mode = "teacher",
  systemPromptOverride?: string,
  /**
   * 계산 근거 직렬화 텍스트 (buildNatalEvidence 출력 등). 주어지면 최종 답변에서
   * 근거에 없는 사주 사실 주장(신살·간지·십성·격국)을 감지해 경고 꼬리를 붙인다.
   * 차단이 아니라 표시다 — 공부용 대화에서 할루시네이션을 사용자가 알아채게 한다.
   */
  groundingEvidence?: string,
  /** 이 호출에 쓸 모델(생략 시 기본 MODEL). 잡담은 값싼 CHAT_MODEL을 넘긴다. */
  modelOverride?: string,
): Promise<string> {
  const level = verbosityOverride ?? BOT_VERBOSITY;
  const maxTokens = VERBOSITY_TOKENS[level];
  const systemPrompt = systemPromptOverride ?? buildTeacherSystem(level);
  const model = modelOverride ?? MODEL;
  // 전역 crypto는 Node 런타임/버전에 따라 없을 수 있어(예: Railway Node 18) node:crypto에서 직접 가져온다.
  const requestId = randomUUID();
  const startedAt = Date.now();

  // 짧은 채팅 답변엔 확장 사고를 끄고 바로 답하게 해 속도·비용을 아낀다.
  // 깊은 설명(detailed)일 때만 adaptive thinking을 켠다.
  // 주의: Sonnet 5·Opus 4.8 등은 thinking을 '생략'하면 adaptive가 켜지므로(비용↑),
  // 짧은 답에서는 명시적으로 disabled로 꺼야 한다.
  // haiku(구형)는 disabled/adaptive 파라미터를 안전하게 안 받을 수 있어 thinking을 생략한다
  // (생략 시 사고 없음 — 잡담엔 그게 맞다). Fable 5도 disabled를 거부하므로 여기서 제외된다.
  const supportsThinkingToggle = /sonnet|opus/.test(model);
  const thinkingEnabled = supportsThinkingToggle && level === "detailed";
  const thinkingParam = supportsThinkingToggle
    ? { thinking: (thinkingEnabled ? { type: "adaptive" as const } : { type: "disabled" as const }) }
    : {};
  // thinking이 켜지면 Anthropic API는 temperature≠1을 거부한다(400). 확장 사고가 켜진
  // 요청에는 온도를 실어 보내지 않아, BOT_TEMPERATURE 설정 시 detailed 답변이 매번 실패하던 걸 막는다.
  const temperatureParam = BOT_TEMPERATURE !== undefined && !thinkingEnabled ? { temperature: BOT_TEMPERATURE } : {};
  const requestParams = {
    model,
    max_tokens: maxTokens,
    ...temperatureParam,
    ...thinkingParam,
    system: [{ type: "text" as const, text: systemPrompt, cache_control: { type: "ephemeral" as const, ttl: "1h" as const } }],
    messages,
  };

  // 스트림 소비. 성공하면 최종 메시지를 반환, 실패하면 던진다.
  // 아무 텍스트도 화면에 안 나온 초기 실패(429/529 과부하 등)에 한해 바깥 루프가 재시도한다.
  const consumeStream = async (): Promise<Anthropic.Messages.Message> => {
    const stream = client.messages.stream(requestParams, { signal: AbortSignal.timeout(BOT_STREAM_TIMEOUT_MS) });
    let streamedText = "";
    // 토큰이 도착하는 대로 누적하고, chatId가 있으면 그때그때 화면에 반영한다.
    for await (const event of stream) {
      if (event.type === "content_block_delta" && event.delta.type === "text_delta") {
        streamedText += event.delta.text;
        if (chatId) await emitPartial(chatId, streamedText);
      }
    }
    return stream.finalMessage();
  };

  let final: Anthropic.Messages.Message;
  let attempt = 0;
  // 초기 실패(텍스트가 아직 안 나온 상태)의 일시적 오류만 재시도한다. 이미 스트리밍이 시작됐거나
  // 우리가 건 타임아웃(시간을 다 씀)은 재시도하지 않는다 — Vercel maxDuration 초과·중복 표시 방지.
  while (true) {
    attempt++;
    try {
      // 재시도 시 화면 표시가 진행 중이었을 수 있어 버퍼를 정리하고 새로 시작한다.
      if (attempt > 1 && chatId) resetStreamBuffer(chatId);
      final = await consumeStream();
      break;
    } catch (err) {
      const aborted = (err as { name?: string })?.name === "TimeoutError" || (err as { name?: string })?.name === "AbortError";
      const alreadyShown = chatId != null && hasStreamStarted(chatId);
      // 텍스트가 아직 안 나왔고, 일시적 오류이고, 시도 여유가 있으면 잠깐 쉬고 재시도.
      if (!aborted && !alreadyShown && isTransientApiError(err) && attempt < MAX_STREAM_ATTEMPTS) {
        logRequest({ requestId, mode: `${mode}:retry`, latencyMs: Date.now() - startedAt, errorCode: "stream_transient_retry" });
        await sleep(retryBackoffMs(attempt));
        continue;
      }
      // 타임아웃(AbortSignal)·복구 불가 오류. 여기서 삼키지 않으면 웹훅 함수가 그대로 매달려
      // Vercel maxDuration(5분)까지 죽고 텔레그램이 같은 메시지를 무한 재시도한다(=먹통).
      // → 안내 메시지를 보내고 빠르게 반환해, 함수가 곧장 200을 돌려주게 한다.
      logError("teacher.runStream", err);
      logRequest({ requestId, mode, latencyMs: Date.now() - startedAt, errorCode: aborted ? "stream_timeout" : "stream_error" });
      const fallback = aborted
        ? "지금 답을 만드는 데 시간이 너무 걸려서 멈췄어요 😢 잠시 뒤 다시 물어봐 주세요. (짧게 물어보면 더 빨라요.)"
        : "지금 답을 만드는 데 문제가 생겼어요 😢 잠시 뒤 다시 물어봐 주세요.";
      if (chatId) {
        try {
          await finalizeStream(chatId, fallback);
        } catch (e) {
          logError("teacher.runStream.fallback", e);
        }
      }
      return fallback;
    }
  }

  const stopReason = final.stop_reason;
  const assembled = final.content
    .filter((b): b is Anthropic.Messages.TextBlock => b.type === "text")
    .map((b) => b.text)
    .join("\n")
    .trim();

  logRequest({
    requestId,
    mode,
    latencyMs: Date.now() - startedAt,
    tokenCount: (final.usage?.input_tokens ?? 0) + (final.usage?.output_tokens ?? 0),
  });

  // 최종 사용자에게 보일 텍스트 결정
  let result: string;
  if (stopReason === "refusal") {
    result = "죄송해요, 이 질문에는 답변이 제한되었어요. 다른 방식으로 물어봐 주시겠어요?";
  } else if (!assembled) {
    result = "답변을 만들지 못했어요. 다시 한번 물어봐 주세요.";
  } else if (stopReason === "max_tokens") {
    result = `${assembled}\n\n_(답이 길어져 여기서 끊겼어요. "계속" 또는 "이어서 설명해줘"라고 보내주세요.)_`;
  } else {
    result = assembled;
  }

  // 근거 점검: 계산 데이터에 없는 사주 사실 주장이 있으면 경고 꼬리를 붙인다.
  // 점검 실패가 답변 실패가 되면 안 되므로 통째로 try/catch.
  if (groundingEvidence && assembled) {
    try {
      const groundingHits = detectUngroundedSajuClaims(assembled, groundingEvidence);
      const warning = formatGroundingWarning(groundingHits);
      if (warning) {
        result = `${result}\n\n${warning}`;
        logRequest({ requestId, mode: `${mode}:grounding-warning`, latencyMs: 0, tokenCount: groundingHits.length });
      }
    } catch (err) {
      logError("teacher.groundingCheck", err);
    }
  }

  // 스트리밍 모드면 최종본을 여기서 확정 표시한다(호출부는 재전송하지 않음).
  if (chatId) {
    await finalizeStream(chatId, result);
  }
  return result;
}

// 타로 리딩 전용 시스템 프롬프트. 텔레그램 톤을 유지하되, 뽑힌 카드 근거에 충실하게 해석한다.
const TAROT_SYSTEM = `당신은 타로를 아주 깊게 읽는 사람인데, 지금은 텔레그램에서 편하게 채팅으로 리딩해주는 중입니다. 짧고 자연스럽게, 문자 주고받듯 대화하세요.

[근거 — 뽑힌 카드만]
- 첨부된 [타로 계산 데이터]의 카드가 이 리딩의 전부입니다. 프로그램이 실제로 뽑은 카드예요. 없는 카드·안 나온 상징을 지어내지 마세요.
- 각 카드는 반드시 *자리 의미*(positionLabel)와 *정/역방향*을 함께 읽으세요. 같은 카드라도 자리와 방향에 따라 뜻이 달라집니다.
- [원소 조합]·[타로 조합 진단](정역 비율·메이저 비율·반복 슈트·흐름 축)을 근거로 배열 전체의 결을 먼저 잡고, 개별 카드를 거기에 엮으세요. 카드를 하나씩 따로 읊고 끝내지 마세요.
- 스프레드에 '해석 지침'이 붙어 있으면 그 방식을 따르세요(예: 선택 비교는 A열/B열을 나란히).

[읽는 법 — 쉽게, 현실로]
- 카드 이름·상징을 나열만 하지 말고, 질문한 상황에서 그게 *현실에서 어떻게 나타나는지*로 번역하세요.
- 흐름 축(첫 카드→마지막 카드)으로 이야기를 이어 붙여, 지금 상황이 어디서 와서 어디로 가는지 한 줄기로 읽어주세요.
- 마지막엔 사용자가 오늘·이번 주에 실제로 해볼 수 있는 행동 1~2개로 마무리하세요.

[안전 — 단정 금지]
- 이별·재회·결혼·합격·죽음·질병 같은 걸 "된다/안 된다"로 단정하지 마세요. 카드는 확정된 미래가 아니라 지금 흐름이 비추는 경향입니다. "~쪽으로 기운다", "~할 여지가 보인다" 정도로.
- 겁주는 말·운명론 금지. '나쁜 카드'(탑·죽음·악마 등)도 무섭게 몰지 말고 '풀어야 할 과제'로 읽으세요. 역방향도 흉으로만 몰지 마세요.
- 건강은 컨디션·생활 리듬까지만. 큰 결정(퇴사·투자·이혼 등)은 단정 말고 판단 기준만.

[말투 — 친구가 카드 봐주듯]
- *항상 한국어로.* 점집 상담사 톤 말고, 친한 친구가 카드 펼쳐놓고 "오 이거 봐" 하며 얘기해 주는 느낌으로. 상대 말투에 맞춰(반말엔 반말, 존댓말엔 존댓말) 편하게.
- 사용자를 부를 땐 *"선생님"*이라고 호칭하세요. "누나·오빠·형·언니" 같은 호칭이나 성별 추측 호칭은 쓰지 마세요.
- 소제목·번호 목록·표로 각 잡지 말고 말로 풀어서. 텔레그램이라 짧은 문장, 굵게는 *별표* 한 쌍만.
- 기본은 카드 수에 맞게 적당히(한 장이면 짧게, 여러 장이면 흐름으로 엮어서). "자세히"라고 하면 그때 더 깊게.
- 후속 질문이면 이미 뽑은 카드를 새로 뽑은 척하지 말고, 그 카드들을 다시 근거로 이어서 답하세요. (사용자가 "다시 뽑아줘/한 장 더" 하면 그건 새로 뽑힌 카드가 첨부됩니다.)`;

export interface AskTarotOptions {
  /** buildTarotEvidenceText()가 만든 타로 근거 블록 */
  tarotEvidence: string;
  question: string;
  history: ChatTurn[];
  chatId?: number;
  verbosityOverride?: "brief" | "normal" | "detailed";
  /** 새로 뽑은 스프레드가 아니라 기존 카드에 대한 후속 질문이면 true */
  isFollowUp?: boolean;
}

/** 뽑힌 타로 카드 근거를 실어 리딩을 요청한다. teacher.ts의 runStream을 재사용한다. */
export async function askTarot({ tarotEvidence, question, history, chatId, verbosityOverride, isFollowUp }: AskTarotOptions): Promise<string> {
  const historyMessages = history.map((t) => ({ role: t.role, content: t.content }) as Anthropic.Messages.MessageParam);
  const framing = isFollowUp
    ? "위 카드는 방금 전에 이미 뽑아 리딩한 그 스프레드입니다. 새로 뽑지 말고, 이 카드들을 근거로 사용자의 이어지는 질문에 답하세요."
    : "위 카드가 이 타로 리딩의 근거입니다. 카드 하나하나를 따로 읊지 말고, 배열 전체의 흐름으로 엮어 풀어주세요.";

  const messages: Anthropic.Messages.MessageParam[] = [
    {
      role: "user",
      content: [
        {
          type: "text",
          text: `${tarotEvidence}\n\n${framing}`,
          cache_control: { type: "ephemeral" },
        },
      ],
    },
    { role: "assistant", content: "카드 확인했어요. 이 배열을 근거로 풀어드릴게요." },
    ...historyMessages,
    { role: "user", content: `[질문]\n${question || "이 카드 흐름을 풀어줘."}` },
  ];
  return runStream(messages, chatId, verbosityOverride, "tarot", TAROT_SYSTEM);
}

export interface AskCompatibilityOptions {
  compatEvidence: string;
  question?: string;
  chatId?: number; // 스트리밍용 (주어지면 답을 직접 화면에 표시)
}

/** 궁합 근거를 실어 두 사람 관계 해석을 요청한다. */
export async function askCompatibility({ compatEvidence, question, chatId }: AskCompatibilityOptions): Promise<string> {
  const ask = question?.trim()
    ? `[이 관계에 대해 특히 궁금한 것]\n${question.trim()}\n\n위 궁금증에 먼저 답하고, 이어서 관계 전반을 풀어주세요.`
    : "이 궁합을 풀어주세요. 두 사람이 왜 그렇게 맞물리는지, 어디서 잘 맞고 어디서 부딪히기 쉬운지, 그리고 관계를 편하게 가져가는 현실적인 방법까지 짚어주세요.";

  const messages: Anthropic.Messages.MessageParam[] = [
    {
      role: "user",
      content: `${compatEvidence}\n\n위 계산 데이터가 이 궁합 해석의 근거입니다. 점수 숫자를 그대로 읊지 말고, 왜 그렇게 나오는지 두 사람의 간지·오행·일지(배우자궁)를 짚어가며 설명하세요. 확실한 계산값은 확신 있게, 사람이 말해주지 않은 실제 상황은 넘겨짚지 말고요.`,
    },
    {
      role: "assistant",
      content: "두 사람의 원국과 궁합 계산 데이터를 확인했습니다. 이 근거로 관계를 풀어드릴게요.",
    },
    { role: "user", content: ask },
  ];
  return runStream(messages, chatId, undefined, "compatibility", undefined, compatEvidence);
}

// 학습모드 딥다이브 전용 시스템 프롬프트. teacher.ts의 다른 프롬프트("짧게, 대화하듯")와 정반대로,
// 여기서는 표·비유·사례 분기·자주 틀리는 포인트까지 담은 긴 강의체 해설을 의도적으로 허용한다.
// 압축 강의·문제 해설은 studyMode.ts에 하드코딩(토큰 0)돼 있고, 이 프롬프트는 사용자가
// "더 설명해줘"라고 직접 요청했을 때만 1회 호출된다.
const STUDY_EXPLAIN_SYSTEM = `당신은 명리학을 아주 깊게 아는 과외 선생님입니다. 학생이 방금 배운 개념 하나를 더 깊게 설명해달라고 요청했습니다. 지금은 짧은 채팅이 아니라 제대로 된 강의를 할 시간입니다.

[가장 중요 — 학생이 원하는 톤·난이도에 맞추기 (다른 모든 규칙보다 우선)]
- 학생의 요청 문장에 톤이나 난이도 지시가 있으면 *그것을 최우선*으로 따르세요. 아래 "기본 구조·형식"은 그 요청과 부딪히면 유연하게 바꾸세요. 구조를 지키느라 원하는 톤을 어기지 마세요.
- "초등학생도 이해하게", "완전 쉽게", "쉬운 말로" → 전문용어를 거의 쓰지 마세요. 꼭 필요하면 쓰자마자 아주 쉬운 말로 바꿔주세요. 짧은 문장, 친근한 말투, 일상 비유(나무·물·요리·게임·학교 등) 위주로. 표가 어렵게 느껴지면 표 대신 말로 풀어도 됩니다. 어려운 한자어 대신 또래가 쓰는 말로.
- "비유로만", "예시 많이" → 정의보다 비유·구체 예시를 앞세우세요.
- "존댓말로/반말로/친구처럼/재미있게" → 그 말투 그대로. 진지한 강의체를 고집하지 마세요.
- 톤 지시가 없으면 아래 기본 구조로 정중하고 친절하게.

[기본 구조 (톤 지시가 없을 때의 기본값)]
1. 먼저 한 문장으로 핵심을 요약하세요 (인용구처럼: > **~~는 ~~이다.**)
2. 이 개념과 헷갈리기 쉬운 개념이 있으면 짧게 대조하세요.
3. 필요하면 간단한 비교표를 넣으세요 (마크다운 표 형식. 텔레그램은 표가 예쁘게 안 그려지지만 줄맞춰 읽을 수는 있습니다).
4. 정의를 풀어 설명하고, 자연물 비유(나무·뿌리·씨앗·물·불 등)로 감을 잡아주세요.
5. 교재 사주(첨부된 [원국 계산 데이터])의 실제 글자로 구체적인 예시를 들어 적용해 보이세요. 지어내지 말고 데이터에 있는 값만 쓰세요.
6. 경우의 수가 있는 개념(예: 있음/없음 조합)이면 번호를 매겨 케이스를 나눠 설명하세요.
7. "자주 틀리는 포인트"를 ❌/✅ 형식으로 1~3개 짚어주세요.
8. 마지막에 실무에서 이 개념을 어떻게 같이 보는지(다른 개념과 묶어서 확인하는 팁) 한 문단으로 정리하세요.

[형식]
- 소제목은 *별표*로 굵게 표시하세요 (# 마크다운 헤더는 텔레그램에서 안 먹습니다).
- 표는 마크다운 파이프 형식 그대로 쓰세요. (단, 쉬운 톤 요청이면 표를 빼도 됩니다.)
- 줄바꿈을 적극적으로 써서 눈으로 훑기 쉽게 하세요. 한 문단이 5줄을 넘지 않게.
- 이모지는 남발하지 말되, 쉬운·재미있는 톤 요청이면 이해를 돕는 선에서 조금 써도 됩니다.
- 길게 써도 됩니다 — 지금은 "짧게 티키타카" 규칙이 적용되지 않습니다. 다만 근거 없는 내용을 채우려고 억지로 늘리지는 마세요. (쉬운 톤이면 오히려 짧고 명료하게.)

[근거 — 톤이 바뀌어도 이건 절대 안 바뀜]
- 첨부된 [원국 계산 데이터]는 프로그램이 만세력으로 정확히 계산한 교재용 고정 사주입니다. 예시를 들 때 이 데이터의 실제 값만 쓰고, 없는 글자·관계를 지어내지 마세요.
- 방금 배운 개념(장 제목·핵심 문장·기본 해설)이 [지금 배우는 개념]으로 첨부됩니다. 그 개념을 벗어나 다른 장 전체를 늘어놓지 말고, 이 개념 하나를 깊게 파세요.
- 명리학 이론은 유파에 따라 세부가 갈릴 수 있습니다. 확정된 계산값(간지·오행·십성 등)은 확신 있게, 해석이 갈리는 부분은 "유파에 따라 다르게 보기도 한다"고 솔직히 밝히세요.
- 반드시 한국어로 답하세요.`;

export interface AskStudyExplainOptions {
  /** 지금 배우는 개념: 장 제목 + 핵심 프롬프트/해설 (studyMode.ts의 deepExplainContext) */
  chapterTitle: string;
  concept: string;
  baseExplain: string;
  /** 교재 사주 근거 (buildNatalEvidence(pillarsSource(TEXTBOOK_PILLARS))) */
  textbookEvidence: string;
  question: string;
  chatId?: number;
}

/** 학습모드 "더 설명해줘" — 표·비유·사례분기까지 담은 긴 해설을 1회 호출로 생성한다. */
export async function askStudyExplain({ chapterTitle, concept, baseExplain, textbookEvidence, question, chatId }: AskStudyExplainOptions): Promise<string> {
  const messages: Anthropic.Messages.MessageParam[] = [
    {
      role: "user",
      content: [
        {
          type: "text",
          text: `${textbookEvidence}\n\n[지금 배우는 개념]\n장: ${chapterTitle}\n개념/문제: ${concept}\n기본 해설(이미 알려준 내용, 이걸 더 깊게 확장해야 함): ${baseExplain}`,
          cache_control: { type: "ephemeral" },
        },
      ],
    },
    { role: "assistant", content: "이 개념, 제대로 깊게 풀어드릴게요." },
    { role: "user", content: question || "이 개념 더 자세히 설명해줘." },
  ];
  // 학습 딥다이브에도 근거 점검(factGrounding)을 넘긴다: 교재 사주에 없는 간지·신살을
  // LLM이 지어내면 경고 꼬리가 붙는다(학습용이라 정확성 안전장치가 더 중요).
  return runStream(messages, chatId, "detailed", "study-explain", STUDY_EXPLAIN_SYSTEM, textbookEvidence);
}

export interface AskStudyLessonOptions {
  /** 재작성할 원문 강의(studyMode.ts의 하드코딩 압축 강의). 개념·사실의 출처다. */
  lesson: string;
  /** 사용자가 저장한 톤·난이도(StudyState.tone). 예: "초등학생도 알게 쉽게". */
  tone: string;
  /** 교재 사주 근거 (buildNatalEvidence(pillarsSource(TEXTBOOK_PILLARS))) */
  textbookEvidence: string;
  chatId?: number;
}

/**
 * 학습 톤 설정이 켜져 있을 때, 기본 압축 강의를 사용자가 원하는 톤·난이도로 다시 쓴다.
 * "쉬움 모드는 강의도 LLM로 생성"에 해당. 원문 강의의 개념·사실은 유지하고 말투·눈높이만 바꾼다.
 * 근거 점검(textbookEvidence)을 넘겨 없는 글자를 지어내면 경고가 붙게 한다.
 */
export async function askStudyLesson({ lesson, tone, textbookEvidence, chatId }: AskStudyLessonOptions): Promise<string> {
  const messages: Anthropic.Messages.MessageParam[] = [
    {
      role: "user",
      content: [
        {
          type: "text",
          text: `${textbookEvidence}\n\n[다시 써야 할 강의 원문]\n${lesson}`,
          cache_control: { type: "ephemeral" },
        },
      ],
    },
    { role: "assistant", content: "원하시는 톤으로 이 강의를 다시 써드릴게요." },
    {
      role: "user",
      content: `위 강의를 다음 톤·난이도로 자연스럽게 다시 설명해줘: "${tone}".\n- 개념과 사실(오행·관계·교재 사주 값)은 그대로 유지하고, 말투와 눈높이만 바꿔.\n- 교재 사주 예시는 첨부된 [원국 계산 데이터]의 실제 값만 써. 없는 글자·관계는 지어내지 마.\n- 강의 한 편이니 이 개념 하나만 다뤄. 다른 장으로 새지 마.`,
    },
  ];
  return runStream(messages, chatId, "detailed", "study-lesson", STUDY_EXPLAIN_SYSTEM, textbookEvidence);
}
