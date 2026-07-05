import { describe, expect, it } from "vitest";
import { detectContradictions } from "./contradictionEngine.js";
import { buildJudgmentPack } from "./judgmentEngine.js";
import { mockCompactEvidence } from "./judgmentTestFixture.js";

describe("contradictionEngine", () => {
  it("직업 변화와 즉시 창업 금지 사이의 긴장을 탐지한다", () => {
    const pack = buildJudgmentPack({
      readingType: "saju",
      compactEvidence: mockCompactEvidence(),
      question: "퇴사 후 창업해도 될까요?",
      generatedAt: "2026-07-06T00:00:00.000Z",
    });
    const contradictions = detectContradictions(pack.judgments);

    expect(contradictions.map((item) => item.id)).toContain("contradiction.career_change.startup_not_recommended");
  });
});
