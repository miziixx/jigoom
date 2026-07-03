import { describe, expect, it } from "vitest";
import { READING_SYSTEM_PROMPT, buildReadingUserMessage } from "./systemPrompt.js";
import { computeSajuChart, computeLuckCycles } from "../lib/saju.js";
import type { BirthInfo } from "../types/index.js";

describe("리딩 시스템 프롬프트 규칙", () => {
  it("사주 전문용어 금지 규칙을 담는다", () => {
    expect(READING_SYSTEM_PROMPT).toContain("사주 전문용어를 사용자에게 보이는 문장에 절대 쓰지 않는다");
  });
  it("마크다운 금지 규칙을 담는다", () => {
    expect(READING_SYSTEM_PROMPT).toContain("마크다운 기호를 쓰지 않는다");
  });
  it("몰입 섹션 구조(첫 점괘~마지막 점괘)를 담는다", () => {
    for (const s of ["# 첫 점괘", "# 지금 내 마음", "# 말하지 않은 고민", "# 겉과 속", "# 마지막 점괘"]) {
      expect(READING_SYSTEM_PROMPT).toContain(s);
    }
  });
  it("안전 규칙(단정·무속 금지)을 유지한다", () => {
    expect(READING_SYSTEM_PROMPT).toContain("반드시/무조건/100%/절대");
    expect(READING_SYSTEM_PROMPT).toContain("무속");
  });
});

describe("근거 직렬화(LLM 내부용)는 계산값을 담는다", () => {
  const birth: BirthInfo = { calendarType: "solar", year: 1990, month: 12, day: 23, hour: 8, minute: 0, gender: "female" };
  const sajuChart = computeSajuChart(birth);
  const luckCycles = computeLuckCycles(birth, new Date("2026-07-03T03:00:00Z"));
  const msg = buildReadingUserMessage({ type: "saju", question: "요즘 지쳐요", birthInfo: birth, sajuChart, luckCycles });

  it("원국 계산값을 근거 데이터로 전달한다 (LLM이 속으로 참고)", () => {
    expect(msg).toContain("사주 원국 계산 결과");
    expect(msg).toContain(sajuChart.day.ganZhi);
  });
});
