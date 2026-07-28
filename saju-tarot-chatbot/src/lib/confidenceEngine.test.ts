import { describe, expect, it } from "vitest";
import { evidenceRefsFromCompactEvidence } from "./evidenceIds.js";
import { scoreConfidence } from "./confidenceEngine.js";
import { mockCompactEvidence } from "./judgmentTestFixture.js";
import { triggerRules } from "./ruleEngine.js";

describe("confidenceEngine", () => {
  it("chart/luck/event/context/overall 구조로 확신도를 산정한다", () => {
    const compactEvidence = mockCompactEvidence();
    const evidence = evidenceRefsFromCompactEvidence(compactEvidence);
    const rule = triggerRules({ readingType: "saju", compactEvidence, evidence })[0];
    const confidence = scoreConfidence(rule, 8);

    expect(confidence.chart).toBeGreaterThanOrEqual(0);
    expect(confidence.luck).toBeGreaterThanOrEqual(0);
    expect(confidence.event).toBeGreaterThanOrEqual(0);
    expect(confidence.context).toBeGreaterThanOrEqual(0);
    expect(confidence.overall).toBeGreaterThanOrEqual(0);
    expect(confidence.overall).toBeLessThanOrEqual(100);
  });
});
