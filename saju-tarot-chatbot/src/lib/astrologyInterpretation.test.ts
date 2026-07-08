import { describe, it, expect } from "vitest";
import { computeAstrologyProfile, computeMajorAspects } from "./astrology.js";
import {
  buildAstrologyInterpretationHints,
  PLANET_ROLE,
  SIGN_STYLE,
  ASPECT_GLOSS,
  NAKSHATRA_GLOSS,
} from "./astrologyInterpretation.js";
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

describe("buildAstrologyInterpretationHints", () => {
  it("계산된 배치에만 힌트를 붙인다 (태양·달은 항상, 상승궁은 시간 있을 때만)", () => {
    const profile = computeAstrologyProfile(withTime);
    const hints = buildAstrologyInterpretationHints(profile, computeMajorAspects(profile));

    // 태양/달 힌트는 항상 존재
    expect(hints.placements.some((h) => h.startsWith("태양:"))).toBe(true);
    expect(hints.placements.some((h) => h.startsWith("달:"))).toBe(true);
    // 시간이 있으면 상승궁 힌트도 존재
    expect(hints.placements.some((h) => h.startsWith("상승궁:"))).toBe(true);
    // 하우스 영역 표기가 붙는다
    expect(hints.placements.some((h) => h.includes("하우스"))).toBe(true);
  });

  it("출생시간 미상이면 상승궁 힌트를 만들지 않는다 (없는 배치 지어내기 방지)", () => {
    const profile = computeAstrologyProfile(noTime);
    const hints = buildAstrologyInterpretationHints(profile, computeMajorAspects(profile));
    expect(hints.placements.some((h) => h.startsWith("상승궁:"))).toBe(false);
  });

  it("베딕 달 나크샤트라와 현재 마하다샤 힌트를 채운다", () => {
    const profile = computeAstrologyProfile(withTime);
    const hints = buildAstrologyInterpretationHints(profile, computeMajorAspects(profile));
    expect(hints.nakshatra).toBeTruthy();
    expect(hints.dasha).toContain("마하다샤");
    expect(hints.integrationNote).toContain("세 전통");
  });

  it("각도 힌트는 표준 5대 각도 gloss만 사용한다", () => {
    const profile = computeAstrologyProfile(withTime);
    const aspects = computeMajorAspects(profile);
    const hints = buildAstrologyInterpretationHints(profile, aspects);
    for (const h of hints.aspects) {
      const matched = Object.values(ASPECT_GLOSS).some((g) => h.includes(g));
      expect(matched).toBe(true);
    }
  });
});

describe("지식베이스 완결성", () => {
  it("12별자리 전부 스타일 gloss가 있다", () => {
    expect(Object.keys(SIGN_STYLE)).toHaveLength(12);
  });

  it("27 나크샤트라 전부 gloss가 있다", () => {
    expect(Object.keys(NAKSHATRA_GLOSS)).toHaveLength(27);
  });

  it("주요 행성·포인트 역할 gloss가 있다", () => {
    for (const body of ["태양", "달", "수성", "금성", "화성", "목성", "토성", "상승궁", "라후", "케투"]) {
      expect(PLANET_ROLE[body]).toBeTruthy();
    }
  });
});
