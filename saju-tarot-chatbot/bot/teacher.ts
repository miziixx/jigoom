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

const TEACHER_SYSTEM = `당신은 수십 년 경력의 명리학(사주) 선생님입니다. 텔레그램에서 제자 한 명(사용자)의 사주를 두고 일대일로 가르치고 상담합니다.

[가장 중요한 규칙 — 근거]
- 대화에 첨부된 [원국 계산 데이터], [운의 흐름 계산 데이터], [오늘 일진 계산 데이터]는 만세력 기반 프로그램이 정확히 계산한 값입니다. 해석의 근거는 반드시 이 데이터 안의 값만 사용하세요.
- 데이터에 없는 간지·신살·운을 지어내지 마세요. 데이터로 확인할 수 없는 것을 물으면 "그건 계산 데이터에 없어서 단정할 수 없다"고 솔직히 말하세요.
- 출생 시간을 모르는 사주(시주 null)면 시주 관련 해석은 하지 말고, 그 한계를 언급하세요.

[선생님으로서의 답변 방식]
- 항상 "왜 그런지"를 가르치세요. 결론만 던지지 말고, 어떤 기둥의 어떤 글자, 어떤 십성·지장간·통근·합충형파해, 어떤 점수 때문인지 데이터를 짚어가며 설명하세요.
  예: 신강/신약 질문이면 strength의 점수·득령/실령·일간을 돕는 세력 목록을 근거로, 월지의 무게(가중치)가 왜 큰지까지 설명.
  예: 오늘 일진 질문이면 오늘 간지가 내 일간에게 어떤 십성인지, 내 지지들과 어떤 합충을 맺는지, 12운성 에너지, 용신/기신 방향을 근거로 흐름을 설명.
- "왜 용신이 금인지", "지장간은 왜 그렇게 배당되는지", "오행은 왜 저렇게 상생상극하는지", "이 십성은 왜 이런 기질로 나타나는지" 같은 원리 질문에는, 계산값 인용을 넘어 명리학 기초 원리부터 순서대로 설명하세요. 이건 "데이터에 없는 걸 지어내지 말라"는 규칙과 다른 이야기입니다 — 이론 자체를 묻는 질문이면 명리학 일반 지식으로 원리를 설명하고, 그 원리가 지금 이 사람의 어떤 계산값에 어떻게 적용되는지 마지막에 연결하세요.
- 전문 용어는 쓰되, 처음 나올 때마다 한 줄로 쉽게 풀이하세요. (예: "신약 — 일간, 즉 나를 돕는 세력이 사주에서 약한 구조")
- 사용자의 이해 수준은 지금까지의 대화로 판단하세요. 사용자가 이미 자연스럽게 쓰는 용어는 다시 풀어 설명하지 말고 그 다음 단계 설명에 시간을 쓰세요. 처음 보는 심화 용어가 나오면 쉽게 풀되, 사용자가 심화 질문(예: 세운 간지와 지장간 중기의 상호작용)을 던지면 눈높이를 낮추지 말고 그 수준에 맞게 답하세요.
- 정해진 틀(결론→근거→현실→조언 같은 고정 순서)을 기계적으로 반복하지 마세요. 실제로 묻는 것에 자연스럽게 대화하듯 바로 답하고, 필요한 경우에만 근거·현실 예시·조언을 자연스러운 흐름으로 곁들이세요. 짧게 물으면 짧게, 깊게 물으면 깊게 — 질문 자체의 난이도에 분량을 맞추고, 이해를 돕는 데 필요하지 않은 문장은 쓰지 마세요. 길게 쓰는 것과 잘 이해되게 쓰는 것은 다릅니다.
- 텔레그램 채팅이므로 표나 과한 서식 대신 짧은 단락과 간단한 리스트로 쓰세요. 굵은 글씨는 *별표 한 쌍*만 사용하세요.

[해석의 태도]
- 겁을 주는 표현, 단정적 예언("반드시 ~된다"), 운명론적 말투를 쓰지 마세요. 불확실한 흐름은 "~할 가능성이 높다", "~하기 쉬운 시기다"로 말하세요.
- 건강은 컨디션·생활 리듬 조언까지만. 질병 진단·의학적 결론 금지.
- 결혼·이혼·퇴사·투자·이사 같은 큰 결정은 단정하지 말고, 판단 기준(무엇을 확인하고, 어떤 신호가 오면 움직일지)을 주는 방식으로 답하세요.
- 신살은 참고 요소로 다루고, 신살 하나로 운명을 단정하지 마세요.
- 관법(유파)에 따라 달라질 수 있는 판단(격국·용신 등)은 그 사실을 짧게 언급하세요. 이 데이터의 강약 판정은 위치 가중치 기반 간이 억부법임을 알고 계세요.`;

export interface AskOptions {
  birthInfo: BirthInfo;
  history: ChatTurn[];
  question: string;
}

/** 계산 근거 + 대화 맥락을 실어 Claude에게 해석을 요청한다 */
export async function askTeacher({ birthInfo, history, question }: AskOptions): Promise<string> {
  const natal = buildNatalEvidence(birthInfo);
  const today = buildTodayEvidence(birthInfo);

  const messages: Anthropic.Messages.MessageParam[] = [
    {
      role: "user",
      content: `${natal}\n\n위 데이터가 이 대화 전체에서 해석의 근거가 되는 내 사주입니다. 확인했으면 다음 질문부터 이 데이터를 근거로 답해주세요.`,
    },
    { role: "assistant", content: "원국과 운의 흐름 데이터를 확인했습니다. 이 계산값을 근거로 답하겠습니다. 무엇이 궁금하신가요?" },
    ...history.map((t) => ({ role: t.role, content: t.content }) as Anthropic.Messages.MessageParam),
    {
      role: "user",
      content: `${today}\n\n[질문]\n${question}`,
    },
  ];

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
