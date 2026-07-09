import { describe, expect, it } from "vitest";
import { buildPersonDeepEvidence, computePersonProfile } from "./personDeep.js";
import { computeSajuChart } from "./saju.js";
import { buildReadingUserMessage } from "../prompts/systemPrompt.js";
import type { BirthInfo } from "../types/index.js";

const birthA: BirthInfo = { calendarType: "solar", year: 1990, month: 12, day: 23, hour: 8, minute: 0, gender: "female" };
const birthB: BirthInfo = { calendarType: "solar", year: 1988, month: 4, day: 5, hour: 14, minute: 0, gender: "male" };
const chartA = computeSajuChart(birthA);
const chartB = computeSajuChart(birthB);

const JARGON = ["일간", "월지", "천간", "지지", "십성", "비겁", "식상", "재성", "관성", "인성", "통근", "신강", "신약", "용신", "기신", "세운", "대운"];
const FORBIDDEN = ["반드시", "무조건", "100%", "절대", "망한다"];
const DIAGNOSIS = ["애착유형", "회피형", "불안형", "나르시시스트", "소시오패스", "번아웃"];

describe("computePersonProfile (상대 작동방식 파생)", () => {
  it("상대 원국으로 taxonomy 5항목을 만든다", () => {
    const profile = computePersonProfile(chartB, chartA, "romantic");
    expect(profile).not.toBeNull();
    const situations = profile!.taxonomy.map((t) => t.situation);
    expect(situations).toEqual(["좋아할 때", "불안할 때", "거절할 때", "질투할 때", "미련·식을 때"]);
  });

  it("상대 원국이 없으면 null", () => {
    expect(computePersonProfile(null, chartA)).toBeNull();
  });

  it("A가 없어도(상대만) taxonomy는 나온다(끌림/부담만 A 의존)", () => {
    const profile = computePersonProfile(chartB, null);
    expect(profile).not.toBeNull();
    expect(profile!.taxonomy.length).toBe(5);
  });

  it("비대칭: A→B와 B→A의 프로필이 다르다", () => {
    const ab = computePersonProfile(chartB, chartA);
    const ba = computePersonProfile(chartA, chartB);
    expect(ab).not.toEqual(ba);
  });

  it("결정론: 같은 입력이면 같은 결과", () => {
    expect(computePersonProfile(chartB, chartA, "romantic")).toEqual(computePersonProfile(chartB, chartA, "romantic"));
  });

  it("표면 문장(taxonomy·끌림·부담·불일치)에 사주 용어·진단명·단정 표현을 노출하지 않는다", () => {
    const p = computePersonProfile(chartB, chartA)!;
    const surface = [
      ...p.taxonomy.map((t) => t.behavior),
      ...p.attraction,
      ...p.burden,
      p.mismatch ?? "",
      p.attractionHeadline,
    ].join(" ");
    for (const term of [...JARGON, ...DIAGNOSIS, ...FORBIDDEN]) expect(surface).not.toContain(term);
  });
});

describe("buildPersonDeepEvidence (프롬프트 근거)", () => {
  it("작동방식·신뢰도 근거 블록과 활용 안내를 만든다", () => {
    const ev = buildPersonDeepEvidence({ chartB, chartA, relationType: "romantic", hasLuck: true });
    expect(ev).not.toBeNull();
    expect(ev!.evidence).toContain("[상대 완전분석 — 작동방식·신뢰도 — 계산됨]");
    expect(ev!.evidence).toContain("▸ 상대 작동방식");
    expect(ev!.evidence).toContain("▸ 분야별 신뢰도");
    expect(ev!.instruction).toContain("궁합 '점수'로 환원하지 말고");
  });

  it("상대 행동체크가 있으면 근거에 실리고 관계 신뢰도를 올린다", () => {
    const ev = buildPersonDeepEvidence({
      chartB,
      chartA,
      hasLuck: true,
      partnerCheck: { wordsMatchActions: "말은 잘하는데 약속은 자주 미룬다" },
    })!;
    expect(ev.evidence).toContain("[상대 행동 체크 — 사용자 입력]");
    expect(ev.evidence).toContain("말은 잘하는데 약속은 자주 미룬다");
  });

  it("상대 원국이 없으면 null", () => {
    expect(buildPersonDeepEvidence({ chartB: null, chartA })).toBeNull();
  });
});

describe("systemPrompt 배선: 상대 완전분석(personDeep)", () => {
  const counterpart = buildPersonDeepEvidence({ chartB, chartA, relationType: "romantic", hasLuck: true })!;
  const counterpartBlock = `${counterpart.evidence}\n\n${counterpart.instruction}`;

  it("analysisMode=personDeep면 16항목 구조 지시와 상대 근거가 들어간다", () => {
    const msg = buildReadingUserMessage({
      type: "saju",
      question: "이 사람은 어떤 사람인가요?",
      gender: birthB.gender,
      sajuChart: chartB,
      context: { analysisMode: "personDeep", depth: "advanced", counterpart: counterpartBlock },
    });
    expect(msg).toContain("[상대 완전분석 — 출력 구조 지정]");
    expect(msg).toContain("# 말과 행동 불일치");
    expect(msg).toContain("# 확실 / 추정 / 확인 필요");
    expect(msg).toContain("[상대 완전분석 — 작동방식·신뢰도 — 계산됨]");
  });

  it("personDeep면 표준/고급 섹션 지시를 태우지 않는다", () => {
    const msg = buildReadingUserMessage({
      type: "saju",
      question: "이 사람은 어떤 사람인가요?",
      gender: birthB.gender,
      sajuChart: chartB,
      context: { analysisMode: "personDeep", depth: "advanced", counterpart: counterpartBlock },
    });
    expect(msg).not.toContain("[고급 리딩]");
    expect(msg).not.toContain("[기본 리딩 구조]");
  });

  it("일반 리딩에는 상대 완전분석 구조가 들어가지 않는다", () => {
    const msg = buildReadingUserMessage({ type: "saju", question: "요즘 어때요?", gender: birthB.gender, sajuChart: chartB });
    expect(msg).not.toContain("[상대 완전분석 — 출력 구조 지정]");
  });
});
