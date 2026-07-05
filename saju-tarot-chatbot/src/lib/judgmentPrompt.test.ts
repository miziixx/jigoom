import { describe, expect, it } from "vitest";
import { buildJudgmentPack } from "./judgmentEngine.js";
import { formatJudgmentPackForPrompt } from "./judgmentPrompt.js";
import { mockCompactEvidence } from "./judgmentTestFixture.js";

describe("judgmentPrompt", () => {
  it("LLM 역할을 판단 생성이 아니라 문장 번역으로 제한한다", () => {
    const pack = buildJudgmentPack({
      readingType: "saju",
      compactEvidence: mockCompactEvidence(),
      generatedAt: "2026-07-06T00:00:00.000Z",
    });
    const prompt = formatJudgmentPackForPrompt(pack);

    expect(prompt).toContain('"judgments"');
    expect(prompt).toContain("judgments에 없는 새 결론 생성");
    expect(prompt).toContain("prompt.judgment_pack.v1");
  });
});
