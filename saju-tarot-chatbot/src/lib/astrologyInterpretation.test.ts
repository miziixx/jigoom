import { describe, it, expect } from "vitest";
import { computeAstrologyProfile, computeMajorAspects, NAKSHATRAS } from "./astrology.js";
import {
  buildAstrologyInterpretationHints,
  PLANET_ROLE,
  SIGN_STYLE,
  HOUSE_THEME,
  ASPECT_GLOSS,
  DIGNITY_GLOSS,
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

// 엔진 업그레이드 A-1: KB를 엔진 실제 출력과 교차 검증(오타·드리프트·누락 감지). "KB=엔진 산출 집합".
describe("지식베이스 완결성 — 엔진 교차 검증 (A-1)", () => {
  it("NAKSHATRA_GLOSS 키가 엔진 NAKSHATRAS 27개와 정확히 일치한다 (오타·드리프트 감지)", () => {
    expect(new Set(Object.keys(NAKSHATRA_GLOSS))).toEqual(new Set(NAKSHATRAS));
  });

  it("HOUSE_THEME이 1~12하우스를 빠짐없이 덮는다", () => {
    for (let h = 1; h <= 12; h += 1) expect(HOUSE_THEME[h], `${h}하우스`).toBeTruthy();
    expect(Object.keys(HOUSE_THEME)).toHaveLength(12);
  });

  it("dignity() 5개 상태 전부 DIGNITY_GLOSS가 있다", () => {
    for (const d of ["도미사일", "엑잘테이션", "디트리먼트", "폴", "페레그린"]) {
      expect(DIGNITY_GLOSS[d], d).toBeTruthy();
    }
  });

  it("계산된 프로파일의 모든 행성·포인트에 PLANET_ROLE이 있다 (지어내기 방지)", () => {
    const profile = computeAstrologyProfile(withTime);
    const bodies = new Set<string>();
    for (const p of [profile.modern.sun, profile.modern.moon, profile.modern.ascendant, profile.modern.venus, profile.modern.mars]) {
      if (p) bodies.add(p.body);
    }
    for (const p of profile.modern.outer) bodies.add(p.body);
    for (const p of profile.classical.placements) bodies.add(p.body);
    bodies.add(profile.vedic.rahu.body);
    bodies.add(profile.vedic.ketu.body);
    for (const body of bodies) expect(PLANET_ROLE[body], body).toBeTruthy();
  });

  it("뚜렷한 고전 품위가 배치 힌트에 인라인으로 실린다 (A-1 품위 결합)", () => {
    const profile = computeAstrologyProfile(withTime);
    const hints = buildAstrologyInterpretationHints(profile, computeMajorAspects(profile));
    const notable = profile.classical.placements.filter((p) => p.dignity !== "페레그린");
    for (const p of notable) {
      const line = hints.placements.find((h) => h.startsWith(`${p.body}:`));
      // 현대/고전 어느 경로로든 그 행성 배치 힌트가 있고, 뚜렷한 품위면 품위 gloss가 인라인으로 붙는다.
      if (line) expect(line, `${p.body} ${p.dignity}`).toContain(DIGNITY_GLOSS[p.dignity]);
    }
  });
});
