import { describe, expect, it } from "vitest";
import { computeSajuChart } from "./saju.js";
import { independentDayPillar, independentHourPillar } from "./manseIndependentCheck.js";
import type { BirthInfo } from "../types/index.js";

/**
 * 독립 알고리즘 vs 앱 엔진 교차검증.
 *
 * 각 케이스에서 `computeSajuChart`(lunar-javascript)가 내는 일주/시주가,
 * JDN 60갑자 + 五鼠遁으로 독립 계산한 값과 일치해야 한다.
 * `dayDate`/`hourGan`/`corrHour`는 자시 처리·진태양시/서머타임 보정의 기대 동작을
 * 문서화한 픽스처다. 엔진의 일주/시주가 바뀌거나 독립 산식이 바뀌면 실패한다.
 * (docs/validation/external-manse-comparison.md 참조)
 */
interface Case {
  name: string;
  birth: BirthInfo;
  /** 일주 귀속 양력일 (음력은 변환일, 조자시는 익일) */
  dayDate: [number, number, number];
  /** 시주 五鼠遁에 쓰는 일간 (야자시는 익일 일간) */
  hourGan: string;
  /** 보정 후 지역시 (시간 모름이면 null) */
  corrHour: number | null;
}

const cases: Case[] = [
  {
    name: "양력 표준 1990-12-23 08:00 여",
    birth: { calendarType: "solar", year: 1990, month: 12, day: 23, hour: 8, minute: 0, gender: "female" },
    dayDate: [1990, 12, 23], hourGan: "임", corrHour: 8,
  },
  {
    name: "입춘 직후 1984-02-05 02:00 남",
    birth: { calendarType: "solar", year: 1984, month: 2, day: 5, hour: 2, minute: 0, gender: "male" },
    dayDate: [1984, 2, 5], hourGan: "기", corrHour: 2,
  },
  {
    name: "음력 평달 1987 음6/15 12:00 남 (양 1987-07-10, 서머타임 -60→11시)",
    birth: { calendarType: "lunar", year: 1987, month: 6, day: 15, hour: 12, minute: 0, isLeapMonth: false, gender: "male" },
    dayDate: [1987, 7, 10], hourGan: "경", corrHour: 11,
  },
  {
    name: "음력 윤달 1987 음윤6/15 12:00 남 (양 1987-08-09, 서머타임 -60→11시)",
    birth: { calendarType: "lunar", year: 1987, month: 6, day: 15, hour: 12, minute: 0, isLeapMonth: true, gender: "male" },
    dayDate: [1987, 8, 9], hourGan: "경", corrHour: 11,
  },
  {
    name: "야자시 2000-01-01 23:30 남 (일주 당일, 시주 익일 자시)",
    birth: { calendarType: "solar", year: 2000, month: 1, day: 1, hour: 23, minute: 30, lateNightZi: "late", gender: "male" },
    dayDate: [2000, 1, 1], hourGan: "기", corrHour: 23,
  },
  {
    name: "조자시 2000-01-01 23:30 남 (일주 익일)",
    birth: { calendarType: "solar", year: 2000, month: 1, day: 1, hour: 23, minute: 30, lateNightZi: "early", gender: "male" },
    dayDate: [2000, 1, 2], hourGan: "기", corrHour: 23,
  },
  {
    name: "서머타임+경도 1988-06-01 12:00 남 서울 (보정 10:28)",
    birth: { calendarType: "solar", year: 1988, month: 6, day: 1, hour: 12, minute: 0, birthPlace: "seoul", gender: "male" },
    dayDate: [1988, 6, 1], hourGan: "정", corrHour: 10,
  },
];

describe("독립 간지 검산 (lunar-javascript 무관) vs 앱 엔진", () => {
  for (const c of cases) {
    it(`${c.name}: 일주·시주가 독립 산식과 일치`, () => {
      const chart = computeSajuChart(c.birth);
      const indDay = independentDayPillar(...c.dayDate);
      expect(chart.day.ganZhi).toBe(indDay);
      if (c.corrHour !== null) {
        expect(chart.hour).not.toBeNull();
        expect(chart.hour!.ganZhi).toBe(independentHourPillar(c.hourGan, c.corrHour));
      }
    });
  }

  it("앵커(1990-12-23)는 임술이어야 한다 — 외부 3곳 교차확인값", () => {
    expect(independentDayPillar(1990, 12, 23)).toBe("임술");
  });
});
