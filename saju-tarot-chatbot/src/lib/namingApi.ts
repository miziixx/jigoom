import type { NameComparison, NameEvaluation, NamingBrief, NamingRecommendOptions } from "./naming";
import { serverErrorText } from "./readingApi";

async function postNaming(body: unknown, emptyError: string): Promise<string> {
  const res = await fetch("/api/naming", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    const errBody = (await res.json().catch(() => ({}))) as { error?: unknown };
    throw new Error(serverErrorText(errBody.error ?? errBody, `요청 실패 (HTTP ${res.status})`));
  }

  const data = (await res.json()) as { reply?: unknown };
  if (typeof data.reply !== "string" || !data.reply.trim()) {
    throw new Error(emptyError);
  }
  return data.reply;
}

export async function generateNamingInterpretation(evaluation: NameEvaluation, comparison?: NameComparison | null): Promise<string> {
  return postNaming({ mode: "evaluate", evaluation, comparison }, "이름 해석 응답이 비어 있습니다.");
}

export async function generateNameRecommendations(brief: NamingBrief, options: NamingRecommendOptions): Promise<string> {
  return postNaming({ mode: "recommend", brief, options }, "이름 추천 응답이 비어 있습니다.");
}
