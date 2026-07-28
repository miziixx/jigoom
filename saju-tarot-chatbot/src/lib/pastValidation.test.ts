import { describe, expect, it } from "vitest";
import { computeSajuChart, computePastEventCalibrationInputs } from "./saju.js";
import { buildPastValidationReport } from "./pastValidation.js";
import type { BirthInfo, PastEvent } from "../types/index.js";

const female1990: BirthInfo = { calendarType: "solar", year: 1990, month: 12, day: 23, hour: 8, minute: 0, gender: "female" };

describe("과거 검증", () => {
  it("입력이 없으면 null을 반환한다", () => {
    const chart = computeSajuChart(female1990);
    const inputs = computePastEventCalibrationInputs(female1990, []);
    expect(inputs).toEqual([]);
    expect(buildPastValidationReport(chart.dayMasterGan, inputs)).toBeNull();
  });

  it("과거 사건마다 그 해 세운 간지와 상호작용을 계산한다", () => {
    const events: PastEvent[] = [
      { year: 2021, domain: "career", note: "이직" },
      { year: 2023, domain: "love", note: "관계 정리" },
    ];
    const inputs = computePastEventCalibrationInputs(female1990, events);
    expect(inputs).toHaveLength(2);
    for (const inp of inputs) {
      expect(inp.yearGanZhi.length).toBe(2); // 간지 2글자
      expect(Array.isArray(inp.interactions)).toBe(true);
    }
    // 2021년 신축, 2023년 계묘 (입춘 기준)
    expect(inputs[0].yearGanZhi).toBe("신축");
    expect(inputs[1].yearGanZhi).toBe("계묘");
  });

  it("부합 판정과 headline·근거를 만든다", () => {
    const chart = computeSajuChart(female1990);
    const events: PastEvent[] = [
      { year: 2021, domain: "career", note: "이직" },
      { year: 2023, domain: "money" },
    ];
    const inputs = computePastEventCalibrationInputs(female1990, events);
    const report = buildPastValidationReport(chart.dayMasterGan, inputs)!;
    expect(report.matches).toHaveLength(2);
    for (const m of report.matches) {
      expect(["strong", "partial", "weak"]).toContain(m.level);
      expect(m.summary.length).toBeGreaterThan(0);
      expect(m.evidence.length).toBeGreaterThan(0);
      // 표면 요약에는 십성 용어를 노출하지 않는다
      for (const term of ["편재", "정관", "식신", "비견", "겁재"]) expect(m.summary).not.toContain(term);
    }
    expect(report.headline.length).toBeGreaterThan(0);
    // 연도 오름차순 정렬
    expect(report.matches[0].year).toBeLessThanOrEqual(report.matches[1].year);
  });

  it("근거(evidence)에는 세운/대운 간지를 남긴다", () => {
    const chart = computeSajuChart(female1990);
    const inputs = computePastEventCalibrationInputs(female1990, [{ year: 2021, domain: "career" }]);
    const report = buildPastValidationReport(chart.dayMasterGan, inputs)!;
    const evidence = report.matches[0].evidence.join(" ");
    expect(evidence).toContain("세운");
    expect(evidence).toContain("신축");
  });
});
