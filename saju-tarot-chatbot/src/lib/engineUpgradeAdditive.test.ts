import { describe, expect, it } from "vitest";
import { computeSajuChart } from "./saju.js";
import type { BirthInfo } from "../types/index.js";

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
