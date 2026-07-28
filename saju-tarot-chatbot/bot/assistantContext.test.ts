import { describe, it, expect } from "vitest";
import { buildSajuSummary, buildAssistantContext } from "./assistantContext.js";
import { birthSource } from "./evidence.js";
import type { BirthInfo } from "../src/types/index.js";

const birthInfo: BirthInfo = {
  calendarType: "solar",
  year: 1993,
  month: 3,
  day: 15,
  hour: 14,
  minute: 30,
  birthPlace: "seoul",
  gender: "female",
};

describe("buildSajuSummary", () => {
  it("원국 계산 결과를 스펙 형태로 압축한다", () => {
    const summary = buildSajuSummary(birthSource(birthInfo));
    expect(summary.fourPillars.split(" ").length).toBe(4);
    expect(summary.dayMaster).toBeTruthy();
    expect(summary.fiveElementsBalance).toContain("목");
    expect(summary.currentYearFlow).toContain("세운");
    expect(Array.isArray(summary.cautionPoints)).toBe(true);
  });
});

describe("buildAssistantContext", () => {
  it("사주+점성술+의도+기억을 하나의 컨텍스트로 병합한다", () => {
    const ctx = buildAssistantContext({
      chartSource: birthSource(birthInfo),
      birthInfo,
      detectedIntent: "planning",
      memories: [{ id: "1", category: "projectMemory", summary: "앱 이름은 nemo", sensitive: false, createdAt: "2026-01-01" }],
      currentQuestion: "이거 앱으로 만들고 싶어",
    });
    expect(ctx.sajuSummary).not.toBeNull();
    expect(ctx.astrologySummary).not.toBeNull();
    expect(ctx.detectedIntent).toBe("planning");
    expect(ctx.savedMemorySummary).toEqual(["[projectMemory] 앱 이름은 nemo"]);
    expect(ctx.securityLevel).toBe("normal");
  });

  it("생년월일시가 없으면(팔자만 등록) astrologySummary는 null", () => {
    const ctx = buildAssistantContext({
      chartSource: null,
      birthInfo: null,
      detectedIntent: "generalChat",
      memories: [],
      currentQuestion: "안녕",
    });
    expect(ctx.astrologySummary).toBeNull();
    expect(ctx.sajuSummary).toBeNull();
  });

  it("민감 키워드가 있으면 securityLevel을 올린다", () => {
    const ctx = buildAssistantContext({
      chartSource: null,
      birthInfo: null,
      detectedIntent: "decision",
      memories: [],
      currentQuestion: "이혼해야 할지 고민돼",
    });
    expect(ctx.securityLevel).toBe("sensitive");
  });
});
