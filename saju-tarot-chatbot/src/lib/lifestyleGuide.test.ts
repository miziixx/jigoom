import { describe, expect, it } from "vitest";
import { buildLifestyleGuide, type Element } from "./lifestyleGuide.js";
import { computeSajuChart } from "./saju.js";
import type { BirthInfo } from "../types/index.js";

const birth: BirthInfo = { calendarType: "solar", year: 1990, month: 12, day: 23, hour: 8, minute: 0, gender: "female" };
const chart = computeSajuChart(birth);

// 기준 오행(한글) → 그 오행을 천간으로 갖는 일진 글자
const ELEMENT_STEM: Record<Element, string> = {
  wood: "갑",
  fire: "병",
  earth: "무",
  metal: "경",
  water: "임",
};

describe("생활 처방 개인화", () => {
  it("보조 기운과 과하면 부담 기운을 함께 계산한다", () => {
    const guide = buildLifestyleGuide(chart);
    expect(guide.basisLabel).toBeTruthy();
    // 보조 오행은 기준과 달라야 한다
    expect(guide.secondaryElement).not.toBe(guide.basisElement);
    // basisReason에 개인화 근거가 녹아 있다
    expect(guide.basisReason.length).toBeGreaterThan(10);
  });

  it("오늘 일진을 주지 않으면 today는 null이다", () => {
    expect(buildLifestyleGuide(chart).today).toBeNull();
  });

  it("오늘 일진 기운이 기준 기운과 같으면 boost로 계산한다", () => {
    const guide = buildLifestyleGuide(chart);
    const sameElementStem = ELEMENT_STEM[guide.basisElement];
    const withToday = buildLifestyleGuide(chart, { todayGanZhi: `${sameElementStem}자` });
    expect(withToday.today).not.toBeNull();
    expect(withToday.today?.relation).toBe("boost");
    expect(withToday.today?.headline).toContain("오늘");
    expect(withToday.today?.action).toBeTruthy();
  });

  it("날짜(일진)에 따라 today가 달라진다", () => {
    const a = buildLifestyleGuide(chart, { todayGanZhi: "갑자" });
    const b = buildLifestyleGuide(chart, { todayGanZhi: "임자" });
    // 서로 다른 일진이면 오늘 기운 라벨이 달라질 수 있다 (같은 basis라도 관계가 갈림)
    expect(a.today?.element).not.toBe(b.today?.element);
  });
});
