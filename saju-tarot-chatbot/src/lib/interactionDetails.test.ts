import { describe, expect, it } from "vitest";
import { computeSajuChart } from "./saju.js";
import type { BirthInfo, InteractionDetail } from "../types/index.js";

// 여러 원국으로 구조화 목록(interactionDetails)이 기존 문자열 목록(interactions)과
// 정확히 같은 관계·순서·라벨을 유지하는지 고정한다 (두 함수 동기화 보장).
const CASES: BirthInfo[] = [
  { calendarType: "solar", year: 1990, month: 12, day: 23, hour: 8, minute: 0, gender: "female" },
  { calendarType: "solar", year: 1985, month: 6, day: 15, hour: 14, minute: 0, gender: "female" },
  { calendarType: "solar", year: 2000, month: 1, day: 1, hour: 12, minute: 0, gender: "male" },
  { calendarType: "solar", year: 1984, month: 2, day: 5, hour: 2, minute: 0, gender: "male" },
];

describe("interactionDetails — 합충형파해 구조화 (#4)", () => {
  it("구조화 label 목록이 기존 interactions 문자열 목록과 정확히 일치한다", () => {
    for (const birth of CASES) {
      const chart = computeSajuChart(birth);
      const labels = (chart.interactionDetails ?? []).map((d) => d.label);
      expect(labels).toEqual(chart.interactions ?? []);
    }
  });

  it("각 항목의 구조 불변식: relation·gloss·resultElement 규칙", () => {
    const all: InteractionDetail[] = CASES.flatMap((b) => computeSajuChart(b).interactionDetails ?? []);
    expect(all.length).toBeGreaterThan(0); // 최소 한 케이스엔 관계가 있어야 테스트가 의미 있음

    const relations = new Set(["합", "충", "형", "파", "해"]);
    const heKinds = new Set(["천간합", "지지육합", "삼합", "반합", "방합"]);
    for (const d of all) {
      expect(relations.has(d.relation)).toBe(true);
      expect(d.gloss.length).toBeGreaterThan(0);
      expect(d.positions.length).toBeGreaterThanOrEqual(2);
      // 합류만 결과 오행을 가진다. 충/형/파/해는 없다.
      if (heKinds.has(d.kind)) {
        expect(d.resultElement).toBeTruthy();
        expect(d.relation).toBe("합");
      } else {
        expect(d.resultElement).toBeUndefined();
      }
    }
  });

  it("자오충이 있는 원국은 구조화에서도 kind=충 으로 잡힌다", () => {
    // 2000-01-01 12:00 → 자(월지)·오(일지) 자오충
    const chart = computeSajuChart(CASES[2]);
    const chong = (chart.interactionDetails ?? []).filter((d) => d.relation === "충");
    expect(chong.some((d) => d.chars.includes("자") && d.chars.includes("오"))).toBe(true);
  });
});
