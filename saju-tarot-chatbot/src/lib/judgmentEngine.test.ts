import { describe, expect, it } from "vitest";
import { buildJudgmentPack } from "./judgmentEngine.js";
import { mockCompactEvidence } from "./judgmentTestFixture.js";

describe("judgmentEngine", () => {
  it("rule 결과를 code 기반 JudgmentCandidate와 Decision Trace로 변환한다", () => {
    const pack = buildJudgmentPack({
      readingType: "saju",
      compactEvidence: mockCompactEvidence(),
      question: "퇴사 후 창업해도 될까요?",
      generatedAt: "2026-07-06T00:00:00.000Z",
    });

    expect(pack.schemaVersion).toBe("1.0.0");
    expect(pack.judgments.map((judgment) => judgment.code)).toContain("CAREER_CHANGE_HIGH");
    expect(pack.judgments.map((judgment) => judgment.code)).toContain("STARTUP_NOT_RECOMMENDED");
    expect(pack.judgments.every((judgment) => judgment.evidence.length > 0)).toBe(true);
    expect(pack.judgments.every((judgment) => judgment.forbiddenClaims.length > 0)).toBe(true);
    expect(pack.decisionTrace.map((step) => step.stage)).toContain("confidence");
  });
});
