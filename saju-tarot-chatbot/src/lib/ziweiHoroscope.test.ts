import { describe, expect, it } from "vitest";
import { computeZiweiHoroscope } from "./ziwei.js";
import type { BirthInfo } from "../types/index.js";

/**
 * 자미두수 운한(대한·유년) precision lock (엔진 업그레이드 Z-1).
 *
 * iztro horoscope()의 정규화 결과를 고정 생일 스냅샷으로 잠근다 — 이후 iztro 버전 업이나
 * 래퍼 수정으로 대한 간지·명궁 소재궁·사화가 바뀌면 여기서 감지된다.
 * 기대값은 2026-07-10에 iztro 2.5.8 실제 출력에서 도출 (기준일 2026-07-06 고정).
 */

const REF = new Date("2026-07-06T03:00:00Z");

const birthA: BirthInfo = { calendarType: "solar", year: 1990, month: 12, day: 23, hour: 8, minute: 0, gender: "female" };
const birthB: BirthInfo = { calendarType: "solar", year: 1984, month: 2, day: 20, hour: 14, minute: 30, gender: "male" };

describe("computeZiweiHoroscope — 대한·유년 잠금", () => {
  it("여 1990-12-23 진시: 신사 대한(32~41, 자녀궁) + 병오 유년(부처궁)", () => {
    const luck = computeZiweiHoroscope(birthA, REF);
    expect(luck).not.toBeNull();

    expect(luck!.decade?.stem).toBe("신");
    expect(luck!.decade?.branch).toBe("사");
    expect(luck!.decade?.palaceOfSoul).toEqual({ name: "자녀", branch: "사" });
    expect(luck!.decade?.ageRange).toEqual([32, 41]);
    expect(luck!.decade?.mutagens).toEqual([
      { star: "거문", type: "록", natalPalace: "질액" },
      { star: "태양", type: "권", natalPalace: "노복" },
      { star: "문곡", type: "과", natalPalace: "명궁" },
      { star: "문창", type: "기", natalPalace: "부처" },
    ]);

    expect(luck!.year?.stem).toBe("병");
    expect(luck!.year?.branch).toBe("오");
    expect(luck!.year?.palaceOfSoul).toEqual({ name: "부처", branch: "오" });
    expect(luck!.year?.ageRange).toBeUndefined();
    expect(luck!.year?.mutagens).toEqual([
      { star: "천동", type: "록", natalPalace: "전택" },
      { star: "천기", type: "권", natalPalace: "질액" },
      { star: "문창", type: "과", natalPalace: "부처" },
      { star: "염정", type: "기", natalPalace: "명궁" },
    ]);
  });

  it("남 1984-02-20 미시: 갑술 대한(35~44, 전택궁) + 병오 유년(형제궁)", () => {
    const luck = computeZiweiHoroscope(birthB, REF);
    expect(luck).not.toBeNull();

    expect(luck!.decade?.stem).toBe("갑");
    expect(luck!.decade?.branch).toBe("술");
    expect(luck!.decade?.palaceOfSoul).toEqual({ name: "전택", branch: "술" });
    expect(luck!.decade?.ageRange).toEqual([35, 44]);
    expect(luck!.decade?.mutagens.map((m) => `${m.star}${m.type}→${m.natalPalace}`)).toEqual([
      "염정록→부모",
      "파군권→전택",
      "무곡과→노복",
      "태양기→천이",
    ]);

    expect(luck!.year?.palaceOfSoul).toEqual({ name: "형제", branch: "오" });
  });

  it("출생 시간을 모르면 원식 차트와 같은 규칙으로 null을 반환한다", () => {
    const luck = computeZiweiHoroscope({ ...birthA, hour: null }, REF);
    expect(luck).toBeNull();
  });

  it("결정론: 같은 입력은 같은 결과를 낸다", () => {
    const a = computeZiweiHoroscope(birthA, REF);
    const b = computeZiweiHoroscope(birthA, REF);
    expect(a).toEqual(b);
  });
});
