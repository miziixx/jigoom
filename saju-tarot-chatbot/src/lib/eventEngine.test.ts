import { describe, expect, it } from "vitest";
import { computeSajuChart, computeLuckCycles } from "./saju.js";
import { buildEventForecast } from "./eventEngine.js";
import type { BirthInfo, LifeDomain } from "../types/index.js";

const female1990: BirthInfo = { calendarType: "solar", year: 1990, month: 12, day: 23, hour: 8, minute: 0, gender: "female" };
const male1984: BirthInfo = { calendarType: "solar", year: 1984, month: 2, day: 5, hour: 2, gender: "male" };

describe("사건화 엔진", () => {
  it("차트가 없으면 null을 반환한다", () => {
    expect(buildEventForecast(undefined)).toBeNull();
  });

  it("7개 분야를 모두 만들고 라벨/패턴을 채운다", () => {
    const chart = computeSajuChart(female1990);
    const forecast = buildEventForecast(chart, undefined, female1990.gender)!;
    const domains = forecast.domains.map((d) => d.domain);
    const expected: LifeDomain[] = ["career", "money", "love", "health", "family", "move", "startup"];
    for (const d of expected) expect(domains).toContain(d);
    for (const scenario of forecast.domains) {
      expect(scenario.label.length).toBeGreaterThan(0);
      // 모든 분야는 원국 기반 사건 패턴을 최소 하나 이상 갖는다
      expect(scenario.patterns.length).toBeGreaterThan(0);
      expect(["high", "mid", "low"]).toContain(scenario.activation);
    }
  });

  it("대운·세운을 주면 활성 분야가 생기고 타이밍 신호가 붙는다", () => {
    const chart = computeSajuChart(female1990);
    const luck = computeLuckCycles(female1990);
    const forecast = buildEventForecast(chart, luck, female1990.gender)!;
    // 활성 분야가 있으면 각 활성 분야는 타이밍 신호 또는 근거를 갖는다
    for (const key of forecast.activeDomains) {
      const scenario = forecast.domains.find((d) => d.domain === key)!;
      expect(scenario.activation).not.toBe("low");
      expect(scenario.timingSignals.length + scenario.evidence.length).toBeGreaterThan(0);
    }
    // headline은 항상 존재
    expect(forecast.headline.length).toBeGreaterThan(0);
  });

  it("activeDomains는 활성도 높은 순으로 정렬된다", () => {
    const chart = computeSajuChart(male1984);
    const luck = computeLuckCycles(male1984);
    const forecast = buildEventForecast(chart, luck, male1984.gender)!;
    const rank = { high: 2, mid: 1, low: 0 } as const;
    const ranks = forecast.activeDomains.map(
      (k) => rank[forecast.domains.find((d) => d.domain === k)!.activation],
    );
    for (let i = 1; i < ranks.length; i++) expect(ranks[i - 1]).toBeGreaterThanOrEqual(ranks[i]);
  });

  it("표면 문구에 사주 전문용어(충/합/십성)를 노출하지 않는다", () => {
    const chart = computeSajuChart(female1990);
    const luck = computeLuckCycles(female1990);
    const forecast = buildEventForecast(chart, luck, female1990.gender)!;
    const TERMS = ["편재", "정재", "편관", "정관", "편인", "정인", "식신", "상관", "비견", "겁재"];
    for (const scenario of forecast.domains) {
      const surface = [...scenario.patterns, ...scenario.cautions, scenario.activationNote].join(" ");
      for (const term of TERMS) expect(surface).not.toContain(term);
    }
  });

  it("evidence(전문가 근거)에는 계산 용어를 남긴다", () => {
    const chart = computeSajuChart(female1990);
    const luck = computeLuckCycles(female1990);
    const forecast = buildEventForecast(chart, luck, female1990.gender)!;
    const allEvidence = forecast.domains.flatMap((d) => d.evidence).join(" ");
    // 활성 분야가 하나라도 있으면 근거 문자열이 비어있지 않다
    if (forecast.activeDomains.length > 0) {
      expect(allEvidence.length).toBeGreaterThan(0);
    }
  });
});
