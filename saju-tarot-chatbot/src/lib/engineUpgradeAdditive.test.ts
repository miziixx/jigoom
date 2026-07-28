import { describe, expect, it } from "vitest";
import { computeSajuChart, computeLuckCycles } from "./saju.js";
import type { BirthInfo } from "../types/index.js";

const REF = new Date("2026-07-03T03:00:00Z");

const BIRTH: BirthInfo = { calendarType: "solar", year: 1990, month: 12, day: 23, hour: 8, minute: 0, gender: "female" };
const NO_HOUR: BirthInfo = { calendarType: "solar", year: 1990, month: 12, day: 23, hour: null, gender: "female" };
const STAGES = ["장생", "목욕", "관대", "건록", "제왕", "쇠", "병", "사", "묘", "절", "태", "양"];

describe("#3 십이운성 구조화 (twelveStageDetails)", () => {
  it("지지 자리 수만큼 나오고, 각 항목 단계·뜻이 유효하다", () => {
    const chart = computeSajuChart(BIRTH);
    const d = chart.twelveStageDetails ?? [];
    expect(d.length).toBe(4); // 연지·월지·일지·시지
    for (const s of d) {
      expect(STAGES).toContain(s.stage);
      expect(s.gloss.length).toBeGreaterThan(0);
      expect(["연지", "월지", "일지", "시지"]).toContain(s.position);
    }
  });

  it("시간 모름이면 시지 없이 3자리", () => {
    const chart = computeSajuChart(NO_HOUR);
    const d = chart.twelveStageDetails ?? [];
    expect(d.length).toBe(3);
    expect(d.some((s) => s.position === "시지")).toBe(false);
  });

  it("기존 문자열 twelveStages와 자리·단계가 일치한다", () => {
    const chart = computeSajuChart(BIRTH);
    const fromString = (chart.twelveStages ?? []).map((s) => s.split(": ")[1]);
    const fromDetail = (chart.twelveStageDetails ?? []).map((s) => s.stage);
    expect(fromDetail).toEqual(fromString);
  });
});

describe("#5 궁위(자리) 해석 레이어 (palaces)", () => {
  it("4기둥 각각 삶의 영역·십신·오행이 매핑된다", () => {
    const p = computeSajuChart(BIRTH).palaces ?? [];
    expect(p.map((x) => x.pillar)).toEqual(["연주", "월주", "일주", "시주"]);
    for (const x of p) {
      expect(x.domains.length).toBeGreaterThan(0);
      expect(x.gloss.length).toBeGreaterThan(0);
      expect(["목", "화", "토", "금", "수"]).toContain(x.ganElement);
      expect(["목", "화", "토", "금", "수"]).toContain(x.zhiElement);
    }
  });

  it("일주 천간은 '일간(나 자신)'으로 표기된다", () => {
    const ilju = (computeSajuChart(BIRTH).palaces ?? []).find((x) => x.pillar === "일주");
    expect(ilju?.ganTenGod).toBe("일간(나 자신)");
    expect(ilju?.gan).toBe(computeSajuChart(BIRTH).dayMasterGan);
  });

  it("시간 모름이면 시주 궁위는 빠진다", () => {
    const p = computeSajuChart(NO_HOUR).palaces ?? [];
    expect(p.some((x) => x.pillar === "시주")).toBe(false);
    expect(p.length).toBe(3);
  });
});

describe("#1 신강신약 판정 투명화 (strength.transparency)", () => {
  it("관법 라벨·자리별 가중치·임계값을 공개한다", () => {
    const t = computeSajuChart(BIRTH).strength?.transparency;
    expect(t).toBeTruthy();
    expect(t!.method).toContain("억부");
    expect(t!.weights["월지"]).toBe(2.5); // 월지 최대 가중치
    expect(t!.thresholds).toEqual({ strong: 0.5, weak: 0.35 });
  });

  it("기여 내역 합이 supportScore/totalScore와 일치한다", () => {
    const chart = computeSajuChart(BIRTH);
    const s = chart.strength!;
    const t = s.transparency!;
    // 일간 자신은 기여 목록에서 제외되므로, 나머지 7자리(시주 있으면)
    const total = t.contributions.reduce((sum, c) => sum + c.weight, 0);
    const support = t.contributions.filter((c) => c.supportsDay).reduce((sum, c) => sum + c.weight, 0);
    expect(total).toBeCloseTo(s.totalScore, 5);
    expect(support).toBeCloseTo(s.supportScore, 5);
    expect(t.ratio).toBeCloseTo(support / total, 5);
  });

  it("라벨이 ratio·임계값과 일관된다", () => {
    const s = computeSajuChart(BIRTH).strength!;
    const t = s.transparency!;
    const expected = t.ratio >= t.thresholds.strong ? "신강" : t.ratio <= t.thresholds.weak ? "신약" : "중화";
    expect(s.label).toBe(expected);
  });
});

describe("#2 격국 판정 근거 (gyeokguk.candidates)", () => {
  it("월지 지장간 후보들이 점수와 함께 나오고, 채택 후보는 정확히 하나", () => {
    const g = computeSajuChart(BIRTH).gyeokguk!;
    const cands = g.candidates ?? [];
    expect(cands.length).toBeGreaterThan(0);
    expect(cands.filter((c) => c.chosen).length).toBe(1);
    for (const c of cands) {
      expect(["여기", "중기", "정기"]).toContain(c.phase);
      expect(typeof c.score).toBe("number");
    }
    // 채택 후보는 basisStem과 일치
    if (g.basisStem) expect(cands.find((c) => c.chosen)?.stem).toBe(g.basisStem);
    expect(g.ambiguityReason && g.ambiguityReason.length).toBeGreaterThan(0);
  });
});

describe("#6 대운-세운 생극합충 세분 (LuckOverlap.refined)", () => {
  it("대운·세운 천간 오행 생극 관계와 구조화 합충이 나온다", () => {
    const luck = computeLuckCycles(BIRTH, REF);
    const ov = luck.daYunYearOverlap;
    expect(ov?.refined).toBeTruthy();
    const r = ov!.refined!;
    // 2026 기준 현재 대운 갑신(목) · 세운 병오(화) → 목생화 → 대운생세운
    expect(r.daYunElement).toBe("목");
    expect(r.yearElement).toBe("화");
    expect(r.stemRelation).toBe("대운생세운");
    expect(r.stemRelationGloss.length).toBeGreaterThan(0);
    expect(Array.isArray(r.interactionDetails)).toBe(true);
  });
});
