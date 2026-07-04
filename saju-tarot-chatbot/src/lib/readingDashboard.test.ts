import { describe, expect, it } from "vitest";
import { buildReadingDashboard } from "./readingDashboard.js";
import { computeSajuChart } from "./saju.js";
import type { BirthInfo } from "../types/index.js";

const birth: BirthInfo = { calendarType: "solar", year: 1994, month: 10, day: 8, hour: 14, minute: 30, gender: "female" };
const chart = computeSajuChart(birth);

describe("결과 요약 대시보드 룰", () => {
  it("차트가 없으면 null", () => {
    expect(buildReadingDashboard(undefined)).toBeNull();
  });

  it("강점·주의점·키워드·스펙트럼·인생영역을 만든다", () => {
    const d = buildReadingDashboard(chart);
    expect(d).not.toBeNull();
    expect(d!.strengths.length).toBeGreaterThan(0);
    expect(d!.strengths.length).toBeLessThanOrEqual(3);
    expect(d!.cautions.length).toBeGreaterThan(0);
    expect(d!.cautions.length).toBeLessThanOrEqual(3);
    expect(d!.keywords.length).toBeGreaterThan(0);
    expect(d!.keywords.length).toBeLessThanOrEqual(5);
  });

  it("스펙트럼은 4축, position은 0~100 범위", () => {
    const d = buildReadingDashboard(chart)!;
    expect(d.spectrum).toHaveLength(4);
    for (const axis of d.spectrum) {
      expect(axis.position).toBeGreaterThanOrEqual(0);
      expect(axis.position).toBeLessThanOrEqual(100);
      expect(axis.leftLabel.length).toBeGreaterThan(0);
      expect(axis.rightLabel.length).toBeGreaterThan(0);
      expect(axis.note.length).toBeGreaterThan(0);
    }
  });

  it("인생영역은 6개, level 0~100 + 톤 라벨", () => {
    const d = buildReadingDashboard(chart)!;
    expect(d.lifeAreas).toHaveLength(6);
    for (const area of d.lifeAreas) {
      expect(area.level).toBeGreaterThanOrEqual(0);
      expect(area.level).toBeLessThanOrEqual(100);
      expect(["high", "mid", "low"]).toContain(area.tone);
      expect(area.toneLabel.length).toBeGreaterThan(0);
      expect(area.note.length).toBeGreaterThan(0);
    }
  });

  it("같은 사주는 같은 대시보드를 낸다(결정론)", () => {
    expect(buildReadingDashboard(chart)).toEqual(buildReadingDashboard(chart));
  });

  it("키워드는 중복이 없다", () => {
    const d = buildReadingDashboard(chart)!;
    expect(new Set(d.keywords).size).toBe(d.keywords.length);
  });
});
