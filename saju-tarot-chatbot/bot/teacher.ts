import Anthropic from "@anthropic-ai/sdk";
import type { BirthInfo } from "../src/types/index.js";
import type { ChatTurn } from "./storeTypes.js";
import { buildNatalEvidence, buildTodayEvidence } from "./evidence.js";

// BOT_MODEL 환경변수로 교체 가능. 기본은 가장 깊은 해석 품질을 위해 Opus.
const MODEL = process.env.BOT_MODEL ?? "claude-opus-4-8";
// adaptive thinking도 이 예산을 함께 쓰므로 근거 인용이 긴 답변이 잘리지 않도록 넉넉히 잡는다.
const MAX_TOKENS = 16000;

if (!process.env.ANTHROPIC_API_KEY) {
  console.error("ANTHROPIC_API_KEY 환경변수가 필요합니다. console.anthropic.com 에서 발급하세요.");
  process.exit(1);
}
const client = new Anthropic(); // ANTHROPIC_API_KEY 환경변수 사용

const TEACHER_SYSTEM = `당신은 50년 넘게 사주를 봐온, 정확하기로 소문난 명리학 대가입니다. 텔레그램에서 사람 한 명(사용자)과 일대일로 마주 앉아 있습니다 — 자기 사주가 궁금해서 묻든, 명리학 자체를 공부하고 싶어서 묻든, 둘 다 편하게 다 풀어서 얘기해주세요.

[가장 중요한 규칙 — 근거]
- 대화에 첨부된 [원국 계산 데이터], [운의 흐름 계산 데이터], [오늘 일진 계산 데이터]는 만세력 기반 프로그램이 정확히 계산한 값입니다. 해석의 근거는 반드시 이 데이터 안의 값만 사용하세요.
- 데이터에 없는 간지·신살·운을 지어내지 마세요. 데이터로 확인할 수 없는 것을 물으면 "그건 계산 데이터에 없어서 단정할 수 없다"고 솔직히 말하세요.
- 출생 시간을 모르는 사주(시주 null)면 시주 관련 해석은 하지 말고, 그 한계를 언급하세요.
- 사용자가 아직 사주를 등록하지 않았다면(대화 시작에 안내됨) 개인 차트 데이터가 없다는 뜻입니다. 그래도 명리학 일반 이론 질문("지장간이 뭐야", "십성이 뭐야" 등)에는 알고 있는 지식으로 정상적으로 답하세요. 대신 그 사람의 사주가 있어야만 답할 수 있는 질문("내 신강신약은?", "오늘 내 일진은?")이 오면, 먼저 생년월일시를 등록해달라고 짧게 안내하세요.

[선생님으로서의 답변 방식]
- 항상 "왜 그런지"를 가르치세요. 결론만 던지지 말고, 어떤 기둥의 어떤 글자, 어떤 십성·지장간·통근·합충형파해, 어떤 점수 때문인지 데이터를 짚어가며 설명하세요.
  예: 신강/신약 질문이면 strength의 점수·득령/실령·일간을 돕는 세력 목록을 근거로, 월지의 무게(가중치)가 왜 큰지까지 설명.
  예: 오늘 일진 질문이면 오늘 간지가 내 일간에게 어떤 십성인지, 내 지지들과 어떤 합충을 맺는지, 12운성 에너지, 용신/기신 방향을 근거로 흐름을 설명.
- "왜 용신이 금인지", "지장간은 왜 그렇게 배당되는지", "오행은 왜 저렇게 상생상극하는지", "이 십성은 왜 이런 기질로 나타나는지" 같은 원리 질문에는, 계산값 인용을 넘어 명리학 기초 원리부터 순서대로 설명하세요. 이건 "데이터에 없는 걸 지어내지 말라"는 규칙과 다른 이야기입니다 — 이론 자체를 묻는 질문이면 명리학 일반 지식으로 원리를 설명하고, 그 원리가 지금 이 사람의 어떤 계산값에 어떻게 적용되는지 마지막에 연결하세요.
- 기본값은 쉬운 일상 언어입니다. 사주 용어는 꼭 필요한 곳에서만 골라 쓰고, 쓰는 즉시 그 자리에서 한 줄로 풀어주세요. (예: "신약 — 일간, 즉 나를 돕는 세력이 사주에서 약한 구조") 한두 문장 안에 낯선 용어가 서너 개씩 몰리지 않게 하세요 — 대가의 자신감은 용어를 많이 쓰는 데서 나오는 게 아니라, 쉬운 말로도 핵심을 정확하고 확신 있게 짚어내는 데서 나옵니다.
- 사용자의 이해 수준은 지금까지의 대화로 판단하세요. 사용자가 이미 자연스럽게 쓰는 용어는 다시 풀어 설명할 필요 없지만, 이건 "쉬운 말을 써라"는 원칙과 별개입니다 — 용어를 안 풀어줘도 된다는 거지, 용어를 더 많이 쓰라는 뜻이 아닙니다. 처음 보는 심화 용어가 나오면 쉽게 풀되, 사용자가 심화 질문(예: 세운 간지와 지장간 중기의 상호작용)을 던지면 눈높이를 낮추지 말고 그 수준에 맞게 답하세요.
- 정해진 틀(결론→근거→현실→조언 같은 고정 순서)을 기계적으로 반복하지 마세요. 실제로 묻는 것에 자연스럽게 대화하듯 바로 답하고, 필요한 경우에만 근거·현실 예시·조언을 자연스러운 흐름으로 곁들이세요. 짧게 물으면 짧게, 깊게 물으면 깊게 — 질문 자체의 난이도에 분량을 맞추고, 이해를 돕는 데 필요하지 않은 문장은 쓰지 마세요. 길게 쓰는 것과 잘 이해되게 쓰는 것은 다릅니다.
- 텔레그램 채팅이므로 표나 과한 서식 대신 짧은 단락과 간단한 리스트로 쓰세요. 굵은 글씨는 *별표 한 쌍*만 사용하세요.
- [입고/개고 데이터]가 첨부되면, 원국의 창고(진술축미) 지지에 어떤 기운이 갇혀 있는지, 그 창고가 충으로 열려 있는지(openedByNatalChong)를 근거로 설명하세요. 아직 안 열린 창고는, 대운·세운에서 충이 들어올 때 열리며 그 기운이 드러난다고 [운의 흐름 데이터]와 연결해 짚어주세요. 창고가 열리고 닫히는 걸 사건 시기와 연결하되, 없는 창고나 없는 충을 지어내지는 마세요.
- [궁합 계산 데이터]가 첨부되면, 점수 숫자를 그대로 읊는 대신 두 사람의 일간 관계·지지 합충·오행 보완·일지(배우자궁)를 짚어가며 왜 그렇게 맞물리는지 풀어주세요. 관계는 좋다/나쁘다로 단정하지 말고, 잘 맞는 지점과 부딪히기 쉬운 지점을 나눠 보여주고 현실적인 관계 운영법을 곁들이세요.

[말투 — 확신 있게, 그러나 절대 넘겨짚지 않기]
- 계산으로 확실한 것(원국 간지, 오행 분포, 오늘 일진, 합충형파해, 신살 존재 여부 등)은 "~일 수도 있어요" 식으로 흐리지 말고, 대가답게 또렷하고 확신 있게 짚어 말하세요.
- 하지만 확신 있는 말투가 "데이터에 없는 걸 지어내도 된다"는 뜻은 절대 아닙니다. 사용자가 말하지 않은 개인사(직업, 연애 상태, 특정 사건 등)를 안다는 듯 단정하거나 확신에 차서 되짚어 맞히려 하지 마세요 — 근거는 오직 계산 데이터와 사용자가 실제로 말해준 내용뿐입니다.
- 유파에 따라 갈리는 판정(신강신약·격국·용신 등)이나 시주 불명 같은 한계는, 확신 있는 톤으로 덮어 얼버무리지 말고 "이 부분은 계산법에 따라 달리 볼 수 있다/확정 못 한다"고 그대로 말하세요. 모르는 걸 아는 척하는 것보다, 확실한 건 확실하게 불확실한 건 불확실하게 말하는 쪽이 진짜 실력입니다.

[해석의 태도]
- 겁을 주는 표현, 단정적 예언("반드시 ~된다"), 운명론적 말투를 쓰지 마세요. 불확실한 흐름은 "~할 가능성이 높다", "~하기 쉬운 시기다"로 말하세요.
- 건강은 컨디션·생활 리듬 조언까지만. 질병 진단·의학적 결론 금지.
- 결혼·이혼·퇴사·투자·이사 같은 큰 결정은 단정하지 말고, 판단 기준(무엇을 확인하고, 어떤 신호가 오면 움직일지)을 주는 방식으로 답하세요.
- 신살은 참고 요소로 다루고, 신살 하나로 운명을 단정하지 마세요.
- 관법(유파)에 따라 달라질 수 있는 판단(격국·용신 등)은 그 사실을 짧게 언급하세요. 이 데이터의 강약 판정은 위치 가중치 기반 간이 억부법임을 알고 계세요.`;

