import { describe, expect, it } from "vitest";
import { computeFortuneEvidence } from "./fortune.js";
import { buildFallbackFortune } from "./fortuneFallback.js";
import { buildFortuneUserMessage, parseFortuneContent } from "../prompts/fortunePrompt.js";
import type { BirthInfo, FortuneContent } from "../types/index.js";

const birth: BirthInfo = {
  calendarType: "solar",
  year: 1990,
  month: 12,
  day: 23,
  hour: 8,
  minute: 0,
  gender: "female",
};
const evidence = computeFortuneEvidence(birth, new Date("2026-07-03T03:00:00Z"));

const FORBIDDEN = ["반드시", "무조건", "헤어져야", "100%", "절대"];

describe("룰 기반 폴백", () => {
  const content = buildFallbackFortune(evidence);

  it("FortuneContent 형식을 모두 채운다", () => {
    expect(content.summary.length).toBeGreaterThan(0);
    expect(content.keywords).toHaveLength(3);
    expect(content.good_areas.length).toBeGreaterThanOrEqual(2);
    expect(content.caution_points.length).toBeGreaterThanOrEqual(2);
    expect(content.do_actions).toHaveLength(3);
    expect(content.avoid_actions).toHaveLength(2);
    expect(content.share_text.length).toBeGreaterThan(0);
    for (const v of Object.values(content.categories)) expect(typeof v).toBe("string");
  });

  it("금지 표현(단정·공포형)을 쓰지 않는다", () => {
    const all = JSON.stringify(content);
    for (const word of FORBIDDEN) expect(all).not.toContain(word);
  });

  it("근거 데이터를 반영한다 (간지·행운 시간대)", () => {
    expect(content.share_text).toContain(evidence.date);
    expect(content.summary).toContain(evidence.ganzhi.day);
  });

  it("폴백 결과는 파서가 검증하는 스키마를 통과한다", () => {
    const parsed = parseFortuneContent(JSON.stringify(content));
    expect(parsed).not.toBeNull();
    expect(parsed).toEqual(content);
  });
});

describe("근거 데이터 직렬화", () => {
  it("십성·지지관계·신살·카테고리 점수를 프롬프트 메시지에 담는다", () => {
    const msg = buildFortuneUserMessage(evidence);
    expect(msg).toContain("[근거 데이터]");
    expect(msg).toContain(evidence.ganzhi.day);
    expect(msg).toContain(evidence.tenGod.name);
    expect(msg).toContain("카테고리 점수");
    expect(msg).toContain(String(evidence.categories.overall));
  });
});

describe("모델 응답 파서", () => {
  const valid: FortuneContent = {
    summary: "무난한 하루",
    keywords: ["a", "b", "c"],
    good_areas: ["x", "y"],
    caution_points: ["p", "q"],
    do_actions: ["1", "2", "3"],
    avoid_actions: ["n1", "n2"],
    categories: { love: "l", work: "w", money: "m", relationship: "r", condition: "c" },
    share_text: "공유",
  };

  it("순수 JSON을 파싱한다", () => {
    expect(parseFortuneContent(JSON.stringify(valid))).toEqual(valid);
  });

  it("코드블록 펜스를 제거하고 파싱한다", () => {
    const fenced = "```json\n" + JSON.stringify(valid) + "\n```";
    expect(parseFortuneContent(fenced)).toEqual(valid);
  });

  it("앞뒤 잡텍스트가 있어도 객체 구간만 파싱한다", () => {
    const noisy = "결과입니다: " + JSON.stringify(valid) + " 이상입니다.";
    expect(parseFortuneContent(noisy)).toEqual(valid);
  });

  it("필수 필드가 빠지면 null", () => {
    const { summary: _omit, ...rest } = valid;
    void _omit;
    expect(parseFortuneContent(JSON.stringify(rest))).toBeNull();
  });

  it("categories 항목 타입이 틀리면 null", () => {
    const bad = { ...valid, categories: { ...valid.categories, love: 123 } };
    expect(parseFortuneContent(JSON.stringify(bad))).toBeNull();
  });

  it("JSON이 아니면 null", () => {
    expect(parseFortuneContent("죄송합니다, 생성에 실패했습니다.")).toBeNull();
  });
});
