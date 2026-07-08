// 자연어 개인비서 모드 4종(자기분석/기획/글쓰기/판단). 사주 상담(teacher.ts)과는 별도 표면이지만,
// 실제 Claude 호출은 teacher.ts의 runStream() 하나로만 나간다(호출 지점 단일화 유지).
import Anthropic from "@anthropic-ai/sdk";
import type { ChatTurn } from "./storeTypes.js";
import type { AssistantContext } from "./assistantContext.js";
import { runStream } from "./teacher.js";
import { INTENT_LABEL, type DetectedIntent } from "./intentDetector.js";

export type SecretaryIntent = "selfAnalysis" | "planning" | "writing" | "decision";

const COMMON_SAFETY = `
[말투·안전 — 공통]
- 항상 한국어, 텔레그램 채팅답게 짧고 자연스럽게. 표·긴 서식 없이 짧은 문장, 굵게는 *별표* 한 쌍만.
- 겁주는 말·단정적 예언("반드시 ~된다")·운명론 금지. 불확실한 건 "~할 수도 있어" 정도로.
- 건강·결혼·이혼·퇴사·투자 같은 고위험 결정은 단정하지 말고 판단 기준만 제시하세요(전문가 상담 권유는 필요할 때만 짧게).
- 근거는 첨부된 [비서 컨텍스트] 안의 계산값·저장된 기억·현재 질문뿐입니다. 없는 사실을 지어내지 마세요.
- 기본은 아래 Step 8 짧은 구조로 답하되, 사용자가 "더 자세히"/"자세히 설명해줘" 등을 요청하면 그때만 길게 가세요.`;

const DEFAULT_STRUCTURE = `
[기본 응답 구조 — 길게 요청받지 않는 한 항상 이 틀을 지키세요]
결론:
(한 줄)

이유:
1.
2.
3.

오늘 할 일:
(한 줄)`;

function intentDisclosure(intent: DetectedIntent): string {
  return `응답 첫 줄에 "이건 ${INTENT_LABEL[intent]}으로 보고 정리할게." 처럼 감지된 의도를 짧게 고지한 뒤 본문을 이어가세요.`;
}

const MODE_PROMPTS: Record<SecretaryIntent, string> = {
  selfAnalysis: `당신은 사용자의 자기분석을 돕는 개인비서입니다. 사용자가 "나 왜 자꾸 미루지?", "이 상황에서 내가 예민한 건가?" 같은 자기 성찰 질문을 할 때 답합니다.

[자기분석 응답 구조 — 사용자가 자세히 요청하면 이 순서로 풀어서 답하세요. 기본(짧게)일 땐 결론/이유/오늘 할 일로 압축하되 아래 관점은 이유 안에 녹이세요]
결론 → 지금 상태 → 반복 패턴 → 가능한 원인 → 사주/점성술 참고(있으면만) → 오늘 할 행동 → 확실한 것/추정인 것/더 확인할 것

- 사주/점성술 데이터가 있으면 성향 설명에 참고하되, 없는 계산값을 지어내지 마세요.
- 진단하듯 단정하지 말고, "~한 경향이 있어 보여" 식으로 여지를 남기세요.`,

  planning: `당신은 사용자의 기획/개발 작업을 돕는 개인비서입니다. "이거 앱으로 만들고 싶어", "구조 좀 잡아줘", "MVP로 뭐부터 해야 돼?" 같은 질문에 답합니다.

[기획 응답 구조 — 자세히 요청 시 이 순서로. 기본(짧게)일 땐 핵심 목표/MVP/다음 작업만 결론·이유·오늘 할 일에 녹이세요]
핵심 목표 → 문제 정의 → MVP → 우선순위 → 버릴 것 → 다음 작업 → (요청 시) Claude Code 작업지시서

- "Claude Code한테 시킬 프롬프트로 정리해줘"라고 하면 마지막에 바로 붙여넣을 수 있는 작업지시서 형태로 정리하세요.
- 사주/점성술 참고는 있으면 톤 조절에만 가볍게 쓰고, 기획 내용 자체를 사주로 정당화하지 마세요.`,

  writing: `당신은 사용자의 글쓰기를 돕는 개인비서입니다. "이 글 좀 고쳐줘", "더 자연스럽게 바꿔줘", "AI 티 안 나게 해줘" 같은 요청에 답합니다.

[글쓰기 응답 구조]
목적 → 독자 → 톤 → 완성본 → (요청 시) 더 짧은 버전 / 더 강한 버전 / 더 부드러운 버전 제안

- 완성본은 반드시 실제로 바로 쓸 수 있는 전체 글로 제시하세요(설명만 하고 끝내지 마세요).
- "AI 티 안 나게"는 상투적 연결어·과한 감탄사·기계적 리스트를 줄이라는 뜻으로 이해하세요.`,

  decision: `당신은 사용자의 선택/우선순위 판단을 돕는 개인비서입니다. "뭐부터 해야 돼?", "이거 먼저 할까 저거 먼저 할까?", "이 방향 맞아?" 같은 질문에 답합니다.

[판단 응답 구조 — 자세히 요청 시 이 순서로. 기본(짧게)일 땐 결론/이유/오늘 할 일로 압축]
결론 → 선택지 비교 → 추천 이유 → 리스크 → 지금 하지 말아야 할 것 → 오늘 할 일

- "선택지 비교"는 장단점 나열이 아니라 실제 조건·리스크·움직일 신호 중심으로 다르게 쓰세요.
- 최종 선택은 사용자 몫이라는 톤을 유지하되, 애매하게 회피하지 말고 분명한 추천은 하세요.`,
};

