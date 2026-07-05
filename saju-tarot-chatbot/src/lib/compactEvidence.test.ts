import { describe, expect, it } from "vitest";
import { buildCompactEvidence, formatCompactEvidence } from "./compactEvidence.js";
import { computeLuckCycles, computeSajuChart } from "./saju.js";
import type { BirthInfo } from "../types/index.js";

const birth: BirthInfo = {
  calendarType: "solar",
  year: 1990,
  month: 12,
  day: 23,
  hour: 8,
  minute: 0,
  gender: "female",
};

describe("compactEvidence", () => {
  it("기본 리딩에 필요한 핵심 판단만 압축한다", () => {
    const chart = computeSajuChart(birth);
    const luck = computeLuckCycles(birth, new Date("2026-07-03T03:00:00Z"));
    const evidence = buildCompactEvidence(chart, luck, birth.gender);

    expect(evidence.dayMaster).toBe(chart.dayMasterGan);
    expect(evidence.strength?.label).toBe(chart.strength?.label);
    expect(evidence.topFindings.length).toBeGreaterThan(0);
    expect(evidence.domainScores.length).toBeGreaterThan(0);
    expect(Object.keys(evidence.evidenceIds)).toContain("natal_core");
    expect(Object.keys(evidence.evidenceIds)).toContain("current_luck");
  });

  it("직렬화 결과에는 원자료 전체 대신 판단 JSON 필드가 중심이 된다", () => {
    const chart = computeSajuChart(birth);
    const luck = computeLuckCycles(birth, new Date("2026-07-03T03:00:00Z"));
    const text = formatCompactEvidence(buildCompactEvidence(chart, luck, birth.gender));

    expect(text).toContain('"topFindings"');
    expect(text).toContain('"domainScores"');
    expect(text).toContain('"riskFlags"');
    expect(text).not.toContain("지장간");
    expect(text).not.toContain("12운성");
    expect(text).not.toContain("앞으로 10년");
    expect(text).not.toContain("올해 1월");
  });
});
