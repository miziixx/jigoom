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

// 2순위: 대운·세운 십성/12운성/신살, 삼재 (모두 additive)
import { computeLuckCycles, sibiSinsalOf, samjaeBranchesOf } from "./saju.js";

describe("대운·세운 해석 필드 (십성·12운성·신살·삼재)", () => {
  const b: BirthInfo = { calendarType: "solar", year: 1985, month: 6, day: 15, hour: 14, minute: 0, gender: "female" };
  const luck = computeLuckCycles(b, new Date("2026-07-07"));

  it("각 대운에 십성·12운성·십이신살·공망 여부가 붙는다", () => {
    for (const dy of luck.daYun) {
      expect(dy.tenGod).toBeTruthy();
      expect(dy.twelveStage).toBeTruthy();
      expect(dy.sibiSinsal).toBeTruthy();
      expect(typeof dy.gongmang).toBe("boolean");
    }
    // 을유 대운: 일간 을 기준 유 지지 → 비견 / 절 / (일지 삼합국) 신살
    const eulYu = luck.daYun.find((d) => d.ganZhi === "을유");
    expect(eulYu?.tenGod).toBe("비견");
    expect(eulYu?.twelveStage).toBe("절");
  });

  it("세운(올해)에 십성·12운성이 붙는다 (2026 병오, 을목 기준)", () => {
    const cur = luck.yearlyFlow!.find((y) => y.current)!;
    expect(cur.ganZhi).toBe("병오");
    expect(cur.tenGod).toBe("상관"); // 을 → 병(화, 양) = 상관
    expect(cur.twelveStage).toBe("장생"); // 을 장생 = 오
  });

  it("삼재는 년지 삼합국 기준으로 계산된다 (축생 = 사유축국 → 해자축해)", () => {
    expect(luck.samjae).toBeDefined();
    expect(luck.samjae!.branches).toEqual(["해", "자", "축"]);
    expect(luck.samjae!.years.length).toBeGreaterThan(0);
    expect(luck.samjae!.years[0].phase).toBe("들삼재");
  });
});

describe("십이신살·삼재 순수 함수", () => {
  it("sibiSinsalOf: 일지 삼합국 기준 지살/역마 등을 반환한다", () => {
    expect(sibiSinsalOf("오", "인")).toBe("지살"); // 인오술 火국에서 인 = 지살
    expect(sibiSinsalOf("자", "인")).toBe("역마살"); // 신자진 水국에서 인 = 역마
  });

  it("samjaeBranchesOf: 삼합국별 삼재 지지 3개", () => {
    expect(samjaeBranchesOf("자").branches).toEqual(["인", "묘", "진"]); // 신자진生
    expect(samjaeBranchesOf("술").branches).toEqual(["신", "유", "술"]); // 인오술生
    expect(samjaeBranchesOf("진").phaseOf("묘")).toBe("눌삼재");
  });
});
