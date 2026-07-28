import { describe, expect, it } from "vitest";
import { computeLuckCycles, computeSajuChart } from "./saju.js";
import type { BirthInfo, FiveElementBalance } from "../types/index.js";

interface PillarBaseline {
  name: string;
  birth: BirthInfo;
  pillars: {
    year: string;
    month: string;
    day: string;
    hour: string | null;
  };
  dayMaster: string;
  fiveElements: FiveElementBalance;
  yinYang: { yang: number; yin: number };
  luck2026: {
    currentDaYun: string | null;
    yearGanZhi: string;
    monthGanZhi: string;
    dayGanZhi: string;
    firstDaYun: {
      startAge: number;
      endAge: number;
      startYear: number;
      endYear: number;
      ganZhi: string;
      current: boolean;
    };
  };
}

const BASELINES: PillarBaseline[] = [
  {
    name: "양력 표준 케이스: 1990-12-23 08:00 여성",
    birth: { calendarType: "solar", year: 1990, month: 12, day: 23, hour: 8, minute: 0, gender: "female" },
    pillars: { year: "경오", month: "무자", day: "임술", hour: "갑진" },
    dayMaster: "임",
    fiveElements: { wood: 1, fire: 1, earth: 3, metal: 1, water: 2 },
    yinYang: { yang: 8, yin: 0 },
    luck2026: {
      currentDaYun: "갑신",
      yearGanZhi: "병오",
      monthGanZhi: "갑오",
      dayGanZhi: "무인",
      firstDaYun: { startAge: 7, endAge: 16, startYear: 1996, endYear: 2005, ganZhi: "정해", current: false },
    },
  },
  {
    name: "양력 관계·신살 기준 케이스: 1985-06-15 14:00 여성",
    birth: { calendarType: "solar", year: 1985, month: 6, day: 15, hour: 14, minute: 0, gender: "female" },
    pillars: { year: "을축", month: "임오", day: "을유", hour: "계미" },
    dayMaster: "을",
    fiveElements: { wood: 2, fire: 1, earth: 2, metal: 1, water: 2 },
    yinYang: { yang: 2, yin: 6 },
    luck2026: {
      currentDaYun: "병술",
      yearGanZhi: "병오",
      monthGanZhi: "갑오",
      dayGanZhi: "무인",
      firstDaYun: { startAge: 8, endAge: 17, startYear: 1992, endYear: 2001, ganZhi: "계미", current: false },
    },
  },
  {
    name: "입춘 직후 연월주 기준 케이스: 1984-02-05 02:00 남성",
    birth: { calendarType: "solar", year: 1984, month: 2, day: 5, hour: 2, minute: 0, gender: "male" },
    pillars: { year: "갑자", month: "병인", day: "기사", hour: "을축" },
    dayMaster: "기",
    fiveElements: { wood: 3, fire: 2, earth: 2, metal: 0, water: 1 },
    yinYang: { yang: 4, yin: 4 },
    luck2026: {
      currentDaYun: "경오",
      yearGanZhi: "병오",
      monthGanZhi: "갑오",
      dayGanZhi: "무인",
      firstDaYun: { startAge: 10, endAge: 19, startYear: 1993, endYear: 2002, ganZhi: "정묘", current: false },
    },
  },
];

describe("사주 계산 기준 케이스", () => {
  it.each(BASELINES)("$name", ({ birth, pillars, dayMaster, fiveElements, yinYang, luck2026 }) => {
    const chart = computeSajuChart(birth);
    const luck = computeLuckCycles(birth, new Date("2026-07-03T03:00:00Z"), { includeMonthlyFlow: true });

    expect({
      year: chart.year.ganZhi,
      month: chart.month.ganZhi,
      day: chart.day.ganZhi,
      hour: chart.hour?.ganZhi ?? null,
    }).toEqual(pillars);
    expect(chart.dayMasterGan).toBe(dayMaster);
    expect(chart.fiveElements).toEqual(fiveElements);
    expect(chart.yinYang).toEqual(yinYang);
    expect(luck.currentDaYun).toBe(luck2026.currentDaYun);
    expect(luck.yearGanZhi).toBe(luck2026.yearGanZhi);
    expect(luck.monthGanZhi).toBe(luck2026.monthGanZhi);
    expect(luck.dayGanZhi).toBe(luck2026.dayGanZhi);
    // 만세력 대운(간지·나이·연도)만 잠근다. 십성·12운성·신살·삼재 등 해석 필드는
    // additive라 스냅샷에서 제외하고 기존 키만 비교한다.
    const { startAge, endAge, startYear, endYear, ganZhi, current } = luck.daYun[0];
    expect({ startAge, endAge, startYear, endYear, ganZhi, current }).toEqual(luck2026.firstDaYun);
  });
});

