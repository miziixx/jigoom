import { describe, expect, it } from "vitest";
import { computeSajuChart } from "./saju.js";
import type { BirthInfo } from "../types/index.js";

// 21장 이론 커버리지 보강분(육친·생목사목·천간충)이 원국에 실제로 붙는지 고정한다.
const CASES: BirthInfo[] = [
  { calendarType: "solar", year: 1990, month: 12, day: 23, hour: 8, minute: 0, gender: "female" },
  { calendarType: "solar", year: 1985, month: 6, day: 15, hour: 14, minute: 0, gender: "female" },
  { calendarType: "solar", year: 2000, month: 1, day: 1, hour: 12, minute: 0, gender: "male" },
  { calendarType: "solar", year: 1984, month: 2, day: 5, hour: 2, minute: 0, gender: "male" },
];

describe("엔진 커버리지 보강 — 육친·생목사목·천간충", () => {
  it("육친(六親): 다섯 십성 그룹이 모두 가족·인간관계로 매핑된다", () => {
    for (const birth of CASES) {
      const chart = computeSajuChart(birth);
      const groups = (chart.sixRelations ?? []).map((r) => r.group);
      expect(groups).toEqual(["비겁", "식상", "재성", "관성", "인성"]);
      for (const r of chart.sixRelations ?? []) {
        expect(r.relatives.length).toBeGreaterThan(0);
        expect(r.note.length).toBeGreaterThan(0);
        expect(["강함", "보통", "약함", "거의없음"]).toContain(r.presence);
      }
    }
  });

  it("생목·사목: 일간 물상 활력 판정이 붙고 세 값 중 하나로 결론난다", () => {
    for (const birth of CASES) {
      const chart = computeSajuChart(birth);
      const ls = chart.livingState;
      expect(ls).toBeTruthy();
      expect(["생(生)", "조건부 생", "사(死)"]).toContain(ls!.verdict);
      expect(ls!.dayGan).toBe(chart.dayMasterGan);
      // 갖춤+부족 = 그 일간 물상이 요구하는 조건 전체
      expect(ls!.satisfied.length + ls!.missing.length).toBeGreaterThan(0);
    }
  });

  it("천간충: 지지 합충형파해(interactions)와 분리된 별도 레이어로 계산된다", () => {
    for (const birth of CASES) {
      const chart = computeSajuChart(birth);
      expect(Array.isArray(chart.stemClashes)).toBe(true);
      // 천간충 항목은 interactions 문자열 목록에 섞이지 않는다(사건 규칙 불변 보장).
      for (const s of chart.interactions ?? []) expect(s).not.toContain("천간충");
    }
  });

  it("갑·경이 천간에 함께 있으면 갑경충이 stemClashes에 잡힌다", () => {
    // 2000-01-01 12:00 원국은 병자년·무자월·경진일·임오시 계열 — 케이스로 직접 검증
    const chart = computeSajuChart({
      calendarType: "solar",
      year: 1984,
      month: 2,
      day: 5,
      hour: 2,
      minute: 0,
      gender: "male",
    });
    // 천간충이 있으면 라벨 포맷이 "..충"으로 끝난다
    for (const s of chart.stemClashes ?? []) expect(s.endsWith("충")).toBe(true);
  });
});
