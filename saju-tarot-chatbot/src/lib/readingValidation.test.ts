import { describe, expect, it } from "vitest";
import { applyReadingValidationWarning, validateReadingOutput } from "./readingValidation.js";

const VALID_REPLY = [
  "# 첫 점괘",
  "지금은 방향을 좁히는 것이 먼저입니다.",
  "# 질문 중심 핵심",
  "바로 결정하기보다 이번 주 확인할 신호를 먼저 보세요.",
  "# 분야별 요약",
  "- 직업·재물: 보통 — 역할을 줄이고 기준을 세울 때입니다.",
  "# 지금 해야 할 것과 피해야 할 것",
  "- 오늘 할 일 하나를 정하세요.",
  "# 마지막 점괘",
  "속도를 낮추면 선택이 선명해집니다.",
].join("\n");

describe("readingValidation", () => {
  it("일반 사주 리딩의 필수 섹션 누락을 잡는다", () => {
    const result = validateReadingOutput({ type: "saju", question: "이직해도 될까요?", reply: "# 첫 점괘\n짧은 답" });
    expect(result.ok).toBe(false);
    expect(result.issues.some((issue) => issue.code === "missing-section")).toBe(true);
  });

  it("근거 없는 단정 표현과 흔한 조언을 warning/failure로 남긴다", () => {
    const reply = `${VALID_REPLY}\n반드시 성공합니다. 신중하게 결정하세요`;
    const result = validateReadingOutput({ type: "saju", question: "이직해도 될까요?", reply });
    expect(result.ok).toBe(false);
    expect(result.issues.some((issue) => issue.code === "deterministic-claim")).toBe(true);
    expect(result.issues.some((issue) => issue.code === "generic-advice")).toBe(true);
  });

  it("문제가 있으면 최종 답변 뒤에 검수 메모를 붙인다", () => {
    const applied = applyReadingValidationWarning({ type: "saju", question: "이직해도 될까요?", reply: "# 첫 점괘\n짧은 답" });
    expect(applied.reply).toContain("# 검수 메모");
    expect(applied.validation.issues.length).toBeGreaterThan(0);
  });

  it("타로 리딩은 일반 사주 검수 대상에서 제외한다", () => {
    const result = validateReadingOutput({ type: "tarot", question: "관계", reply: "짧은 답" });
    expect(result.ok).toBe(true);
    expect(result.issues).toHaveLength(0);
  });
});
