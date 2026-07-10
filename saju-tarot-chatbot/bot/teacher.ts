import Anthropic from "@anthropic-ai/sdk";
import type { ChatTurn } from "./storeTypes.js";
import { buildNatalEvidence, buildTodayEvidence, type ChartSource } from "./evidence.js";
import { emitPartial, finalizeStream } from "./streamToTelegram.js";
import { logError, logRequest } from "./logSafe.js";

// BOT_MODEL 환경변수로 교체 가능. 기본은 가장 깊은 해석 품질을 위해 Opus.
const MODEL = process.env.BOT_MODEL ?? "claude-opus-4-8";
// BOT_VERBOSITY로 답변 길이 상한 제어. 기본은 채팅답게 짧게(normal).
// 텔레그램은 수다처럼 짧게 티키타카가 원칙이라 상한을 낮게 둔다. detailed만 깊은 설명용.
const BOT_VERBOSITY = (process.env.BOT_VERBOSITY ?? "normal") as "brief" | "normal" | "detailed";
// (선택) 온도 오버라이드. 미설정 시 SDK 기본값 사용.
const BOT_TEMPERATURE = process.env.BOT_TEMPERATURE ? Number(process.env.BOT_TEMPERATURE) : undefined;
const VERBOSITY_TOKENS = {
  brief: 900,
  normal: 1800,
  detailed: 8000,
} as const;
type Verbosity = "brief" | "normal" | "detailed";

if (!process.env.ANTHROPIC_API_KEY) {
  console.error("ANTHROPIC_API_KEY 환경변수가 필요합니다. console.anthropic.com 에서 발급하세요.");
  process.exit(1);
}
const client = new Anthropic(); // ANTHROPIC_API_KEY 환경변수 사용

// 사주 선생님의 전체 시스템 프롬프트. 길이 지시는 verbosity에 따라 달라진다.
// 핵심: 텔레그램 채팅이니 짧게 티키타카. 안 물어본 걸 먼저 갖다붙이지 않는다.
const buildTeacherSystem = (verbosity: Verbosity = "normal"): string => {
  const lengthRule =
    verbosity === "detailed"
      ? "- 지금은 사용자가 *자세히* 원합니다. 기초 원리부터 차근차근, 길고 깊게 설명해도 됩니다."
      : verbosity === "brief"
        ? "- 지금은 *아주 짧게*. 한두 문장으로 끝내세요. 군더더기 금지."
        : "- 기본은 짧게. 2~4문장으로 핵심만. 물어본 것만 답하고 멈추세요.";

  return `당신은 사주를 아주 잘 보는 사람인데, 지금은 텔레그램에서 편한 반말 섞인 채팅으로 사용자랑 수다 떨듯 티키타카 하는 중입니다. 문자 주고받듯이, 짧고 자연스럽게 대화하세요.

[제일 중요 — 짧게, 물어본 것만]
${lengthRule}
- 사용자가 물은 것 딱 그것만 답하세요. 안 물어본 사주 얘기(대운·격국·신살·오늘 운세 등)를 스스로 줄줄이 갖다붙이지 마세요. 한 답변에 개념 하나면 충분합니다.
- "왜", "자세히", "더 설명" 처럼 사용자가 깊이 요청할 때만 길게 가세요. 그 전엔 무조건 짧게.
- 결론→근거→현실→조언 같은 정해진 틀을 기계적으로 채우지 마세요. 그냥 대화하세요.

[말귀 알아듣기 — 맥락과 의도]
- 지금까지의 대화를 반드시 읽고 이어가세요. 방금 나온 얘기를 처음 듣는 것처럼 굴거나, 앞 맥락을 무시하지 마세요. 이미 아는 용어는 다시 풀지 마세요.
- 사용자가 뭘 원하는지 먼저 파악하세요. 그냥 잡담이면 잡담으로 받아주고, 명리학 이론 질문이면 이론으로, 자기 사주 질문이면 사주 데이터로 답하세요.
- *모든 말을 "네 사주가 어쩌구"로 끌고 가지 마세요.* 사용자가 개인 사주를 안 물었으면 사주 해석을 억지로 시작하지 마세요.
- 오늘 일진/오늘의 운세는 사용자가 "오늘", "일진", "지금 어때" 처럼 직접 물었을 때만 꺼내세요. 안 물으면 절대 먼저 붙이지 마세요.

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
- 텔레그램이라 표·긴 서식 없이 짧은 문장으로. 굵게는 *별표* 한 쌍만.`;
};

