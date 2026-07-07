import { describe, expect, it } from "vitest";
import { looksLikeFourPillars, looksLikePartialPillars, parseFourPillars } from "./parseFourPillars.js";

describe("looksLikeFourPillars", () => {
  it("여덟 글자(4기둥)를 붙여넣으면 팔자 입력으로 본다", () => {
    expect(looksLikeFourPillars("경오 무자 임술 갑진")).toBe(true);
    expect(looksLikeFourPillars("경오무자임술갑진")).toBe(true);
    expect(looksLikeFourPillars("연주 경오 월주 무자 일주 임술 시주 갑진")).toBe(true);
  });

  it("라벨/시간모름이 있으면 3기둥(시주 없음)도 인식", () => {
    expect(looksLikeFourPillars("연주 경오 월주 무자 일주 임술")).toBe(true);
    expect(looksLikeFourPillars("경오 무자 임술 시간모름")).toBe(true);
  });

  it("단위가 붙은 3기둥(연·월·일)은 4번째가 없어도 인식", () => {
    expect(looksLikeFourPillars("갑자년 정축월 병인일")).toBe(true);
  });

  it("일상 문장의 우연한 간지 인접은 오탐하지 않는다", () => {
    expect(looksLikeFourPillars("나 무자식이라 걱정이야")).toBe(false);
    expect(looksLikeFourPillars("오늘 일진 어때?")).toBe(false);
    expect(looksLikeFourPillars("신강신약이 뭐야?")).toBe(false);
  });
});

describe("looksLikePartialPillars", () => {
  it("연·월주만 준 부분 입력을 잡는다", () => {
    expect(looksLikePartialPillars("갑자년 정축월")).toBe(true);
  });

  it("일주까지 있으면 부분 입력이 아니다", () => {
    expect(looksLikePartialPillars("갑자년 정축월 병인일")).toBe(false);
    expect(looksLikePartialPillars("경오 무자 임술 갑진")).toBe(false);
  });

  it("일반 문장은 부분 입력으로 보지 않는다", () => {
    expect(looksLikePartialPillars("오늘 뭐하지")).toBe(false);
    expect(looksLikePartialPillars("임오일에 약속 있어")).toBe(false);
  });
});

describe("parseFourPillars", () => {
  it("공백으로 나열한 팔자를 순서대로 읽는다", () => {
    const r = parseFourPillars("경오 무자 임술 갑진");
    expect(r.ok).toBe(true);
    expect(r.pillars).toMatchObject({ year: "경오", month: "무자", day: "임술", hour: "갑진" });
  });

  it("라벨이 있으면 라벨 기준으로 매핑(표기 순서가 달라도 안전)", () => {
    const r = parseFourPillars("시주 갑진 일주 임술 월주 무자 연주 경오");
    expect(r.ok).toBe(true);
    expect(r.pillars).toMatchObject({ year: "경오", month: "무자", day: "임술", hour: "갑진" });
  });

  it("단위(년/월/일/시)가 붙으면 역순으로 써도 단위 기준으로 매핑", () => {
    const r = parseFourPillars("정묘시 임술일 무자월 경오년");
    expect(r.ok).toBe(true);
    expect(r.pillars).toMatchObject({ year: "경오", month: "무자", day: "임술", hour: "정묘" });
  });

  it("단위가 붙은 정순 입력도 정확히 매핑", () => {
    const r = parseFourPillars("경오년 무자월 임술일 갑진시");
    expect(r.ok).toBe(true);
    expect(r.pillars).toMatchObject({ year: "경오", month: "무자", day: "임술", hour: "갑진" });
  });

  it("붙여쓴 여덟 글자도 읽는다", () => {
    const r = parseFourPillars("경오무자임술갑진");
    expect(r.ok).toBe(true);
    expect(r.pillars).toMatchObject({ year: "경오", month: "무자", day: "임술", hour: "갑진" });
  });

  it("시주가 없으면 hour=null", () => {
    const r = parseFourPillars("연주 경오 월주 무자 일주 임술");
    expect(r.ok).toBe(true);
    expect(r.pillars?.hour).toBeNull();
  });

  it("시간모름이면 4번째 토큰이 있어도 hour=null 로 강제", () => {
    const r = parseFourPillars("경오 무자 임술 시간모름");
    expect(r.ok).toBe(true);
    expect(r.pillars?.hour).toBeNull();
  });

  it("한자 팔자도 한글로 정규화", () => {
    const r = parseFourPillars("庚午 戊子 壬戌 甲辰");
    expect(r.ok).toBe(true);
    expect(r.pillars).toMatchObject({ year: "경오", month: "무자", day: "임술", hour: "갑진" });
  });

  it("성별과 뒤따르는 질문을 분리한다", () => {
    const r = parseFourPillars("경오 무자 임술 갑진 여자 성격 좀 봐줘");
    expect(r.ok).toBe(true);
    expect(r.pillars?.gender).toBe("female");
    expect(r.remainder).toContain("성격");
  });

  it("간지가 3개 미만이면 실패", () => {
    const r = parseFourPillars("경오 무자");
    expect(r.ok).toBe(false);
    expect(r.error).toBeTruthy();
  });
});
