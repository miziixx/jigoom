import { describe, it, expect } from "vitest";
import { computeAstrologyProfile, computeMajorAspects, computeCurrentTransitTheme } from "./astrology.js";
import type { BirthInfo } from "../types/index.js";

const withTime: BirthInfo = {
  calendarType: "solar",
  year: 1993,
  month: 3,
  day: 15,
  hour: 14,
  minute: 30,
  birthPlace: "seoul",
  gender: "female",
};

const noTime: BirthInfo = {
  calendarType: "solar",
  year: 1993,
  month: 3,
  day: 15,
  hour: null,
  gender: "female",
};

describe("computeAstrologyProfile", () => {
  it("출생시간이 있으면 상승궁·하우스까지 계산한다", () => {
    const profile = computeAstrologyProfile(withTime);
    expect(profile.timeKnown).toBe(true);
    expect(profile.classical.ascendant).toBeDefined();
    expect(profile.modern.sun.house).toBeDefined();
  });

  it("출생시간이 없으면 상승궁 없이 별자리만 계산한다", () => {
    const profile = computeAstrologyProfile(noTime);
    expect(profile.timeKnown).toBe(false);
    expect(profile.classical.ascendant).toBeUndefined();
    expect(profile.modern.sun.sign).toBeTruthy();
  });
});

describe("computeMajorAspects", () => {
  it("천체 쌍 사이 각도를 표준 5대 각도(orb 이내)로 분류해 반환한다", () => {
    const profile = computeAstrologyProfile(withTime);
    const aspects = computeMajorAspects(profile);
    for (const a of aspects) {
      expect(["합", "육십분", "사각", "삼분", "충"]).toContain(a.aspect);
      expect(a.orb).toBeGreaterThanOrEqual(0);
    }
  });
});

describe("computeCurrentTransitTheme", () => {
  it("상승궁이 있으면 오늘 태양/달의 하우스를 계산해 테마 문장을 만든다", () => {
    const profile = computeAstrologyProfile(withTime);
    const theme = computeCurrentTransitTheme(profile, new Date());
    expect(theme.sunTransitHouse).toBeGreaterThanOrEqual(1);
    expect(theme.theme).toContain("하우스");
  });

  it("상승궁이 없으면(출생시간 미상) 하우스 계산 불가 문구를 반환한다", () => {
    const profile = computeAstrologyProfile(noTime);
    const theme = computeCurrentTransitTheme(profile, new Date());
    expect(theme.sunTransitHouse).toBeUndefined();
    expect(theme.theme).toContain("계산하지 못했");
  });
});
