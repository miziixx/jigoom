import type { FeedbackRating, ReadingFeedback, ReadingSession } from "../types";
import { loadSessions, saveSession } from "./storage";

export const RATING_LABEL: Record<FeedbackRating, string> = {
  accurate: "잘 맞았어요",
  partial: "어느 정도 맞았어요",
  unsure: "잘 모르겠어요",
  inaccurate: "별로 안 맞았어요",
};

export const FEEDBACK_TAGS = [
  { id: "too-abstract", label: "너무 추상적이에요" },
  { id: "want-specific", label: "더 구체적이면 좋겠어요" },
  { id: "good-advice", label: "조언이 좋았어요" },
  { id: "hard-to-understand", label: "설명이 어려웠어요" },
] as const;

/** 세션에 피드백을 저장하고, 갱신된 세션을 반환한다 */
export function saveFeedback(sessionId: string, rating: FeedbackRating, tags: string[]): ReadingSession | undefined {
  const session = loadSessions().find((s) => s.id === sessionId);
  if (!session) return undefined;
  const feedback: ReadingFeedback = { rating, tags, createdAt: new Date().toISOString() };
  const updated: ReadingSession = { ...session, feedback };
  saveSession(updated);
  return updated;
}

/**
 * 지난 피드백에서 반복되는 불만을 스타일 조정 요청 문장으로 만든다.
 * 사용자가 "지난 피드백 반영"에 동의(체크)했을 때만 호출해서 쓴다.
 */
export function buildStyleHintFromFeedback(): string | null {
  const feedbacks = loadSessions()
    .map((s) => s.feedback)
    .filter((f): f is ReadingFeedback => f !== undefined);
  if (feedbacks.length === 0) return null;

  const tagCount = new Map<string, number>();
  for (const f of feedbacks) {
    for (const tag of f.tags ?? []) tagCount.set(tag, (tagCount.get(tag) ?? 0) + 1);
  }

  const hints: string[] = [];
  if ((tagCount.get("too-abstract") ?? 0) + (tagCount.get("want-specific") ?? 0) >= 2) {
    hints.push("이 사용자는 추상적인 표현보다 구체적인 상황·행동 묘사를 선호한다. 예시와 실제 모습 서술의 비중을 늘려라.");
  }
  if ((tagCount.get("hard-to-understand") ?? 0) >= 2) {
    hints.push("이 사용자는 전문 용어가 어렵다고 느낀다. 용어 사용을 줄이고 쉬운 말 풀이를 더 자주 붙여라.");
  }
  if ((tagCount.get("good-advice") ?? 0) >= 2) {
    hints.push("이 사용자는 현실 조언 섹션을 특히 좋아한다. 행동 조언을 조금 더 풍부하게 써라.");
  }

  const inaccurate = feedbacks.filter((f) => f.rating === "inaccurate").length;
  if (inaccurate >= 2 && inaccurate / feedbacks.length >= 0.4) {
    hints.push("지난 리딩들이 잘 맞지 않았다는 피드백이 많았다. 단정의 강도를 낮추고, 근거와 반대 근거를 더 투명하게 보여라.");
  }

  return hints.length > 0 ? hints.join(" ") : null;
}
