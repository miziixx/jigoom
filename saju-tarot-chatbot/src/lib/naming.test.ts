import { describe, expect, it } from "vitest";
import { analyzeNameSound, compareNames, evaluateName, evaluateSuri } from "./naming.js";
import { computeSajuChart } from "./saju.js";
import type { BirthInfo } from "../types/index.js";

const birth: BirthInfo = { calendarType: "solar", year: 1990, month: 12, day: 23, hour: 8, minute: 0, gender: "female" };
const chart = computeSajuChart(birth);

describe("발음오행 분석", () => {
  it("초성을 오행으로 옮긴다", () => {
    // 김(ㄱ=목) 민(ㅁ=수) 준(ㅈ=금)
    const a = analyzeNameSound("김민준");
    expect(a.syllables.map((s) => s.elementLabel)).toEqual(["목", "수", "금"]);
    expect(a.relations).toHaveLength(2);
  });

  it("상생으로만 이어지면 순조로움으로 판정한다", () => {
    // 수→목(상생), 목→화(상생): 문자 예시 - 물(ㅁ=수) 강(ㄱ=목) 님(ㄴ=화)
    const a = analyzeNameSound("물강님");
    expect(a.syllables.map((s) => s.elementLabel)).toEqual(["수", "목", "화"]);
    expect(a.harmony).toBe("순조로움");
  });

  it("한글이 아닌 문자는 건너뛴다", () => {
    const a = analyzeNameSound("A김B");
    expect(a.syllables).toHaveLength(1);
    expect(a.syllables[0].syllable).toBe("김");
  });

  it("이름 중심 기준은 3글자 이상에서 성을 제외하고 본다", () => {
    const a = analyzeNameSound("김민준", "given-name");
    expect(a.schoolLabel).toBe("이름 중심 기준");
    expect(a.syllables.map((s) => s.syllable)).toEqual(["민", "준"]);
  });
});

describe("수리 계산", () => {
  it("사격을 계산하고 길흉 레벨을 매긴다", () => {
    const suri = evaluateSuri([8, 9, 6]);
    expect(suri).not.toBeNull();
    expect(suri?.won).toBe(15); // 9 + 6
    expect(suri?.jeong).toBe(23); // 8 + 9 + 6
    expect(suri?.levels).toHaveLength(4);
  });

  it("획수가 부족하면 null", () => {
    expect(evaluateSuri([8])).toBeNull();
  });
});

describe("이름 종합 감정", () => {
  it("발음·사주 적합도·종합 판정을 반환한다", () => {
    const evaln = evaluateName(chart, "김민준");
    expect(evaln.sound.syllables.length).toBe(3);
    expect(evaln.school).toBe("full-name");
    expect(["좋음", "보통", "주의"]).toContain(evaln.fit.level);
    expect(["좋음", "보통", "주의"]).toContain(evaln.overall);
    expect(evaln.headline.length).toBeGreaterThan(5);
  });

  it("획수를 주면 수리도 포함한다", () => {
    const evaln = evaluateName(chart, "김민준", [8, 9, 6]);
    expect(evaln.suri).not.toBeNull();
  });

  it("여러 후보를 비교해 추천 후보를 고른다", () => {
    const comparison = compareNames(chart, [
      { name: "김민준", strokes: [8, 9, 6] },
      { name: "이서아", strokes: [7, 8, 9] },
      { name: "박도윤" },
    ], "given-name");
    expect(comparison.candidates).toHaveLength(3);
    expect(comparison.recommended).toBe(comparison.candidates[0]);
    expect(comparison.summary).toContain(comparison.recommended.name);
    expect(comparison.recommended.school).toBe("given-name");
  });
});
