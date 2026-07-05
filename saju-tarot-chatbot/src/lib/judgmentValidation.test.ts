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
    expect(result.status).toBe("rewrite");
    expect(result.issues.some((issue) => issue.code === "forbidden-claim")).toBe(true);
  });

  it("JudgmentPack에 없는 도메인 결론을 error로 차단한다", () => {
    const pack = buildJudgmentPack({
      readingType: "saju",
      compactEvidence: mockCompactEvidence(),
      generatedAt: "2026-07-06T00:00:00.000Z",
    });
    const careerOnlyPack = { ...pack, judgments: pack.judgments.filter((judgment) => judgment.domain === "career") };
    const result = validateOutputAgainstJudgmentPack({
      pack: careerOnlyPack,
      reply: "직업 환경은 바뀔 가능성이 있습니다. 그리고 결혼합니다.",
    });

    expect(result.ok).toBe(false);
    expect(result.issues.some((issue) => issue.code === "unsupported-domain-claim" && issue.severity === "error")).toBe(true);
  });

  it("semantic claim으로 직접 실행 명령을 차단한다", () => {
    const pack = buildJudgmentPack({
      readingType: "saju",
      compactEvidence: mockCompactEvidence(),
      generatedAt: "2026-07-06T00:00:00.000Z",
    });
    const result = validateOutputAgainstJudgmentPack({
      pack,
      reply: "직업 변화 가능성이 있으니 지금 퇴사하세요.",
    });

    expect(result.ok).toBe(false);
    expect(result.issues.some((issue) => issue.code === "semantic-claim-violation")).toBe(true);
  });

  it("confidence가 낮은 판단에 강한 표현이 나오면 차단한다", () => {
    const pack = buildJudgmentPack({
      readingType: "saju",
      compactEvidence: mockCompactEvidence(),
      generatedAt: "2026-07-06T00:00:00.000Z",
    });
    const lowConfidencePack = {
      ...pack,
      judgments: pack.judgments.map((judgment) => ({
        ...judgment,
        confidence: { ...judgment.confidence, overall: 35 },
      })),
    };
    const result = validateOutputAgainstJudgmentPack({
      pack: lowConfidencePack,
      reply: "직업 변화 흐름이 강하게 나타납니다.",
    });

    expect(result.ok).toBe(false);
    expect(result.issues.some((issue) => issue.code === "confidence-tone-violation")).toBe(true);
  });
});
