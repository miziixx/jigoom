import { describe, expect, it } from "vitest";
import { buildJudgmentPack } from "./judgmentEngine.js";
import { mockCompactEvidence } from "./judgmentTestFixture.js";
import { validateJudgmentPack, validateOutputAgainstJudgmentPack } from "./judgmentValidation.js";

describe("judgmentValidation", () => {
  it("모든 judgment가 evidence/rule/forbiddenClaims/confidence를 갖는지 검사한다", () => {
    const pack = buildJudgmentPack({
      readingType: "saju",
      compactEvidence: mockCompactEvidence(),
      generatedAt: "2026-07-06T00:00:00.000Z",
    });
    const result = validateJudgmentPack(pack);

    expect(result.ok).toBe(true);
    expect(result.issues).toHaveLength(0);
  });

  it("LLM 출력의 forbidden claim을 JudgmentPack 기준으로 잡는다", () => {
    const pack = buildJudgmentPack({
      readingType: "saju",
      compactEvidence: mockCompactEvidence(),
      generatedAt: "2026-07-06T00:00:00.000Z",
    });
    const result = validateOutputAgainstJudgmentPack({
      pack,
      reply: "지금 퇴사하세요. 반드시 창업하세요.",
    });

    expect(result.ok).toBe(false);
    expect(result.issues.some((issue) => issue.code === "forbidden-claim")).toBe(true);
  });
});
