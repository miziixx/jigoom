import { describe, it, expect } from "vitest";
import { parseBirthInput, looksLikeBirthInput, looksLikeTwoBirths, parseTwoBirthsInput } from "./parseBirth.js";

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

  it("'오후 8시'를 20시로 읽는다", () => {
    const r = parseBirthInput("1990-01-01 오후 8시 남");
    expect(r.ok).toBe(true);
    expect(r.birthInfo?.hour).toBe(20);
  });

  it("'오전 8시'는 8시 그대로 읽는다", () => {
    const r = parseBirthInput("1990-01-01 오전 8시 남");
    expect(r.ok).toBe(true);
    expect(r.birthInfo?.hour).toBe(8);
  });

  it("'저녁 7시 30분'을 19:30으로 읽는다", () => {
    const r = parseBirthInput("1990-01-01 저녁 7시 30분 여");
    expect(r.ok).toBe(true);
    expect(r.birthInfo?.hour).toBe(19);
    expect(r.birthInfo?.minute).toBe(30);
  });

  it("'새벽 3시'는 3시로 읽는다", () => {
    const r = parseBirthInput("1990-01-01 새벽 3시 남");
    expect(r.ok).toBe(true);
    expect(r.birthInfo?.hour).toBe(3);
  });

  it("'오후 12시'는 정오(12시), '오전 12시'는 자정(0시)", () => {
    expect(parseBirthInput("1990-01-01 오후 12시 남").birthInfo?.hour).toBe(12);
    expect(parseBirthInput("1990-01-01 오전 12시 남").birthInfo?.hour).toBe(0);
  });

  it("meridiem 없는 24시간제는 그대로 (오후 표기 없이 20시)", () => {
    const r = parseBirthInput("1990-01-01 20시 남");
    expect(r.ok).toBe(true);
    expect(r.birthInfo?.hour).toBe(20);
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

describe("looksLikeTwoBirths / parseTwoBirthsInput — 한 박스에 두 사람(명령어 없는 궁합)", () => {
  it("한 줄에 두 사람 생년월일+성별이 있으면 두 사람 입력으로 본다", () => {
    expect(looksLikeTwoBirths("1993-03-15 14:30 여 서울, 1995-06-20 09:30 남 부산 연인")).toBe(true);
    expect(looksLikeTwoBirths("나 95년 8월 23일 여, 상대 90년 5월 2일 남 우리 궁합 어때?")).toBe(true);
  });

  it("한 사람만 있으면 두 사람 입력이 아니다", () => {
    expect(looksLikeTwoBirths("1993-03-15 14:30 여 서울")).toBe(false);
    expect(looksLikeTwoBirths("95년 8월 23일 남자 성격 봐줘")).toBe(false);
  });

  it("본인 사주 + 우연히 섞인 다른 날짜(둘째에 성별 없음)는 궁합으로 오인하지 않는다", () => {
    expect(looksLikeTwoBirths("1993-03-15 14:30 여 서울, 2020년 1월 1일에 이사했어")).toBe(false);
  });

  it("두 사람을 각각 정확히 파싱하고 첫=나·둘째=상대로 나눈다", () => {
    const r = parseTwoBirthsInput("1993-03-15 14:30 여 서울, 1995-06-20 09:30 남 부산 연인");
    expect(r.ok).toBe(true);
    expect(r.first).toMatchObject({ year: 1993, month: 3, day: 15, hour: 14, gender: "female" });
    expect(r.second).toMatchObject({ year: 1995, month: 6, day: 20, hour: 9, gender: "male" });
    expect(r.relationType).toBe("romantic");
  });

  it("관계 키워드(동료 등)를 읽고, 두 자리 연도·자연어 표현도 처리한다", () => {
    const r = parseTwoBirthsInput("나 95년 8월 23일 시간모름 여, 상대 90년 5월 2일 07시 남 동료");
    expect(r.ok).toBe(true);
    expect(r.first).toMatchObject({ year: 1995, month: 8, day: 23, hour: null, gender: "female" });
    expect(r.second).toMatchObject({ year: 1990, month: 5, day: 2, hour: 7, gender: "male" });
    expect(r.relationType).toBe("coworker");
  });

  it("한쪽에 성별이 빠지면 어느 사람이 문제인지 알려준다", () => {
    const r = parseTwoBirthsInput("1993-03-15 14:30 서울, 1995-06-20 09:30 남 부산");
    expect(r.ok).toBe(false);
    expect(r.error).toContain("첫 번째 사람");
  });
});