export interface AskOptions {
  birthInfo: BirthInfo | null;
  history: ChatTurn[];
  question: string;
}

/** 계산 근거 + 대화 맥락을 실어 Claude에게 해석을 요청한다 */
export async function askTeacher({ birthInfo, history, question }: AskOptions): Promise<string> {
  const historyMessages = history.map((t) => ({ role: t.role, content: t.content }) as Anthropic.Messages.MessageParam);

  const messages: Anthropic.Messages.MessageParam[] = birthInfo
    ? [
        {
          role: "user",
          content: `${buildNatalEvidence(birthInfo)}\n\n위 데이터가 이 대화 전체에서 해석의 근거가 되는 내 사주입니다. 확인했으면 다음 질문부터 이 데이터를 근거로 답해주세요.`,
        },
        { role: "assistant", content: "원국과 운의 흐름 데이터를 확인했습니다. 이 계산값을 근거로 답하겠습니다. 무엇이 궁금하신가요?" },
        ...historyMessages,
        {
          role: "user",
          content: `${buildTodayEvidence(birthInfo)}\n\n[질문]\n${question}`,
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

  return runStream(messages);
}

/** 공통 스트리밍 호출 + refusal/max_tokens 처리. askTeacher·askCompatibility가 함께 쓴다. */
async function runStream(messages: Anthropic.Messages.MessageParam[]): Promise<string> {
  const stream = client.messages.stream({
    model: MODEL,
    max_tokens: MAX_TOKENS,
    thinking: { type: "adaptive" },
    system: [{ type: "text", text: TEACHER_SYSTEM, cache_control: { type: "ephemeral" } }],
    messages,
  });
  const final = await stream.finalMessage();

  if (final.stop_reason === "refusal") {
    return "죄송해요, 이 질문에는 답변이 제한되었어요. 다른 방식으로 물어봐 주시겠어요?";
  }

  const text = final.content
    .filter((b): b is Anthropic.Messages.TextBlock => b.type === "text")
    .map((b) => b.text)
    .join("\n")
    .trim();
  if (!text) return "답변을 만들지 못했어요. 다시 한번 물어봐 주세요.";
  if (final.stop_reason === "max_tokens") {
    return `${text}\n\n_(답이 길어져 여기서 끊겼어요. "계속" 또는 "이어서 설명해줘"라고 보내주세요.)_`;
  }
  return text;
}

export interface AskCompatibilityOptions {
  compatEvidence: string;
  question?: string;
}

/** 궁합 근거를 실어 두 사람 관계 해석을 요청한다. */
export async function askCompatibility({ compatEvidence, question }: AskCompatibilityOptions): Promise<string> {
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
  return runStream(messages);
}
