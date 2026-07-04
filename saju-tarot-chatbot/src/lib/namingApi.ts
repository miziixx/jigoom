import type { NameComparison, NameEvaluation } from "./naming";
import { serverErrorText } from "./readingApi";

export async function generateNamingInterpretation(evaluation: NameEvaluation, comparison?: NameComparison | null): Promise<string> {
  const res = await fetch("/api/naming", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ evaluation, comparison }),
  });

  if (!res.ok) {
    const errBody = (await res.json().catch(() => ({}))) as { error?: unknown };
    throw new Error(serverErrorText(errBody.error ?? errBody, `요청 실패 (HTTP ${res.status})`));
  }

  const data = (await res.json()) as { reply?: unknown };
  if (typeof data.reply !== "string" || !data.reply.trim()) {
    throw new Error("이름 해석 응답이 비어 있습니다.");
  }
  return data.reply;
}
