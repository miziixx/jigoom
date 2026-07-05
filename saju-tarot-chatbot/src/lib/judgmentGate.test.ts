import { describe, expect, it } from "vitest";
import { buildJudgmentPack } from "./judgmentEngine.js";
import { buildJudgmentFallback, buildJudgmentRewritePrompt, finalizeJudgmentPackAudit, passOrNeedsRewrite } from "./judgmentGate.js";
import { mockCompactEvidence } from "./judgmentTestFixture.js";
import { validateOutputAgainstJudgmentPack } from "./judgmentValidation.js";

function pack() {
  return buildJudgmentPack({
    readingType: "saju",
    compactEvidence: mockCompactEvidence(),
    question: "퇴사 후 창업해도 될까요?",
    generatedAt: "2026-07-06T00:00:00.000Z",
  });
}

describe("judgmentGate", () => {
  it("forbidden claim이 있으면 통과시키지 않고 rewrite 필요 상태로 돌린다", () => {
    const result = passOrNeedsRewrite("지금 퇴사하세요. 반드시 창업하세요.", pack());

    expect(result.status).toBe("needs-rewrite");
    if (result.status === "needs-rewrite") {
      expect(result.validation.ok).toBe(false);
      expect(result.validation.status).toBe("rewrite");
    }
  });

  it("rewrite prompt는 같은 JudgmentPack 안에서만 다시 쓰라고 지시한다", () => {
    const p = pack();
    const validation = validateOutputAgainstJudgmentPack({ pack: p, reply: "지금 퇴사하세요." });
    const prompt = buildJudgmentRewritePrompt({ originalReply: "지금 퇴사하세요.", validation, pack: p });

    expect(prompt).toContain("JudgmentPack에 없는 새 결론을 추가하지 마라");
    expect(prompt).toContain("confidence < 40");
    expect(prompt).toContain("지금 퇴사하세요");
  });

  it("rewrite 성공 응답은 pass로 재검수된다", () => {
    const p = pack();
    const safeReply = [
      "# 첫 점괘",
      "직업 환경이 변할 가능성이 있습니다.",
      "# 분야별 요약",
      "career: 역할 변화 가능성을 조건부로 봅니다.",
      "# 지금 해야 할 것과 피해야 할 것",
      "고정비와 준비 기간을 먼저 확인하세요.",
      "# 마지막 점괘",
      "단정 대신 조건을 확인하는 흐름입니다.",
    ].join("\n");
    const validation = validateOutputAgainstJudgmentPack({ pack: p, reply: safeReply });

    expect(validation.ok).toBe(true);
    expect(validation.status).toBe("pass");
  });

  it("rewrite 실패 시 fallback은 forbidden claim 없이 생성된다", () => {
    const p = pack();
    const fallback = buildJudgmentFallback(p);
    const validation = validateOutputAgainstJudgmentPack({ pack: p, reply: fallback });

    expect(fallback).toContain("현재 계산 근거만으로는");
    expect(validation.issues.some((issue) => issue.code === "forbidden-claim")).toBe(false);
  });

  it("fallback 결과는 audit에 상태로 기록할 수 있다", () => {
    const p = pack();
    const firstValidation = validateOutputAgainstJudgmentPack({ pack: p, reply: "지금 퇴사하세요." });
    const fallbackValidation = validateOutputAgainstJudgmentPack({ pack: p, reply: buildJudgmentFallback(p) });
    const audited = finalizeJudgmentPackAudit(p, {
      status: "fallback",
      reply: buildJudgmentFallback(p),
      validation: fallbackValidation,
      firstValidation,
      rewriteValidation: firstValidation,
      rewriteAttempted: true,
      fallbackUsed: true,
    });

    expect(audited.audit.validationStatus).toBe("fallback");
    expect(audited.audit.rewriteAttempted).toBe(true);
    expect(audited.audit.fallbackUsed).toBe(true);
    expect(audited.audit.finalConfidence).toBeGreaterThanOrEqual(0);
  });
});