describe("사주 계산 특수 케이스", () => {
  it("음력 평달과 윤달은 서로 다른 원국과 대운을 만든다", () => {
    const normal = computeSajuChart({ calendarType: "lunar", year: 1987, month: 6, day: 15, hour: 12, minute: 0, gender: "male" });
    const leap = computeSajuChart({
      calendarType: "lunar",
      year: 1987,
      month: 6,
      day: 15,
      hour: 12,
      minute: 0,
      gender: "male",
      isLeapMonth: true,
    });

    expect([normal.year.ganZhi, normal.month.ganZhi, normal.day.ganZhi, normal.hour?.ganZhi]).toEqual(["정묘", "정미", "경신", "임오"]);
    expect([leap.year.ganZhi, leap.month.ganZhi, leap.day.ganZhi, leap.hour?.ganZhi]).toEqual(["정묘", "무신", "경인", "임오"]);
    expect(normal.timeCorrection?.applied).toContain("서머타임 -60분");
    expect(leap.timeCorrection?.applied).toContain("서머타임 -60분");
  });

  it("23시대 출생은 야자시/조자시 선택에 따라 일주가 달라진다", () => {
    const birth = { calendarType: "solar" as const, year: 2000, month: 1, day: 1, hour: 23, minute: 30, gender: "male" as const };
    const late = computeSajuChart({ ...birth, lateNightZi: "late" });
    const early = computeSajuChart({ ...birth, lateNightZi: "early" });

    expect([late.year.ganZhi, late.month.ganZhi, late.day.ganZhi, late.hour?.ganZhi]).toEqual(["기묘", "병자", "무오", "갑자"]);
    expect([early.year.ganZhi, early.month.ganZhi, early.day.ganZhi, early.hour?.ganZhi]).toEqual(["기묘", "병자", "기미", "갑자"]);
  });

  it("출생 시간을 모르면 시주를 제외하고 연월일주와 오행을 계산한다", () => {
    const chart = computeSajuChart({ calendarType: "solar", year: 1990, month: 12, day: 23, hour: null, minute: 0, gender: "female" });

    expect([chart.year.ganZhi, chart.month.ganZhi, chart.day.ganZhi, chart.hour]).toEqual(["경오", "무자", "임술", null]);
    expect(chart.fiveElements).toEqual({ wood: 0, fire: 1, earth: 2, metal: 1, water: 2 });
    expect(chart.tenGods).toContain("시간: 출생시간 모름");
  });

  it("서머타임과 출생지 경도 보정은 보정 내역에 남긴다", () => {
    const chart = computeSajuChart({
      calendarType: "solar",
      year: 1988,
      month: 6,
      day: 1,
      hour: 12,
      minute: 0,
      gender: "male",
      birthPlace: "seoul",
    });

    expect([chart.year.ganZhi, chart.month.ganZhi, chart.day.ganZhi, chart.hour?.ganZhi]).toEqual(["무진", "정사", "정해", "을사"]);
    expect(chart.timeCorrection?.applied).toContain("서머타임 -60분");
    expect(chart.timeCorrection?.applied).toContain("서울/경기/인천 경도 보정 -32분");
    expect(chart.timeCorrection?.correctedDateTime).toBe("1988-06-01 10:28");
    expect(chart.timeCorrection?.boundaryWarning).toBeNull();
  });
});
