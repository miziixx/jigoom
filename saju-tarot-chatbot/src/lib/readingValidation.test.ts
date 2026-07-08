import { describe, expect, it } from "vitest";
import {
  applyReadingValidationWarning,
  buildContentRewritePrompt,
  contentNeedsRewrite,
  validateReadingContent,
  validateReadingOutput,
} from "./readingValidation.js";

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

describe("내용 자가교정 게이트", () => {
  it("validateReadingContent는 구조와 무관하게 단정 예언을 잡는다(반쪽에도 안전)", () => {
    // 섹션 헤더가 없는 리딩 '반쪽'이어도 단정 표현은 잡힌다
    const half = "요즘 흐름을 보면 반드시 성공합니다. 힘내세요.";
    const issues = validateReadingContent(half);
    expect(issues.some((i) => i.code === "deterministic-claim")).toBe(true);
    expect(contentNeedsRewrite(issues)).toBe(true);
  });

  it("깨끗한 리딩은 교정이 필요 없다", () => {
    const clean = "지금은 속도를 낮추면 선택이 또렷해지는 흐름입니다. 이번 주 확인할 신호를 먼저 보세요.";
    const issues = validateReadingContent(clean);
    expect(contentNeedsRewrite(issues)).toBe(false);
  });

  it("전문용어는 [전문가 근거 보기] 안에서는 세지 않는다", () => {
    const withEvidence = "타고난 결이 이렇습니다.\n[전문가 근거 보기]\n- 일간 병화, 월지 자수, 정관, 편재, 식신, 상관, 대운 신유, 세운 갑진";
    const issues = validateReadingContent(withEvidence);
    expect(issues.some((i) => i.code === "excessive-jargon")).toBe(false);
  });

  it("경고(뻔한 조언)만 있으면 교정을 트리거하지 않는다", () => {
    const issues = validateReadingContent("신중하게 결정하세요");
    expect(issues.some((i) => i.code === "generic-advice")).toBe(true);
    expect(contentNeedsRewrite(issues)).toBe(false); // warning만이면 재생성 안 함
  });

  it("buildContentRewritePrompt는 이슈·원 근거·기존 리딩·금지 규칙을 담는다", () => {
    const issues = validateReadingContent("반드시 합격합니다.");
    const prompt = buildContentRewritePrompt({
      originalReply: "반드시 합격합니다.",
      issues,
      evidenceUserMessage: "[상세 계산 근거] 오행 분포 ...",
    });
    expect(prompt).toContain("리딩 교정 요청");
    expect(prompt).toContain("[원 근거]");
    expect(prompt).toContain("[기존 리딩]");
    expect(prompt).toContain("반드시/무조건/100%/절대");
    expect(prompt).toContain("[상세 계산 근거]");
  });
});
