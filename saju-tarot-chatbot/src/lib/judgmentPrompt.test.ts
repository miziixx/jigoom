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

    expect(prompt).toContain("■ 판단들");
    expect(prompt).toContain("judgments에 없는 새 결론 생성");
    // 번역자 역할 제한과 금지 규칙이 남아 있어야 한다
    expect(prompt).toContain("공통 금지 표현");
  });

  it("컴팩트 직렬화: 감사/스키마 노이즈를 빼 통짜 JSON 덤프보다 훨씬 작다", () => {
    const pack = buildJudgmentPack({
      readingType: "saju",
      compactEvidence: mockCompactEvidence(),
      generatedAt: "2026-07-06T00:00:00.000Z",
    });
    const prompt = formatJudgmentPackForPrompt(pack);
    // 내부 감사용 필드는 프롬프트에 실리지 않는다
    expect(prompt).not.toContain("decisionTrace");
    expect(prompt).not.toContain("schemaVersion");
    expect(prompt).not.toContain("audit");
    // 통짜 JSON 덤프(수만 자)보다 훨씬 작아야 한다
    expect(prompt.length).toBeLessThan(12000);
  });
});
