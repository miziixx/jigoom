import { computeSajuChart, computeLuckCycles } from "../src/lib/saju.js";
import type { BirthInfo } from "../src/types/index.js";

const REF = new Date("2026-07-03T03:00:00Z"); // 대운/세운 기준 고정일 (KST 2026-07-03 12:00)

type Case = { name: string; birth: BirthInfo };

const cases: Case[] = [
  {
    name: "1. 양력 표준 (1990-12-23 08:00 여)",
    birth: { calendarType: "solar", year: 1990, month: 12, day: 23, hour: 8, minute: 0, gender: "female" },
  },
  {
    name: "2. 입춘 직후 (1984-02-05 02:00 남)",
    birth: { calendarType: "solar", year: 1984, month: 2, day: 5, hour: 2, minute: 0, gender: "male" },
  },
  {
    name: "3. 음력 평달 (1987 음 6/15 12:00 남)",
    birth: { calendarType: "lunar", year: 1987, month: 6, day: 15, hour: 12, minute: 0, isLeapMonth: false, gender: "male" },
  },
  {
    name: "4. 음력 윤달 (1987 음 윤6/15 12:00 남)",
    birth: { calendarType: "lunar", year: 1987, month: 6, day: 15, hour: 12, minute: 0, isLeapMonth: true, gender: "male" },
  },
  {
    name: "5. 야자시 (2000-01-01 23:30 남, late)",
    birth: { calendarType: "solar", year: 2000, month: 1, day: 1, hour: 23, minute: 30, lateNightZi: "late", gender: "male" },
  },
  {
    name: "6. 조자시 (2000-01-01 23:30 남, early)",
    birth: { calendarType: "solar", year: 2000, month: 1, day: 1, hour: 23, minute: 30, lateNightZi: "early", gender: "male" },
  },
  {
    name: "7. 서머타임+출생지 (1988-06-01 12:00 남, 서울)",
    birth: { calendarType: "solar", year: 1988, month: 6, day: 1, hour: 12, minute: 0, birthPlace: "seoul", gender: "male" },
  },
];

for (const c of cases) {
  const chart = computeSajuChart(c.birth);
  const luck = computeLuckCycles(c.birth, REF);
  const cur = luck.daYun.find((d) => d.current);
  const first = luck.daYun[0];
  const pillars = [
    chart.year.ganZhi,
    chart.month.ganZhi,
    chart.day.ganZhi,
    chart.hour ? chart.hour.ganZhi : "(시주없음)",
  ].join("/");
  console.log(`\n### ${c.name}`);
  console.log(`  연월일시주 : ${pillars}`);
  console.log(`  일간       : ${chart.dayMasterGan}`);
  console.log(`  대운시작   : ${first ? `${first.startAge}세, ${first.startYear}년` : "-"}`);
  console.log(`  현재대운   : ${luck.currentDaYun ?? "-"}${cur ? ` (${cur.startAge}~${cur.endAge}세)` : ""}`);
  console.log(`  세운(2026) : ${luck.yearGanZhi}`);
  if (chart.timeCorrection) console.log(`  시간보정   : ${chart.timeCorrection.applied.join(", ")} → ${chart.timeCorrection.correctedDateTime}`);
}
