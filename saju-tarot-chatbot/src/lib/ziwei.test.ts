import { describe, expect, it } from "vitest";
import { computeZiweiChart } from "./ziwei.js";
import type { BirthInfo } from "../types/index.js";

const birthA: BirthInfo = { calendarType: "solar", year: 1990, month: 12, day: 23, hour: 8, minute: 0, gender: "female" };
const birthB: BirthInfo = { calendarType: "solar", year: 1988, month: 5, day: 2, hour: 14, minute: 30, gender: "male" };

// 12궁 정식 이름 (iztro ko-KR)
const PALACE_NAMES = ["명궁", "형제", "부처", "자녀", "재백", "질액", "천이", "노복", "관록", "전택", "복덕", "부모"];

describe("computeZiweiChart (자미두수 래퍼)", () => {
  it("원식 12궁·명궁·오행국을 계산한다", () => {
    const c = computeZiweiChart(birthA)!;
    expect(c).not.toBeNull();
    expect(c.palaces).toHaveLength(12);
    expect(c.timeKnown).toBe(true);
    expect(c.source).toBe("iztro");
  });

  it("12궁 이름이 모두 정식 명칭이다", () => {
    const names = computeZiweiChart(birthA)!.palaces.map((p) => p.name).sort();
    expect(names).toEqual([...PALACE_NAMES].sort());
  });

  it("명궁 플래그와 명궁 지지가 일치한다", () => {
    const c = computeZiweiChart(birthA)!;
    const soul = c.palaces.find((p) => p.isSoul)!;
    expect(soul.name).toBe("명궁");
    expect(soul.branch).toBe(c.soulBranch);
  });

  // 골든 회귀: iztro 버전 변화나 매핑 실수를 잡기 위한 고정 스냅샷.
  // (docs/validation/ziwei-calculation-validation.md에 외부 대조 기준 명시)
  it("골든: 1990-12-23 08:00 여성 = 명궁 신 · 수이국", () => {
    const c = computeZiweiChart(birthA)!;
    expect(c.soulBranch).toBe("신");
    expect(c.fiveElementsClass).toBe("수이국");
  });

  it("골든: 1988-05-02 14:30 남성 = 목삼국", () => {
    const c = computeZiweiChart(birthB)!;
    expect(c.fiveElementsClass).toBe("목삼국");
    expect(c.palaces.find((p) => p.isSoul)!.branch).toBe(c.soulBranch);
  });

  it("결정론: 같은 입력이면 같은 결과", () => {
    expect(computeZiweiChart(birthA)).toEqual(computeZiweiChart(birthA));
  });

  it("출생 시간을 모르면(hour null) 명궁을 못 잡아 null을 반환한다", () => {
    expect(computeZiweiChart({ ...birthA, hour: null })).toBeNull();
  });

  it("음력 입력도 계산한다", () => {
    const c = computeZiweiChart({ calendarType: "lunar", year: 1990, month: 11, day: 7, hour: 8, minute: 0, isLeapMonth: false, gender: "female" });
    expect(c).not.toBeNull();
    expect(c!.palaces).toHaveLength(12);
  });

  it("주성에 묘왕리함 밝기(-3~+3)를 담는다", () => {
    const c = computeZiweiChart(birthA)!;
    const brights = c.palaces.flatMap((p) => p.majorStars.map((s) => s.brightness));
    expect(brights.length).toBeGreaterThan(0);
    for (const b of brights) {
      expect(b).toBeGreaterThanOrEqual(-3);
      expect(b).toBeLessThanOrEqual(3);
    }
    // 실제로 밝기 편차가 있어야 한다(전부 0이면 파싱 실패)
    expect(new Set(brights).size).toBeGreaterThan(1);
  });

  it("각 궁에 삼방사정 방조(대궁+삼합) 주성을 담는다", () => {
    const c = computeZiweiChart(birthA)!;
    expect(c.palaces.every((p) => Array.isArray(p.sanfangStars))).toBe(true);
    // 삼방에는 보통 주성이 실린다(전부 빈 경우는 드묾)
    expect(c.palaces.some((p) => p.sanfangStars.length > 0)).toBe(true);
  });

  it("사화(록·권·과·기)가 붙은 별을 보존한다", () => {
    const c = computeZiweiChart(birthB)!;
    const mutagens = c.palaces.flatMap((p) => p.majorStars.map((s) => s.mutagen)).filter(Boolean);
    // 어느 명식이든 사화 4개 중 최소 하나는 원식에 나타난다
    expect(mutagens.length).toBeGreaterThan(0);
    for (const m of mutagens) expect(["록", "권", "과", "기"]).toContain(m);
  });
});
