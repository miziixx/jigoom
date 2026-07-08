// "기억해줘" 자연어 요청 처리 — 원문을 저장하지 않고, Claude에게 1~2문장 요약+카테고리
// 분류만 짧게 요청해(teacher.ts의 runStream 재사용) 그 요약만 저장한다.
import type Anthropic from "@anthropic-ai/sdk";
import { runStream } from "./teacher.js";
import { isSensitiveContent } from "./assistantContext.js";
import type { ChatTurn, MemoryCategory } from "./storeTypes.js";

const CATEGORY_VALUES: MemoryCategory[] = ["projectMemory", "userPreference", "repeatedPattern", "writingStyle", "decisionLog"];

const MEMORY_SUMMARY_SYSTEM = `당신은 대화에서 사용자가 "기억해달라"고 한 내용만 뽑아 짧게 요약하는 보조 도구입니다.
반드시 아래 형식으로만 답하세요(다른 설명·인사 붙이지 마세요):
카테고리: projectMemory 또는 userPreference 또는 repeatedPattern 또는 writingStyle 또는 decisionLog 중 하나
요약: 1~2문장

카테고리 판단 기준: 프로젝트/앱/작업 관련=projectMemory, 사용자 취향/기준=userPreference, 반복되는 행동 패턴=repeatedPattern, 글쓰기 톤/문체 선호=writingStyle, 과거 판단/결정 기록=decisionLog.
"요약"은 원문을 그대로 베끼지 말고, 나중에 다른 대화에서 참고할 수 있는 사실만 짧게 담으세요.`;

export interface MemorySummaryResult {
  category: MemoryCategory;
  summary: string;
  sensitive: boolean;
}

/** 최근 대화 맥락 + 방금 메시지에서 "기억할 내용"만 요약해 돌려준다. 원문은 반환하지 않는다. */
export async function summarizeForMemory(history: ChatTurn[], triggerMessage: string): Promise<MemorySummaryResult> {
  const historyMessages = history.slice(-6).map((t) => ({ role: t.role, content: t.content }) as Anthropic.Messages.MessageParam);
  const messages: Anthropic.Messages.MessageParam[] = [
    ...historyMessages,
    { role: "user", content: `[사용자가 방금 한 말]\n${triggerMessage}\n\n위 대화에서 기억해달라고 한 내용만 지시된 형식으로 요약하세요.` },
  ];

  const raw = await runStream(messages, undefined, "brief", "memorySummarize", MEMORY_SUMMARY_SYSTEM);

  const categoryMatch = raw.match(/카테고리:\s*(\S+)/);
  const summaryMatch = raw.match(/요약:\s*([\s\S]+)/);
  const category = CATEGORY_VALUES.find((c) => categoryMatch?.[1]?.includes(c)) ?? "projectMemory";
  const summary = (summaryMatch?.[1]?.trim() || raw.trim()).slice(0, 500);

  return { category, summary, sensitive: isSensitiveContent(summary) || isSensitiveContent(triggerMessage) };
}

const CATEGORY_HINTS: Array<{ category: MemoryCategory; patterns: RegExp[] }> = [
  { category: "projectMemory", patterns: [/프로젝트/, /앱/, /작업/] },
  { category: "writingStyle", patterns: [/글쓰기/, /문체/, /톤/] },
  { category: "decisionLog", patterns: [/결정/, /판단/] },
  { category: "repeatedPattern", patterns: [/패턴/, /반복/] },
  { category: "userPreference", patterns: [/취향/, /선호/, /기준/] },
];

/** "이거 내 프로젝트 기억 지워줘" 처럼 삭제 요청에 카테고리가 언급됐는지 감지 */
export function detectMemoryDeleteScope(text: string): { mode: "recent" | "all"; category?: MemoryCategory } {
  const mode: "recent" | "all" = /전부|모두|다\s*지워|싹/.test(text) ? "all" : "recent";
  const hint = CATEGORY_HINTS.find((h) => h.patterns.some((p) => p.test(text)));
  return { mode, category: hint?.category };
}
