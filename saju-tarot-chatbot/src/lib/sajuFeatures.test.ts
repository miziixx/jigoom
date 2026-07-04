import { describe, expect, it } from "vitest";
import { computeSajuChart, computeLuckCycles, computeCompatibility } from "./saju.js";
import type { BirthInfo } from "../types/index.js";

const female1990: BirthInfo = { calendarType: "solar", year: 1990, month: 12, day: 23, hour: 8, minute: 0, gender: "female" };

describe("신살 계산", () => {
  const chart = computeSajuChart(female1990);

  it("일주 임술은 백호·괴강 신살을 함께 가진다", () => {
    // 임술 일주는 백호대살(임술)이면서 괴강(임술)에 해당
    const names = chart.sinsal!.map((s) => s.name);
    expect(names).toContain("백호대살");
    expect(names).toContain("괴강");
  });

  it("십이신살을 일지 삼합국 기준으로 계산한다 (임술=화1990국)", () => {
    // 원국 경오 무자 임술 갑진 — 일지 술(인오술 火局): 오=장성살, 자=재살, 술=화개살, 진=월살
    const map = new Map((chart.sinsal ?? []).map((s) => [`${s.name}|${s.position}`, true]));
    expect(map.has("장성살|연지 오")).toBe(true);
    expect(map.has("재살|월지 자")).toBe(true);
    expect(map.has("화개살|일지 술")).toBe(true);
    expect(map.has("월살|시지 진")).toBe(true);
  });

  it("원진·귀문 지지쌍과 년살(도화)을 계산한다 (을축 임오 을유 계미)", () => {
    const c = computeSajuChart({ calendarType: "solar", year: 1985, month: 6, day: 15, hour: 14, minute: 0, gender: "female" });
    const names = (c.sinsal ?? []).map((s) => s.name);
    // 일지 유(사유축 金局): 오=년살(도화), 유=장성살, 축=화개살
    expect(names).toContain("년살");
    expect(names).toContain("장성살");
    // 연지 축–월지 오가 함께 있어 원진·귀문 성립
    expect(names).toContain("원진살");
    expect(names).toContain("귀문관살");
  });

  it("모든 신살 이름은 알려진 신살 집합 안에 있다", () => {
    const KNOWN = new Set([
      "겁살", "재살", "천살", "지살", "년살", "월살", "망신살", "장성살", "반안살", "역마살", "육해살", "화개살",
      "천을귀인", "천덕귀인", "월덕귀인", "양인", "문창귀인", "학당귀인", "금여", "암록", "홍염살",
      "백호대살", "괴강", "원진살", "귀문관살", "고신살", "과숙살",
    ]);
    for (const s of chart.sinsal ?? []) expect(KNOWN.has(s.name)).toBe(true);
  });

  it("모든 신살 항목은 이름·위치·뜻을 갖는다", () => {
    for (const s of chart.sinsal ?? []) {
      expect(s.name.length).toBeGreaterThan(0);
      expect(s.position.length).toBeGreaterThan(0);
      expect(s.gloss.length).toBeGreaterThan(0);
    }
  });

  it("천을귀인은 일간 기준 정해진 지지에만 잡힌다", () => {
    // 갑일간 + 축 지지 → 천을귀인
    const chart2 = computeSajuChart({ calendarType: "solar", year: 1984, month: 2, day: 5, hour: 2, gender: "male" });
    // 존재 여부와 무관하게, 천을귀인이 잡혔다면 위치 지지가 축/미 중 하나여야 함
    const cheoneul = (chart2.sinsal ?? []).filter((s) => s.name === "천을귀인");
    for (const s of cheoneul) {
      const dayGan = chart2.dayMasterGan;
      if (dayGan === "갑" || dayGan === "무" || dayGan === "경") {
        expect(s.position).toMatch(/[축미]/);
      }
    }
  });
});

describe("격국·희신", () => {
  const chart = computeSajuChart(female1990);
  it("격국이 판정된다", () => {
    expect(chart.gyeokguk).toBeDefined();
    expect(chart.gyeokguk!.name.length).toBeGreaterThan(0);
    expect(chart.gyeokguk!.basis).toContain("월지");
  });
  it("신강/신약이면 용신과 희신이 분리된다", () => {
    const weak = computeSajuChart({ calendarType: "solar", year: 1975, month: 6, day: 15, hour: 12, gender: "female" });
    if (weak.strength!.label !== "중화") {
      expect(weak.yongshin!.yongshin!.length).toBeGreaterThan(0);
      expect(weak.yongshin!.heesin!.length).toBeGreaterThan(0);
      // 용신과 희신은 겹치지 않아야 함
      for (const h of weak.yongshin!.heesin!) expect(weak.yongshin!.yongshin!).not.toContain(h);
    }
  });
});

describe("60갑자 일주 성향", () => {
  it("일주에 맞는 성향 문구가 붙는다", () => {
    const chart = computeSajuChart(female1990);
    expect(chart.iljuTrait).toBeDefined();
    expect(chart.iljuTrait!.length).toBeGreaterThan(5);
  });
});

