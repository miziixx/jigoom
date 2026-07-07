import { describe, expect, it } from "vitest";
import {
  computeChartFromPillars,
  computeLuckFromPillars,
  computeSajuChart,
  inferSolarDatesFromPillars,
} from "./saju.js";
import type { BirthInfo } from "../types/index.js";

// 만세력 사주팔자(여덟 글자)를 직접 입력하면, 생년월일시로 계산한 원국과
// 동일한 값(원국 간지·오행·십성·신강신약·격국·신살)을 내야 한다.
// 이게 이 기능의 핵심 요구사항이다: 사용자가 만세력에서 뽑은 팔자를 그대로 붙여넣으면
// 봇이 다시 계산하지 않고도 그 팔자를 근거로 정확히 해석한다.

describe("computeChartFromPillars — 생년월일시 계산과 원국 일치", () => {
  const cases: Array<{
    name: string;
    birth: BirthInfo;
    pillars: { year: string; month: string; day: string; hour: string | null };
  }> = [
    {
      name: "1990-12-23 08:00 여",
      birth: { calendarType: "solar", year: 1990, month: 12, day: 23, hour: 8, minute: 0, gender: "female" },
      pillars: { year: "경오", month: "무자", day: "임술", hour: "갑진" },
    },
    {
      name: "1985-06-15 14:00 여",
      birth: { calendarType: "solar", year: 1985, month: 6, day: 15, hour: 14, minute: 0, gender: "female" },
      pillars: { year: "을축", month: "임오", day: "을유", hour: "계미" },
    },
  ];

  for (const c of cases) {
    it(`${c.name}: 팔자 입력 원국이 생년월일시 원국과 일치`, () => {
      const fromBirth = computeSajuChart(c.birth);
      const fromPillars = computeChartFromPillars(c.pillars);

      // 네 기둥 간지
      expect(fromPillars.year.ganZhi).toBe(fromBirth.year.ganZhi);
      expect(fromPillars.month.ganZhi).toBe(fromBirth.month.ganZhi);
      expect(fromPillars.day.ganZhi).toBe(fromBirth.day.ganZhi);
      expect(fromPillars.hour?.ganZhi).toBe(fromBirth.hour?.ganZhi);

      // 파생 계산이 동일해야 한다
      expect(fromPillars.dayMasterGan).toBe(fromBirth.dayMasterGan);
      expect(fromPillars.fiveElements).toEqual(fromBirth.fiveElements);
      expect(fromPillars.yinYang).toEqual(fromBirth.yinYang);
      expect(fromPillars.tenGods).toEqual(fromBirth.tenGods);
      expect(fromPillars.hiddenStems).toEqual(fromBirth.hiddenStems);
      expect(fromPillars.strength?.label).toBe(fromBirth.strength?.label);
      // 격국(gyeokguk)은 일부러 비교하지 않는다: 격을 잡을 때 쓰는 사령(월률분야)은
      // 절입 경과일(생년월일)이 있어야 정해지므로, 팔자만 입력하면 정기 기준으로 폴백해
      // 격국명이 달라질 수 있다(관법에 따라 갈리는 부분 — 근거 데이터에도 명시됨).
      expect(fromPillars.gyeokguk?.name).toBeTruthy();
      expect(fromPillars.sinsal?.map((s) => s.name).sort()).toEqual(fromBirth.sinsal?.map((s) => s.name).sort());
      expect(fromPillars.interactions).toEqual(fromBirth.interactions);
    });
  }

  it("시주를 모르면(hour null) 시주 없이 계산한다", () => {
    const chart = computeChartFromPillars({ year: "경오", month: "무자", day: "임술", hour: null });
    expect(chart.hour).toBeNull();
    expect(chart.day.ganZhi).toBe("임술");
    // 시주가 빠져도 원국 나머지는 계산된다
    expect(chart.strength?.label).toBeDefined();
  });

  it("한자 간지도 한글로 정규화해 받는다", () => {
    const fromHanja = computeChartFromPillars({ year: "庚午", month: "戊子", day: "壬戌", hour: "甲辰" });
    const fromHangul = computeChartFromPillars({ year: "경오", month: "무자", day: "임술", hour: "갑진" });
    expect(fromHanja.day.ganZhi).toBe("임술");
    expect(fromHanja.fiveElements).toEqual(fromHangul.fiveElements);
  });

  it("팔자(연·월·일)로 실제 양력 날짜를 되짚는다", () => {
    // 1990-12-23 08:00 → 경오/무자/임술 : 범위 안 유일 후보
    expect(inferSolarDatesFromPillars("경오", "무자", "임술", { maxYear: 2026 })).toEqual([
      { year: 1990, month: 12, day: 23 },
    ]);
  });

  it("같은 간지가 60년마다 반복되면 후보를 모두(오름차순) 낸다", () => {
    // 계해/을축/계묘 → 1924-01-25, 1984-01-10 (연주는 입춘 전이라 계해)
    const dates = inferSolarDatesFromPillars("계해", "을축", "계묘", { maxYear: 2026 });
    expect(dates).toEqual([
      { year: 1924, month: 1, day: 25 },
      { year: 1984, month: 1, day: 10 },
    ]);
  });

  it("되짚은 날짜는 원래 팔자를 그대로 재현한다(왕복 검증)", () => {
    const [d] = inferSolarDatesFromPillars("경오", "무자", "임술", { maxYear: 2026 });
    const chart = computeSajuChart({
      calendarType: "solar",
      year: d.year,
      month: d.month,
      day: d.day,
      hour: 8,
      minute: 0,
      gender: "female",
    });
    expect(chart.year.ganZhi).toBe("경오");
    expect(chart.month.ganZhi).toBe("무자");
    expect(chart.day.ganZhi).toBe("임술");
  });

  it("맞는 날짜가 없으면 빈 배열", () => {
    // 연주와 월주 간지 조합이 오호둔 규칙상 불가능하면 후보 없음
    expect(inferSolarDatesFromPillars("갑자", "갑자", "갑자", { maxYear: 2026 })).toEqual([]);
  });

  it("팔자 입력 운 흐름은 대운을 비우고 세운/월운/일진은 채운다", () => {
    const chart = computeChartFromPillars({ year: "경오", month: "무자", day: "임술", hour: "갑진" });
    const luck = computeLuckFromPillars(chart, new Date("2026-07-07T03:00:00Z"), { includeMonthlyFlow: true });
    expect(luck.daYun).toEqual([]);
    expect(luck.currentDaYun).toBeNull();
    expect(luck.yearGanZhi).toBe("병오");
    expect(luck.monthGanZhi).toBeTruthy();
    expect(luck.dayGanZhi).toBeTruthy();
    expect(luck.monthlyFlow).toHaveLength(12);
  });
});
