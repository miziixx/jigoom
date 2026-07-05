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

  it("모순이 있는 judgment는 confidence를 낮추고 cautious tone으로 완화한다", () => {
    const pack = buildJudgmentPack({
      readingType: "saju",
      compactEvidence: mockCompactEvidence(),
      question: "퇴사 후 창업해도 될까요?",
      generatedAt: "2026-07-06T00:00:00.000Z",
    });
    const career = pack.judgments.find((judgment) => judgment.code === "CAREER_CHANGE_HIGH");

    expect(pack.contradictions.map((item) => item.id)).toContain("contradiction.career_change.startup_not_recommended");
    expect(career?.allowedTone.stance).toBe("cautious");
    expect(career?.confidence.reasons.some((reason) => reason.includes("모순 탐지"))).toBe(true);
  });
});
