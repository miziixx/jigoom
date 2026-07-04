import { describe, expect, it } from "vitest";
import { computeSajuChart } from "../lib/saju.js";
import { compareNames, evaluateName } from "../lib/naming.js";
import type { BirthInfo } from "../types/index.js";
import { buildNamingUserMessage, NAMING_SYSTEM_PROMPT } from "./namingPrompt.js";

describe("이름 감정 AI 프롬프트", () => {
  const birth: BirthInfo = { calendarType: "solar", year: 1990, month: 12, day: 23, hour: 8, minute: 0, gender: "female" };
  const evaluation = evaluateName(computeSajuChart(birth), "김민준", [8, 9, 6], "full-name", {
    mode: "baby",
    desiredImage: "밝고 단아함",
    avoidSounds: "너무 무거운 발음",
  });

  it("단정 금지와 근거 제한 규칙을 담는다", () => {
    expect(NAMING_SYSTEM_PROMPT).toContain("나쁜 이름");
    expect(NAMING_SYSTEM_PROMPT).toContain("제공되지 않은 한자 뜻");
    expect(NAMING_SYSTEM_PROMPT).toContain("법적 등록 가능성");
    expect(NAMING_SYSTEM_PROMPT).toContain("공포감");
  });

  it("계산된 이름 감정 결과만 전달하고 생년월일 원본은 담지 않는다", () => {
    const msg = buildNamingUserMessage(evaluation);
    expect(msg).toContain("이름: 김민준");
    expect(msg).toContain("작명 목적: 아기 이름");
    expect(msg).toContain("원하는 이미지: 밝고 단아함");
    expect(msg).toContain("피하고 싶은 발음/느낌: 너무 무거운 발음");
    expect(msg).toContain("발음오행 기준");
    expect(msg).toContain("발음오행");
    expect(msg).toContain("보완하면 좋은 기운");
    expect(msg).toContain("획수 수리");
    expect(msg).not.toContain("1990년");
    expect(msg).not.toContain("생년월일");
  });

  it("법적 등록 가능성을 확정하지 말라는 안내를 담는다", () => {
    const msg = buildNamingUserMessage(evaluation);
    expect(msg).toContain("등록 가능 여부");
    expect(msg).toContain("최종 확인");
    expect(msg).toContain("전자가족관계등록시스템");
  });

  it("후보가 여러 개면 후보 비교 종합평 근거를 함께 전달한다", () => {
    const comparison = compareNames(
      computeSajuChart(birth),
      [{ name: "김민준" }, { name: "이서아" }, { name: "박도윤" }],
      "given-name",
      { mode: "baby" },
    );
    const msg = buildNamingUserMessage(comparison.recommended, comparison);
    expect(msg).toContain("# 후보 비교 종합평");
    expect(msg).toContain("[후보 비교]");
    expect(msg).toContain("1위");
    expect(msg).toContain("2위");
  });
});