describe("세운 다년", () => {
  const luck = computeLuckCycles(female1990, new Date("2026-07-03T03:00:00Z"));
  it("올해부터 10년치 세운을 만든다", () => {
    expect(luck.yearlyFlow).toHaveLength(10);
    expect(luck.yearlyFlow![0].year).toBe(2026);
    expect(luck.yearlyFlow![0].current).toBe(true);
    expect(luck.yearlyFlow![9].year).toBe(2035);
  });
  it("나이가 연도에 따라 증가한다", () => {
    const ages = luck.yearlyFlow!.map((y) => y.age);
    for (let i = 1; i < ages.length; i++) expect(ages[i]).toBe(ages[i - 1] + 1);
  });
});

describe("윤달·야자시", () => {
  it("윤달 여부에 따라 다른 원국이 나온다", () => {
    // 1987년은 음력 윤6월이 있는 해
    const normal = computeSajuChart({ calendarType: "lunar", year: 1987, month: 6, day: 15, hour: 12, gender: "male" });
    const leap = computeSajuChart({ calendarType: "lunar", year: 1987, month: 6, day: 15, hour: 12, gender: "male", isLeapMonth: true });
    expect(normal.month.ganZhi).not.toBe(leap.month.ganZhi);
  });

  it("23시 출생의 조자시/야자시는 일주가 달라진다", () => {
    const base = { calendarType: "solar" as const, year: 2000, month: 1, day: 1, hour: 23, minute: 30, gender: "male" as const };
    const late = computeSajuChart({ ...base, lateNightZi: "late" }); // 당일 일주
    const early = computeSajuChart({ ...base, lateNightZi: "early" }); // 다음날 일주
    expect(late.day.ganZhi).not.toBe(early.day.ganZhi);
  });
});

describe("궁합 계산", () => {
  const A = female1990;
  const B: BirthInfo = { calendarType: "solar", year: 1988, month: 5, day: 5, hour: 14, minute: 0, gender: "male" };
  const compat = computeCompatibility(A, B);

  it("0~100 점수와 세부 항목을 낸다", () => {
    expect(compat.score).toBeGreaterThanOrEqual(0);
    expect(compat.score).toBeLessThanOrEqual(100);
    expect(compat.breakdown.length).toBeGreaterThanOrEqual(4);
    expect(compat.dayMasterRelation.length).toBeGreaterThan(0);
    expect(compat.summary.length).toBeGreaterThan(0);
    expect(compat.partnerPalace?.body.length).toBeGreaterThan(0);
    expect(compat.roleChemistry).toHaveLength(2);
    expect(compat.purposeFits).toHaveLength(4);
    expect(compat.timing).toHaveLength(2);
    expect(compat.repairReport?.conflictCycle.length).toBeGreaterThanOrEqual(4);
    expect(compat.repairReport?.byPerson.me.length).toBeGreaterThanOrEqual(3);
    expect(compat.repairReport?.byPerson.partner.length).toBeGreaterThanOrEqual(3);
    expect(compat.repairReport?.scripts.length).toBeGreaterThanOrEqual(3);
    expect(compat.repairReport?.sevenDayPlan).toHaveLength(7);
  });

  it("세부 흐름·목적별 궁합에 '이럴 때 드러나요' 신호와 상세를 담는다", () => {
    for (const b of compat.breakdown) {
      expect(b.detail && b.detail.length).toBeGreaterThan(0);
      expect(b.signal && b.signal.length).toBeGreaterThan(0);
    }
    for (const fit of compat.purposeFits ?? []) {
      expect(fit.signal && fit.signal.length).toBeGreaterThan(0);
    }
  });

  it("종합 요약이 가장 강한 축을 구체적으로 짚는다", () => {
    const strongest = [...compat.breakdown].sort((x, y) => y.score - x.score)[0];
    expect(compat.summary).toContain(strongest.label);
  });

  it("교환해도 점수가 동일하다 (대칭성)", () => {
    const swapped = computeCompatibility(B, A);
    expect(swapped.score).toBe(compat.score);
  });

  it("관계 유형별 궁합 문맥을 바꿀 수 있다", () => {
    const family = computeCompatibility(A, B, "parentChild");
    const work = computeCompatibility(A, B, "bossEmployee");
    const rival = computeCompatibility(A, B, "rival");
    expect(family.relationLabel).toBe("부모와 자식");
    expect(work.purposeFits?.map((p) => p.label)).toContain("지시·보고");
    expect(rival.improvementTips?.join(" ")).toContain("사실");
  });

  it("결과 표면 문장에 사주 전문용어가 없다", () => {
    // 단독 '충/형/파/해'는 '균형' 등 일반어와 겹쳐 오탐이므로, 명확한 용어만 검사
    const JARGON = ["천간합", "육합", "삼합", "반합", "상생", "상극", "비화", "오행", "일간", "십성", "지지 관계", "지지 사이"];
    const surface = JSON.stringify({
      dayMasterRelation: compat.dayMasterRelation,
      branchRelations: compat.branchRelations,
      elementComplement: compat.elementComplement,
      summary: compat.summary,
      breakdown: compat.breakdown,
      partnerPalace: compat.partnerPalace?.body,
      roleChemistry: compat.roleChemistry?.map((r) => r.body),
      purposeFits: compat.purposeFits,
      timing: compat.timing?.map((t) => t.body),
      repairReport: compat.repairReport,
    });
    for (const w of JARGON) expect(surface, `궁합에 용어 노출: ${w}`).not.toContain(w);
  });
});
