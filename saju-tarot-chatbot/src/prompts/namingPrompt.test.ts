import { describe, expect, it } from "vitest";
import { computeSajuChart } from "../lib/saju.js";
import { evaluateName } from "../lib/naming.js";
import type { BirthInfo } from "../types/index.js";
import { buildNamingUserMessage, NAMING_SYSTEM_PROMPT } from "./namingPrompt.js";

describe("이름 감정 AI 프롬프트", () => {
  const birth: BirthInfo = { calendarType: "solar", year: 1990, month: 12, day: 23, hour: 8, minute: 0, gender: "female" };
  const evaluation = evaluateName(computeSajuChart(birth), "김민준", [8, 9, 6]);

  it("단정 금지와 근거 제한 규칙을 담는다", () => {
    expect(NAMING_SYSTEM_PROMPT).toContain("나쁜 이름");
    expect(NAMING_SYSTEM_PROMPT).toContain("제공되지 않은 한자 뜻");
    expect(NAMING_SYSTEM_PROMPT).toContain("공포감");
  });

  it("계산된 이름 감정 결과만 전달하고 생년월일 원본은 담지 않는다", () => {
    const msg = buildNamingUserMessage(evaluation);
    expect(msg).toContain("이름: 김민준");
    expect(msg).toContain("발음오행 기준");
    expect(msg).toContain("발음오행");
    expect(msg).toContain("보완하면 좋은 기운");
    expect(msg).toContain("획수 수리");
    expect(msg).not.toContain("1990년");
    expect(msg).not.toContain("생년월일");
  });
});