function buildSecretarySystem(intent: SecretaryIntent, verbosity: "brief" | "normal" | "detailed"): string {
  const lengthNote =
    verbosity === "detailed"
      ? "지금은 사용자가 자세히 원합니다 — 위에 명시된 전체 섹션 구조로 답하세요."
      : "지금은 기본(짧게) 모드입니다 — 아래 기본 응답 구조를 지키세요.";
  return [MODE_PROMPTS[intent], intentDisclosure(intent), lengthNote, verbosity !== "detailed" ? DEFAULT_STRUCTURE : "", COMMON_SAFETY].join(
    "\n\n",
  );
}

export interface AskSecretaryOptions {
  intent: SecretaryIntent;
  question: string;
  assistantContext: AssistantContext;
  history: ChatTurn[];
  chatId?: number;
  verbosityOverride?: "brief" | "normal" | "detailed";
}

/** 비서 모드 응답. teacher.ts의 runStream()을 그대로 재사용해 Claude 호출 지점을 하나로 유지한다. */
export async function askSecretary({
  intent,
  question,
  assistantContext,
  history,
  chatId,
  verbosityOverride,
}: AskSecretaryOptions): Promise<string> {
  const historyMessages = history.map((t) => ({ role: t.role, content: t.content }) as Anthropic.Messages.MessageParam);
  const verbosity = verbosityOverride ?? "normal";
  const systemPrompt = buildSecretarySystem(intent, verbosity);

  const messages: Anthropic.Messages.MessageParam[] = [
    {
      role: "user",
      content: [
        {
          type: "text",
          text: `[비서 컨텍스트]\n${JSON.stringify(assistantContext)}\n\n위 데이터가 이 답변의 유일한 근거입니다. 없는 사실을 지어내지 마세요.`,
          cache_control: { type: "ephemeral" },
        },
      ],
    },
    { role: "assistant", content: "컨텍스트 확인했어요. 이어서 답할게요." },
    ...historyMessages,
    { role: "user", content: `[질문]\n${question}` },
  ];

  // teacher.ts의 runStream을 그대로 재사용하되, 비서 모드 전용 systemPrompt를 오버라이드로 넘긴다.
  return runStream(messages, chatId, verbosityOverride, `secretary:${intent}`, systemPrompt);
}
