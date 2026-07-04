import { describe, expect, it } from "vitest";
import { buildInstantSummary } from "./instantSummary.js";
import type { LuckCycles, SajuChart } from "../types/index.js";

const baseChart: SajuChart = {
  year: { gan: "甲", zhi: "子", ganZhi: "甲子" },
  month: { gan: "丙", zhi: "寅", ganZhi: "丙寅" },
  day: { gan: "戊", zhi: "午", ganZhi: "戊午" },
  hour: null,
  fiveElements: { wood: 3, fire: 2, earth: 2, metal: 0, water: 1 },
  tenGods: [],
  dayMasterGan: "戊",
};

describe("buildInstantSummary", () => {
  it("근거가 없으면 null", () => {
    expect(buildInstantSummary(undefined, undefined)).toBeNull();
  });

  it("가장 강한 오행과 비어 있는 오행을 쉬운 말로 요약한다", () => {
    const summary = buildInstantSummary(baseChart);
    expect(summary).not.toBeNull();
    const labels = summary!.lines.map((l) => l.label);
    expect(labels).toContain("타고난 중심");
    expect(labels).toContain("채우면 좋은 결"); // metal=0
    // 표면 문장에 전문용어(간지)가 노출되지 않아야 한다
    const joined = summary!.lines.map((l) => l.text).join(" ");
    expect(joined).not.toMatch(/甲|丙|戊|충|합/);
  });

  it("신강/신약 라벨을 문장으로 옮긴다", () => {
    const summary = buildInstantSummary({
      ...baseChart,
      strength: { supportScore: 5, totalScore: 8, label: "신약", detail: "" },
    });
    const strengthLine = summary!.lines.find((l) => l.label === "힘의 균형");
    expect(strengthLine?.text).toContain("협력");
  });

  it("올해 상호작용이 많으면 변화 흐름으로 안내한다", () => {
    const luck: LuckCycles = {
      daYun: [],
      currentDaYun: null,
      yearGanZhi: "丙午",
      monthGanZhi: "甲午",
      year: 2026,
      month: 7,
      luckInteractions: ["세운-일지 충", "세운-월지 형"],
    };
    const summary = buildInstantSummary(baseChart, luck);
    const yearLine = summary!.lines.find((l) => l.label === "올해 흐름");
    expect(yearLine?.text).toContain("변화");
  });
});
