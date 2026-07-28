import { describe, expect, it } from "vitest";
import { basicReadingBlocks, buildBasicReading } from "./basicReadingRenderer.js";
import { computeSajuChart, computeLuckCycles } from "./saju.js";
import type { BirthInfo } from "../types/index.js";

const birth: BirthInfo = { calendarType: "solar", year: 1990, month: 12, day: 23, hour: 8, minute: 0, gender: "female" };
const chart = computeSajuChart(birth);
const luck = computeLuckCycles(birth, new Date("2026-07-03T03:00:00Z"), { includeMonthlyFlow: true });

describe("buildBasicReading (무료 기본 리딩 룰 렌더러, §8)", () => {
  it("원국·대운이 있으면 블록 2~6이 채워진다 (블록 1은 C-1 전까지 항상 null)", () => {
    const reading = buildBasicReading({ sajuChart: chart, luckCycles: luck, gender: "female" });
    expect(reading.gooseBumpCheck).toBeNull();
    expect(reading.snapshot).not.toBeNull();
    expect(reading.userManual).not.toBeNull();
    expect(reading.domainSignals).not.toBeNull();
    expect(reading.yearFlow).not.toBeNull();
    expect(reading.lifestyle).not.toBeNull();
  });

  it("입력이 없으면 API 호출 없이도 안전하게 빈 상태를 반환한다", () => {
    const reading = buildBasicReading({});
    expect(reading.gooseBumpCheck).toBeNull();
    expect(reading.snapshot).toBeNull();
    expect(reading.userManual).toBeNull();
    expect(reading.domainSignals).toBeNull();
    expect(reading.yearFlow).toBeNull();
    expect(reading.lifestyle).toBeNull();
  });

  it("결정론: 같은 입력이면 같은 블록 구성 (generatedAt 제외)", () => {
    const a = buildBasicReading({ sajuChart: chart, luckCycles: luck, gender: "female" });
    const b = buildBasicReading({ sajuChart: chart, luckCycles: luck, gender: "female" });
    const strip = (r: typeof a) => ({ ...r, generatedAt: "" });
    expect(strip(a)).toEqual(strip(b));
  });

  it("basicReadingBlocks는 채워진 블록만 순서대로 돌려준다 (최대 5개, 소름 검증 제외)", () => {
    const reading = buildBasicReading({ sajuChart: chart, luckCycles: luck, gender: "female" });
    const blocks = basicReadingBlocks(reading);
    expect(blocks.length).toBeGreaterThan(0);
    expect(blocks.length).toBeLessThanOrEqual(5);
    expect(blocks.map((b) => b.key)).toEqual(["snapshot", "userManual", "domainSignals", "yearFlow", "lifestyle"]);
  });

  it("블록 7 CTA(deepDiveCta)는 소름 검증을 제외한 각 블록에 유료 진입점을 갖는다", () => {
    const reading = buildBasicReading({ sajuChart: chart, luckCycles: luck, gender: "female" });
    for (const block of basicReadingBlocks(reading)) {
      if (block.key === "snapshot") continue; // 원국 스냅샷은 이미 CalculationEvidenceZone에서 별도 노출, CTA 없음
      expect(block.deepDiveCta).not.toBeNull();
    }
  });

  it("월별 데이터가 없으면 yearFlow 블록은 null (강제로 빈 캘린더를 만들지 않는다)", () => {
    const luckNoMonths = { ...luck, monthlyFlow: [] };
    const reading = buildBasicReading({ sajuChart: chart, luckCycles: luckNoMonths, gender: "female" });
    expect(reading.yearFlow).toBeNull();
  });
});