export interface AskOptions {
  source: ChartSource | null;
  history: ChatTurn[];
  question: string;
  chatId?: number; // 스트리밍용 (웹훅 모드)
  verbosityOverride?: "brief" | "normal" | "detailed"; // 자연어 힌트에서 추출됨
  /** astrologyReading/combinedReading일 때만 첨부하는 점성술 근거 텍스트 블록 */
  astrologyEvidence?: string;
}

/**
 * 오늘 일진 데이터를 이 질문에 붙일지 판단한다.
 * 사용자가 "오늘/일진/지금" 등을 직접 물었을 때만 붙인다 — 안 그러면 봇이 매 답변마다
 * 오늘의 운세를 억지로 갖다붙이게 된다(사용자 불만의 핵심).
 */
function questionAsksAboutToday(question: string): boolean {
  return /오늘|일진|지금\s*(어때|어떄|운|흐름|뭐)|오늘의|하루\s*운/.test(question);
}

/** 계산 근거 + 대화 맥락을 실어 Claude에게 해석을 요청한다 */
export async function askTeacher({ source, history, question, chatId, verbosityOverride, astrologyEvidence }: AskOptions): Promise<string> {
  const historyMessages = history.map((t) => ({ role: t.role, content: t.content }) as Anthropic.Messages.MessageParam);

  // 오늘 일진은 사용자가 오늘을 직접 물었을 때만 첨부한다(평소엔 원국 데이터만).
  const evidenceBlocks: string[] = [];
  if (source && questionAsksAboutToday(question)) evidenceBlocks.push(buildTodayEvidence(source));
  if (astrologyEvidence) evidenceBlocks.push(astrologyEvidence);
  const finalUserContent = evidenceBlocks.length > 0 ? `${evidenceBlocks.join("\n\n")}\n\n[질문]\n${question}` : `[질문]\n${question}`;

  const messages: Anthropic.Messages.MessageParam[] = source
    ? [
        {
          role: "user",
          // 원국·운 계산 데이터는 대화 내내 고정이라 프롬프트 캐시에 태운다.
          // 같은 사람과 이어지는 턴에서는 이 큰 JSON을 원가로 재전송하지 않고 캐시에서 읽어 토큰값을 아낀다.
          content: [
            {
              type: "text",
              text: `${buildNatalEvidence(source)}\n\n위 데이터가 이 대화 전체에서 해석의 근거가 되는 내 사주입니다. 사용자가 실제로 물어본 것에만 답하고, 안 물어본 항목(오늘 운세·대운 등)은 먼저 꺼내지 마세요.`,
              cache_control: { type: "ephemeral" },
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

  return runStream(messages, chatId, verbosityOverride, "teacher");
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
): Promise<string> {
  const level = verbosityOverride ?? BOT_VERBOSITY;
  const maxTokens = VERBOSITY_TOKENS[level];
  const systemPrompt = systemPromptOverride ?? buildTeacherSystem(level);
  const requestId = crypto.randomUUID();
  const startedAt = Date.now();

  // 짧은 채팅 답변엔 확장 사고를 끄고 바로 답하게 해 속도를 높인다.
  // 깊은 설명(detailed)일 때만 adaptive thinking을 켠다.
  const stream = client.messages.stream({
    model: MODEL,
    max_tokens: maxTokens,
    ...(BOT_TEMPERATURE !== undefined ? { temperature: BOT_TEMPERATURE } : {}),
    ...(level === "detailed" ? { thinking: { type: "adaptive" as const } } : {}),
    system: [{ type: "text", text: systemPrompt, cache_control: { type: "ephemeral" } }],
    messages,
  });

  let streamedText = "";
  // 토큰이 도착하는 대로 누적하고, chatId가 있으면 그때그때 화면에 반영한다.
  // for await로 각 emitPartial을 기다리므로 루프가 끝나면 진행 중 전송이 남지 않는다.
  try {
    for await (const event of stream) {
      if (event.type === "content_block_delta" && event.delta.type === "text_delta") {
        streamedText += event.delta.text;
        if (chatId) await emitPartial(chatId, streamedText);
      }
    }
  } catch (err) {
    logError("teacher.runStream", err);
    logRequest({ requestId, mode, latencyMs: Date.now() - startedAt, errorCode: "stream_error" });
    throw err;
  }

  const final = await stream.finalMessage();
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

[말투]
- *항상 한국어로.* 쉬운 일상말로. 텔레그램이라 표·긴 서식 없이 짧은 문장, 굵게는 *별표* 한 쌍만.
- 기본은 카드 수에 맞게 적당히(한 장이면 짧게, 여러 장이면 자리별로 한두 줄씩). 사용자가 "자세히"라고 하면 그때 더 깊게.
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
  return runStream(messages, chatId, undefined, "compatibility");
}
