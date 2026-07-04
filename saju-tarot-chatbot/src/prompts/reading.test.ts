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
  it("종합 사주풀이 섹션(성격·직업·애정·건강·대운·세운)을 담는다", () => {
    for (const s of [
      "# 첫 점괘",
      "# 타고난 성격과 기질",
      "# 직업과 돈",
      "# 애정과 관계",
      "# 건강과 컨디션",
      "# 인생의 큰 흐름",
      "# 올해의 흐름",
      "# 마지막 점괘",
    ]) {
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
  const msg = buildReadingUserMessage({ type: "saju", question: "요즘 지쳐요", gender: birth.gender, sajuChart, luckCycles });

  it("원국 계산값을 근거 데이터로 전달한다 (LLM이 속으로 참고)", () => {
    expect(msg).toContain("사주 원국 계산 결과");
    expect(msg).toContain(sajuChart.day.ganZhi);
  });

  it("개인정보 보호: 생년월일 원본은 AI 메시지에 담지 않는다", () => {
    // 계산 결과와 성별만 전달하고, 생년월일 원본 문자열은 넣지 않는다
    expect(msg).not.toContain("1990년");
    expect(msg).not.toContain("생년월일시");
    expect(msg).toContain("성별");
  });

  it("깊이 미선택이면 종합(모든 섹션)·간결 기본 프로필을 붙인다", () => {
    expect(msg).toContain("기본 리딩 — 종합");
    expect(msg).toContain("건강과 컨디션");
    expect(msg).toContain("인생의 큰 흐름");
    expect(msg).toContain("4200~5200자");
    expect(msg).toContain("월별 근거");
  });

  it("깊이를 고르면 기본 종합 프로필 대신 해당 깊이를 쓴다", () => {
    const deep = buildReadingUserMessage({
      type: "saju",
      question: "요즘 지쳐요",
      gender: birth.gender,
      sajuChart,
      luckCycles,
      context: { depth: "expert" },
    });
    expect(deep).not.toContain("[기본 리딩 — 종합]");
    expect(deep).toContain("전문가 리딩");
  });

  it("병렬 생성을 위해 지정 섹션만 쓰라는 지시를 붙일 수 있다", () => {
    const front = buildReadingUserMessage({
      type: "saju",
      question: "전체",
      gender: birth.gender,
      sajuChart,
      luckCycles,
      sectionGroup: "front",
    });
    const back = buildReadingUserMessage({
      type: "saju",
      question: "전체",
      gender: birth.gender,
      sajuChart,
      luckCycles,
      sectionGroup: "back",
    });

    expect(front).toContain("병렬 생성 — 앞부분만 작성");
    expect(front).toContain("# 재물 흐름");
    expect(front).toContain("건강과 컨디션");
    expect(front).toContain("절대 쓰지 마라");
    expect(back).toContain("병렬 생성 — 뒷부분만 작성");
    expect(back).toContain("# 건강과 컨디션");
    expect(back).toContain("첫 점괘");
    expect(back).toContain("절대 쓰지 마라");
  });
});
