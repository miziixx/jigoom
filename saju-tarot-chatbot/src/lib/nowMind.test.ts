import { describe, expect, it } from "vitest";
import { buildNowMind, formatNowMind } from "./nowMind.js";
import { computeSajuChart, computeLuckCycles } from "./saju.js";
import { buildReadingUserMessage } from "../prompts/systemPrompt.js";
import type { BirthInfo, LuckCycles, SajuChart } from "../types/index.js";

const birth: BirthInfo = { calendarType: "solar", year: 1990, month: 12, day: 23, hour: 8, minute: 0, gender: "female" };
const chart = computeSajuChart(birth);
const luck = computeLuckCycles(birth, new Date("2026-07-03T03:00:00Z"));

// 표면(mind/headline)에 절대 나오면 안 되는 사주 용어.
// 단음절 한자어(충·형·파·해 등)는 "예민해지고"·"해내야"처럼 평범한 한글 음절과 겹치므로
// 표면 검사에서는 오탐을 피하려 명확한 다음절 용어만 본다.
const JARGON = [
  "일간", "월지", "천간", "지지", "십성", "비겁", "식상", "재성", "관성", "인성",
  "세운", "대운", "월운", "용신", "기신", "신강", "신약",
];
// 안전 규칙상 단정·공포 표현
const FORBIDDEN = ["반드시", "무조건", "100%", "절대", "망한다", "이혼합니다"];
const OUTWARD_GROUPS = ["식상", "재성", "비겁"];

describe("buildNowMind (지금 마음 엔진)", () => {
  it("원국+운이 있으면 지금 마음을 계산해 낸다", () => {
    const now = buildNowMind(chart, luck);
    expect(now).not.toBeNull();
    expect(now!.headline.length).toBeGreaterThan(10);
    expect(now!.drives.length).toBeGreaterThanOrEqual(1);
    expect(now!.drives.length).toBeLessThanOrEqual(2);
  });

  it("원국이나 운이 없으면 null (순수 타로 등)", () => {
    expect(buildNowMind(undefined, luck)).toBeNull();
    expect(buildNowMind(chart, undefined)).toBeNull();
  });

  it("결정론: 같은 입력이면 항상 같은 결과", () => {
    expect(buildNowMind(chart, luck)).toEqual(buildNowMind(chart, luck));
  });

  it("표면 문장(headline/mind/tension/shaken)에 사주 용어를 노출하지 않는다", () => {
    const now = buildNowMind(chart, luck)!;
    const surface = [now.headline, now.tension ?? "", now.shaken ?? "", ...now.drives.map((d) => d.mind)].join(" ");
    for (const term of JARGON) expect(surface).not.toContain(term);
  });

  it("표면 문장에 단정·공포 표현을 쓰지 않는다", () => {
    const now = buildNowMind(chart, luck)!;
    const surface = [now.headline, now.tension ?? "", now.shaken ?? "", ...now.drives.map((d) => d.mind)].join(" ");
    for (const term of FORBIDDEN) expect(surface).not.toContain(term);
  });

  it("전문가 근거(evidence)에는 계산 근거(간지·십성·강약)를 남긴다", () => {
    const now = buildNowMind(chart, luck)!;
    expect(now.evidence.length).toBeGreaterThan(0);
    expect(now.evidence.join(" ")).toMatch(/세운|월운/);
  });

  it("신약 + 발산형 마음이면 '하고 싶은 마음 vs 낼 힘'의 속 긴장을 짚는다", () => {
    const weakOutward: SajuChart = {
      ...chart,
      dayMasterGan: "을", // 을목 일간
      strength: { supportScore: 1, totalScore: 1, label: "신약", detail: "테스트용 신약" },
      yongshin: { supportive: ["수", "목"], yongshin: ["수"], heesin: ["목"], unfavorable: ["금"], note: "테스트" },
    };
    // 세운 천간이 식상/재성 계열이 되도록: 을목 기준 병(화)=상관, 무(토)=정재
    const outLuck: LuckCycles = { ...luck, yearGanZhi: "병오", monthGanZhi: "무술" };
    const now = buildNowMind(weakOutward, outLuck)!;
    expect(OUTWARD_GROUPS).toContain(now.drives[0].group);
    expect(now.tension).toContain("밀어붙일 힘");
  });

  it("formatNowMind는 근거 블록 문자열로 직렬화한다", () => {
    const now = buildNowMind(chart, luck)!;
    const text = formatNowMind(now);
    expect(text).toContain("지금 특히 올라오기 쉬운 마음:");
    expect(text).toContain("(근거)");
  });
});

describe("systemPrompt 배선: 지금 마음이 통합 심리 블록에 들어간다", () => {
  it("기본 리딩에 통합 블록과 '지금 올라오는 마음' 소재, 활용 안내를 전달한다", () => {
    const msg = buildReadingUserMessage({ type: "saju", question: "요즘 지쳐요", gender: birth.gender, sajuChart: chart, luckCycles: luck });
    expect(msg).toContain("[속마음·현재 심리 — 계산됨");
    expect(msg).toContain("▸ 지금 올라오는 마음");
    expect(msg).toContain("속마음·현재 심리 활용 안내");
  });

  it("고급 리딩에도 '지금 올라오는 마음'이 그대로 들어간다(깊이와 무관하게 콘텐츠는 동일)", () => {
    const msg = buildReadingUserMessage({
      type: "saju",
      question: "요즘 지쳐요",
      gender: birth.gender,
      sajuChart: chart,
      luckCycles: luck,
      context: { depth: "advanced" },
    });
    expect(msg).toContain("▸ 지금 올라오는 마음");
    expect(msg).toContain("▸ 재료 vs 실제 쓸 힘");
  });

  it("팬아웃 back 호출에는 심리 블록이 붙지 않는다", () => {
    const msg = buildReadingUserMessage({
      type: "saju",
      question: "전체",
      gender: birth.gender,
      sajuChart: chart,
      luckCycles: luck,
      sectionGroup: "back",
    });
    expect(msg).not.toContain("[속마음·현재 심리 — 계산됨");
  });

  it("순수 타로(원국 없음)에는 심리 블록이 붙지 않는다", () => {
    const msg = buildReadingUserMessage({ type: "tarot", question: "이 관계 어때요?", tarotCards: [] });
    expect(msg).not.toContain("[속마음·현재 심리 — 계산됨");
  });
});
