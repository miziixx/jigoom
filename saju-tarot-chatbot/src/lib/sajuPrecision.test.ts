import { describe, expect, it } from "vitest";
import { computeSajuChart } from "./saju.js";
import type { BirthInfo } from "../types/index.js";

// 1순위 정밀도: 월률분야(사령) · 격국 투출/사령 · 한난 조후

describe("월률분야(사령)", () => {
  it("절입 경과일로 월지 지장간 중 사령을 정한다 (자월 15일차 → 정기 계)", () => {
    const c = computeSajuChart({ calendarType: "solar", year: 1990, month: 12, day: 23, hour: 8, minute: 0, gender: "female" });
    expect(c.monthCommand).toBeDefined();
    expect(c.monthCommand!.monthZhi).toBe("자");
    expect(c.monthCommand!.stem).toBe("계");
    expect(c.monthCommand!.phase).toBe("정기");
    // 임수 일간 기준 계수 = 겁재
    expect(c.monthCommand!.tenGod).toBe("겁재");
    expect(c.monthCommand!.daysSinceTerm).toBeGreaterThan(0);
    expect(c.monthCommand!.termName).toBe("大雪");
  });

  it("절입 직후 출생이면 여기가 사령한다 (입춘 0일차 인월 → 여기 무)", () => {
    const c = computeSajuChart({ calendarType: "solar", year: 1984, month: 2, day: 5, hour: 2, minute: 0, gender: "male" });
    expect(c.monthCommand!.monthZhi).toBe("인");
    expect(c.monthCommand!.stem).toBe("무");
    expect(c.monthCommand!.phase).toBe("여기");
    expect(c.monthCommand!.daysSinceTerm).toBeLessThan(1);
  });
});

describe("격국 — 투출/사령 기반", () => {
  it("월지 정기가 투출하면 정기로 격을 잡는다 (기토 인월, 갑목 투출 → 정관격)", () => {
    const c = computeSajuChart({ calendarType: "solar", year: 1984, month: 2, day: 5, hour: 2, minute: 0, gender: "male" });
    expect(c.gyeokguk!.basisKind).toBe("정기 투출");
    expect(c.gyeokguk!.basisStem).toBe("갑");
    expect(c.gyeokguk!.name).toBe("정관격");
  });

  it("정기가 불투하고 지장간이 투출하면 그 투출자로 격을 잡는다 (자월, 임수 투출)", () => {
    const c = computeSajuChart({ calendarType: "solar", year: 1990, month: 12, day: 23, hour: 8, minute: 0, gender: "female" });
    expect(c.gyeokguk!.basisKind).toBe("지장간 투출");
    expect(c.gyeokguk!.basisStem).toBe("임");
  });

  it("월지 지장간이 하나도 투출하지 않으면 사령으로 격을 잡는다 (오월, 투출 없음)", () => {
    const c = computeSajuChart({ calendarType: "solar", year: 1985, month: 6, day: 15, hour: 14, minute: 0, gender: "female" });
    expect(c.gyeokguk!.basisKind).toBe("사령(잠복)");
    // 오월 9.5일차 사령 = 여기 병 → 을목 기준 상관
    expect(c.gyeokguk!.basisStem).toBe("병");
    expect(c.gyeokguk!.name).toBe("상관격");
  });

  it("basis 문자열에는 여전히 '월지'가 들어간다", () => {
    const c = computeSajuChart({ calendarType: "solar", year: 1990, month: 12, day: 23, hour: 8, minute: 0, gender: "female" });
    expect(c.gyeokguk!.basis).toContain("월지");
  });
});

describe("조후 — 계절·일간 한난", () => {
  const mk = (b: Partial<BirthInfo>): BirthInfo => ({ calendarType: "solar", year: 1990, month: 1, day: 1, hour: 12, minute: 0, gender: "male", ...b });

  it("차가운 사주는 화를 조후로 (겨울 임수)", () => {
    const c = computeSajuChart(mk({ year: 1990, month: 12, day: 23, hour: 8, gender: "female" }));
    expect(c.yongshin!.climatic!.element).toBe("화");
  });

  it("더운 사주는 수를 조후로 (여름 을목 오월)", () => {
    const c = computeSajuChart(mk({ year: 1985, month: 6, day: 15, hour: 14, gender: "female" }));
    expect(c.yongshin!.climatic!.element).toBe("수");
  });

  it("한난이 크게 치우치지 않으면 조후를 강제하지 않는다 (가을 병화 유월)", () => {
    const c = computeSajuChart(mk({ year: 1980, month: 9, day: 20, hour: 10 }));
    // 병화(더운 일간)가 서늘한 가을을 상쇄 → 조후 부담 적음
    expect(c.yongshin!.climatic ?? null).toBeNull();
  });
});
