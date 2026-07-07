import { describe, it, expect } from "vitest";
import { parseBirthInput, looksLikeBirthInput } from "./parseBirth.js";

describe("parseBirthInput — 완전 자연어 입력", () => {
  it("네 자리 연도 표준 입력을 읽는다", () => {
    const r = parseBirthInput("1993-03-15 14:30 여 서울");
    expect(r.ok).toBe(true);
    expect(r.birthInfo).toMatchObject({ year: 1993, month: 3, day: 15, hour: 14, minute: 30, gender: "female" });
  });

  it("두 자리 연도('95년')를 4자리로 편다", () => {
    const r = parseBirthInput("95년 8월 23일 14시 남자");
    expect(r.ok).toBe(true);
    expect(r.birthInfo?.year).toBe(1995);
    expect(r.birthInfo?.month).toBe(8);
    expect(r.birthInfo?.day).toBe(23);
    expect(r.birthInfo?.hour).toBe(14);
    expect(r.birthInfo?.gender).toBe("male");
  });

  it("두 자리 연도 2000년대('05년')는 2005로 편다", () => {
    const r = parseBirthInput("05년 3월 9일 시간모름 여자");
    expect(r.ok).toBe(true);
    expect(r.birthInfo?.year).toBe(2005);
    expect(r.birthInfo?.hour).toBeNull();
    expect(r.birthInfo?.gender).toBe("female");
  });

  it("성별이 붙어 있고 '시간 몰라'가 섞인 자연어 + 질문을 한 번에 처리한다", () => {
    const r = parseBirthInput("95년 8월 23일남자 성격좀 봐줘, 근데 시간 몰라");
    expect(r.ok).toBe(true);
    expect(r.birthInfo).toMatchObject({ year: 1995, month: 8, day: 23, hour: null, gender: "male" });
    // 남은 텍스트에 질문이 살아 있어야 한다
    expect(r.remainder).toContain("성격");
  });

  it("지명에 든 '여'를 성별로 오인하지 않는다 (남 여수 → 남자)", () => {
    const r = parseBirthInput("1990-01-01 12:00 남 여수");
    expect(r.ok).toBe(true);
    expect(r.birthInfo?.gender).toBe("male");
    expect(r.birthInfo?.birthPlace).toBe("gwangju");
  });

  it("순수 생일 입력이면 remainder가 비어 있다", () => {
    const r = parseBirthInput("1988.7.15 시간모름 남");
    expect(r.ok).toBe(true);
    expect(r.birthInfo?.hour).toBeNull();
    expect((r.remainder ?? "").length).toBe(0);
  });
});

describe("looksLikeBirthInput", () => {
  it("두 자리 연도 자연어도 생일 입력으로 본다", () => {
    expect(looksLikeBirthInput("95년 8월 23일남자 성격 봐줘")).toBe(true);
    expect(looksLikeBirthInput("1993-03-15 14:30 여 서울")).toBe(true);
  });

  it("연도나 성별이 없으면 생일 입력이 아니다", () => {
    expect(looksLikeBirthInput("지장간이 뭐야?")).toBe(false);
    expect(looksLikeBirthInput("오늘 일진 어때")).toBe(false);
  });
});
