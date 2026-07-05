import { describe, expect, it } from "vitest";
import { evidenceRefsFromCompactEvidence } from "./evidenceIds.js";
import { mockCompactEvidence } from "./judgmentTestFixture.js";
import { triggerRules } from "./ruleEngine.js";

describe("ruleEngine", () => {
  it("compact evidence에서 rule id와 근거를 가진 rule을 발동한다", () => {
    const compactEvidence = mockCompactEvidence();
    const evidence = evidenceRefsFromCompactEvidence(compactEvidence);
    const rules = triggerRules({
      readingType: "saju",
      compactEvidence,
      evidence,
      question: "퇴사 후 창업해도 될까요?",
    });

    expect(rules.map((rule) => rule.id)).toContain("rule.career.change");
    expect(rules.map((rule) => rule.id)).toContain("rule.money.risk");
    expect(rules.map((rule) => rule.id)).toContain("rule.startup.not_recommended");
    expect(rules.every((rule) => rule.evidence.length > 0)).toBe(true);
  });
});
