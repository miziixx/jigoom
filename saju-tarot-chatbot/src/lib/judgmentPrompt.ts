import type { JudgmentPack } from "./judgmentTypes.js";

export function formatJudgmentPackForPrompt(pack: JudgmentPack): string {
  return JSON.stringify(
    {
      schemaVersion: pack.schemaVersion,
      readingType: pack.readingType,
      evidence: pack.evidence,
      triggeredRules: pack.triggeredRules,
      judgments: pack.judgments,
      contradictions: pack.contradictions,
      globalForbiddenClaims: pack.globalForbiddenClaims,
      decisionTrace: [...pack.decisionTrace, { stage: "prompt", refId: "prompt.judgment_pack", summary: "LLM에는 JudgmentPack만 판단 근거로 전달" }],
      audit: { ...pack.audit, promptId: "prompt.judgment_pack.v1" },
      llmRole: {
        allowed: [
          "judgments[].plainConclusion을 상담 문장으로 번역",
          "evidence[].summary를 쉬운 말과 전문가 근거로 짧게 인용",
          "allowedTone과 actionFrame 안에서만 행동 조언 작성",
        ],
        forbidden: [
          "judgments에 없는 새 결론 생성",
          "forbiddenClaims에 해당하는 표현 사용",
          "evidence 없이 퇴사·창업·결혼·투자·질병 결론 작성",
        ],
      },
    },
    null,
    2,
  );
}
