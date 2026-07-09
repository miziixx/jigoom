import { describe, expect, it } from "vitest";
import { buildGoosebumpReport } from "./goosebumpEngine.js";
import { computePastYearRawSignals } from "./saju.js";
import type { BirthInfo, PastYearRawSignal } from "../types/index.js";

describe("computePastYearRawSignals (saju.ts, 소름 엔진 C-1 원시값)", () => {
  const birth: BirthInfo = { calendarType: "solar", year: 1990, month: 12, day: 23, hour: 8, minute: 0, gender: "female" };

  it("연도 목록을 주면 각 연도의 세운 간지·상호작용을 계산한다(domain 없이)", () => {
    const signals = computePastYearRawSignals(birth, [2018, 2020, 2022]);
    expect(signals).toHaveLength(3);
    for (const s of signals) {
      expect(s.yearGanZhi).toMatch(/^[가-힣]{2}$/);
      expect(Array.isArray(s.interactions)).toBe(true);
    }
  });

  it("빈 연도 목록이면 빈 배열", () => {
    expect(computePastYearRawSignals(birth, [])).toEqual([]);
  });

  it("결정론: 같은 입력이면 항상 같은 결과", () => {
    expect(computePastYearRawSignals(birth, [2019])).toEqual(computePastYearRawSignals(birth, [2019]));
  });
});

describe("buildGoosebumpReport (소름 엔진, 재기획안 §7)", () => {
  const dayGan = "병"; // 화 일간, 재성=금(경/신), 관성=수(임/계) 등

  it("상호작용이 하나도 없는 연도는 후보에서 제외한다(확신 없는 해는 말하지 않는다)", () => {
    const signals: PastYearRawSignal[] = [{ year: 2019, yearGanZhi: "기묘", daYunGanZhi: null, interactions: [] }];
    const report = buildGoosebumpReport(dayGan, signals);
    expect(report.guesses).toEqual([]);
  });

  it("십성 부합 + 상호작용이 있는 연도만 guess로 남긴다", () => {
    const signals: PastYearRawSignal[] = [
      { year: 2021, yearGanZhi: "신축", daYunGanZhi: "경자", interactions: ["세운-일간 병경충"] },
      { year: 2019, yearGanZhi: "기묘", daYunGanZhi: null, interactions: [] },
    ];
    const report = buildGoosebumpReport(dayGan, signals);
    expect(report.guesses.some((g) => g.year === 2021)).toBe(true);
    expect(report.guesses.some((g) => g.year === 2019)).toBe(false);
  });

  it("최대 개수(maxGuesses)를 넘지 않는다", () => {
    const signals: PastYearRawSignal[] = [2016, 2018, 2020, 2021, 2023].map((year) => ({
      year,
      yearGanZhi: "경신",
      daYunGanZhi: "신유",
      interactions: [`세운-일간 병경충 ${year}`],
    }));
    const report = buildGoosebumpReport(dayGan, signals, { maxGuesses: 2 });
    expect(report.guesses.length).toBeLessThanOrEqual(2);
  });

  it("한 해에서 여러 분야가 동시에 강하면 그 해에서 가장 강한 분야 하나만 남긴다", () => {
    const signals: PastYearRawSignal[] = [
      { year: 2021, yearGanZhi: "신축", daYunGanZhi: "경자", interactions: ["세운-일간 병경충", "세운-일지 축미충"] },
    ];
    const report = buildGoosebumpReport(dayGan, signals);
    const years = report.guesses.map((g) => g.year);
    expect(new Set(years).size).toBe(years.length);
  });

  it("guess의 prompt는 연도와 쉬운 말 동사만 담고 사주 전문용어를 노출하지 않는다", () => {
    const signals: PastYearRawSignal[] = [
      { year: 2021, yearGanZhi: "신축", daYunGanZhi: "경자", interactions: ["세운-일간 병경충"] },
    ];
    const report = buildGoosebumpReport(dayGan, signals);
    for (const g of report.guesses) {
      expect(g.prompt).toContain(String(g.year));
      expect(g.prompt).toContain("맞나요?");
      for (const jargon of ["십성", "세운", "대운", "재성", "관성", "충", "합"]) {
        expect(g.prompt).not.toContain(jargon);
      }
    }
  });

  it("결정론: 같은 입력이면 항상 같은 결과", () => {
    const signals: PastYearRawSignal[] = [
      { year: 2021, yearGanZhi: "신축", daYunGanZhi: "경자", interactions: ["세운-일간 병경충"] },
    ];
    expect(buildGoosebumpReport(dayGan, signals)).toEqual(buildGoosebumpReport(dayGan, signals));
  });
});
