import { describe, expect, it } from "vitest";
import { buildCrossValidation } from "./crossValidation.js";
import { computeZiweiChart } from "./ziwei.js";
import { computeSajuChart, computeLuckCycles } from "./saju.js";
import { buildReadingUserMessage } from "../prompts/systemPrompt.js";
import type { BirthInfo } from "../types/index.js";

const birth: BirthInfo = { calendarType: "solar", year: 1990, month: 12, day: 23, hour: 8, minute: 0, gender: "female" };
const saju = computeSajuChart(birth);
const luck = computeLuckCycles(birth, new Date("2026-07-08T03:00:00Z"));
const ziwei = computeZiweiChart(birth);

describe("buildCrossValidation (사주·자미두수 교차검증)", () => {
  it("자미두수 차트가 없으면 null", () => {
    expect(buildCrossValidation(saju, null, luck, "female")).toBeNull();
  });

  it("두 방식이 다 판정하는 분야에 대해 일치 레벨을 낸다", () => {
    const r = buildCrossValidation(saju, ziwei, luck, "female")!;
    expect(r).not.toBeNull();
    expect(r.matches.length).toBeGreaterThan(0);
    expect(r.agreementScore).toBeGreaterThanOrEqual(0);
    expect(r.agreementScore).toBeLessThanOrEqual(100);
    for (const m of r.matches) {
      expect(["강일치", "부분일치", "불일치"]).toContain(m.level);
      expect(["좋음", "보통", "주의"]).toContain(m.sajuTone);
      expect(["좋음", "보통", "주의"]).toContain(m.ziweiTone);
      // 강일치는 두 tone이 같아야 한다
      if (m.level === "강일치") expect(m.sajuTone).toBe(m.ziweiTone);
      // 불일치는 좋음↔주의만
      if (m.level === "불일치") expect(new Set([m.sajuTone, m.ziweiTone])).toEqual(new Set(["좋음", "주의"]));
    }
  });

  it("결정론: 같은 입력이면 같은 결과", () => {
    expect(buildCrossValidation(saju, ziwei, luck, "female")).toEqual(buildCrossValidation(saju, ziwei, luck, "female"));
  });

  it("agreementScore는 강일치 비율과 일치한다", () => {
    const r = buildCrossValidation(saju, ziwei, luck, "female")!;
    const strong = r.matches.filter((m) => m.level === "강일치").length;
    expect(r.agreementScore).toBe(Math.round((strong / r.matches.length) * 100));
  });
});

describe("systemPrompt 배선: 교차검증 블록", () => {
  it("crossValidation이 있으면 사주 리딩(front)에 압축 블록·활용 안내를 전달한다", () => {
    const cv = buildCrossValidation(saju, ziwei, luck, "female")!;
    const msg = buildReadingUserMessage({ type: "saju", question: "요즘 어때요?", gender: "female", sajuChart: saju, luckCycles: luck, crossValidation: cv });
    expect(msg).toContain("[교차검증 — 사주·자미두수 — 계산됨");
    expect(msg).toContain("교차검증 활용 안내");
  });

  it("팬아웃 back 호출에는 교차검증 블록이 붙지 않는다", () => {
    const cv = buildCrossValidation(saju, ziwei, luck, "female")!;
    const msg = buildReadingUserMessage({ type: "saju", question: "요즘 어때요?", gender: "female", sajuChart: saju, luckCycles: luck, crossValidation: cv, sectionGroup: "back" });
    expect(msg).not.toContain("[교차검증 — 사주·자미두수 — 계산됨");
  });

  it("crossValidation이 없으면 블록이 없다(자미두수 미계산 시 무해)", () => {
    const msg = buildReadingUserMessage({ type: "saju", question: "요즘 어때요?", gender: "female", sajuChart: saju, luckCycles: luck });
    expect(msg).not.toContain("[교차검증 — 사주·자미두수 — 계산됨");
  });

  it("교차검증 블록은 압축적이다(<1500자)", () => {
    const cv = buildCrossValidation(saju, ziwei, luck, "female")!;
    const msg = buildReadingUserMessage({ type: "saju", question: "요즘 어때요?", gender: "female", sajuChart: saju, luckCycles: luck, crossValidation: cv });
    const start = msg.indexOf("[교차검증 — 사주·자미두수 — 계산됨");
    const block = msg.slice(start, start + 2000);
    const evidenceBlock = block.split("[교차검증 활용 안내]")[0];
    expect(evidenceBlock.length).toBeLessThan(1500);
  });
});
