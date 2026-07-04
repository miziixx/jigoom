import { describe, expect, it } from "vitest";
import {
  analyzeNameSound,
  buildNamingBrief,
  compareNames,
  evaluateName,
  evaluateSuri,
  namingDisplayScore,
  parseRecommendedNames,
  scoreRecommendedNames,
} from "./naming.js";
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

describe("이름 추천 브리프", () => {
  const GENERATES: Record<string, string> = { wood: "fire", fire: "earth", earth: "metal", metal: "water", water: "wood" };

  it("보완 기운과 어울리는 초성·상생 기운을 결정론적으로 정리한다", () => {
    const brief = buildNamingBrief(chart);
    expect(["wood", "fire", "earth", "metal", "water"]).toContain(brief.neededElement);
    expect(brief.recommendedChoseong.length).toBeGreaterThan(0);
    expect(brief.supportingChoseong.length).toBeGreaterThan(0);
    // 상생 기운은 보완 기운을 생하는 오행이어야 한다
    expect(GENERATES[brief.supportingElement]).toBe(brief.neededElement);
    expect(brief.note).toContain(brief.neededLabel);
  });

  it("같은 사주에는 같은 브리프를 낸다", () => {
    expect(buildNamingBrief(chart)).toEqual(buildNamingBrief(chart));
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
    const evaln = evaluateName(chart, "김민준", [8, 9, 6], "full-name", {
      mode: "baby",
      desiredImage: "단아함",
    });
    expect(evaln.suri).not.toBeNull();
    expect(evaln.purpose?.mode).toBe("baby");
    expect(evaln.purpose?.desiredImage).toBe("단아함");
  });

  it("여러 후보를 비교해 추천 후보를 고른다", () => {
    const comparison = compareNames(chart, [
      { name: "김민준", strokes: [8, 9, 6] },
      { name: "이서아", strokes: [7, 8, 9] },
      { name: "박도윤" },
    ], "given-name", { mode: "rename", purposeNote: "직업 이미지 개선" });
    expect(comparison.candidates).toHaveLength(3);
    expect(comparison.recommended).toBe(comparison.candidates[0]);
    expect(comparison.summary).toContain(comparison.recommended.name);
    expect(comparison.recommended.school).toBe("given-name");
    expect(comparison.recommended.purpose?.mode).toBe("rename");
  });
});

describe("이름 추천 결과 구조화", () => {
  it("AI JSON 응답에서 후보를 파싱한다 (앞뒤 잡음/코드펜스 허용)", () => {
    const raw =
      '설명 문장\n```json\n{ "direction": "밝은 소리 방향", "candidates": [ {"name":"민준","hanja":"民俊","hanjaMeaning":"백성 민, 뛰어날 준","sound":"ㅁ 소리","image":"밝음"}, {"name":"서준"} ] }\n```\n끝';
    const parsed = parseRecommendedNames(raw);
    expect(parsed).not.toBeNull();
    expect(parsed!.direction).toBe("밝은 소리 방향");
    expect(parsed!.candidates).toHaveLength(2);
    expect(parsed!.candidates[0].name).toBe("민준");
    expect(parsed!.candidates[0].hanja).toBe("民俊");
  });

  it("JSON이 아니면 null을 돌려준다", () => {
    expect(parseRecommendedNames("# 추천 이름\n1. 민준")).toBeNull();
  });

  it("후보에 성을 붙여 점수를 매기고 내림차순 정렬한다", () => {
    const parsed = parseRecommendedNames(
      '{ "candidates": [ {"name":"민준"}, {"name":"서아"}, {"name":"민준"} ] }',
    );
    const scored = scoreRecommendedNames(chart, parsed!, { surname: "김", school: "full-name" });
    // 중복 이름 제거
    expect(scored).toHaveLength(2);
    expect(scored[0].fullName.startsWith("김")).toBe(true);
    expect(scored[0].rank).toBe(1);
    // 점수 내림차순
    expect(scored[0].displayScore).toBeGreaterThanOrEqual(scored[1].displayScore);
    // 표시 점수는 40~99 범위
    for (const s of scored) {
      expect(s.displayScore).toBeGreaterThanOrEqual(40);
      expect(s.displayScore).toBeLessThanOrEqual(99);
    }
  });

  it("적합도가 좋은 이름이 주의 이름보다 점수가 높다", () => {
    const good = evaluateName(chart, "김강현", undefined, "full-name");
    const scoreGood = namingDisplayScore(good);
    expect(scoreGood).toBeGreaterThanOrEqual(40);
    expect(scoreGood).toBeLessThanOrEqual(99);
  });
});

describe("이름 추천 JSON 견고성", () => {
  it("max_tokens로 잘린 JSON에서도 완성된 후보만 복구한다", () => {
    const truncated =
      'AI 이름 추천\n{ "direction": "목 기운 방향", "candidates": [\n' +
      '{ "name": "가은", "hanja": "嘉恩", "hanjaMeaning": "아름다울 가, 은혜 은", "sound": "ㄱ 소리", "image": "온화" },\n' +
      '{ "name": "강희", "hanja": "姜熙", "hanjaMeaning": "굳셀 강, 빛날 희", "sound": "ㄱ", "image": "단정" },\n' +
      '{ "name": "경윤", "han';
    const parsed = parseRecommendedNames(truncated);
    expect(parsed).not.toBeNull();
    expect(parsed!.direction).toBe("목 기운 방향");
    // 완성된 2개만 복구, 잘린 '경윤'은 제외
    expect(parsed!.candidates).toHaveLength(2);
    expect(parsed!.candidates.map((c) => c.name)).toEqual(["가은", "강희"]);
  });
})
