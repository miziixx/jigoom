import { describe, expect, it } from "vitest";
import { buildCapacityAxes } from "./capacityAxis.js";
import { buildPsychLayer } from "./psychLayer.js";
import { buildConfidenceTiers, buildSelfDeepEvidence, deriveShadow } from "./selfDeep.js";
import { computeSajuChart } from "./saju.js";
import { buildReadingUserMessage } from "../prompts/systemPrompt.js";
import type { BirthInfo, PastValidationReport } from "../types/index.js";

const birth: BirthInfo = { calendarType: "solar", year: 1990, month: 12, day: 23, hour: 8, minute: 0, gender: "female" };
const chart = computeSajuChart(birth);

const JARGON = ["일간", "월지", "천간", "지지", "십성", "비겁", "식상", "재성", "관성", "인성", "통근", "신강", "신약", "용신", "기신", "세운", "대운"];
const FORBIDDEN = ["반드시", "무조건", "100%", "절대", "망한다"];
// 표면 문장에 심리 진단명이 새지 않아야 한다
const DIAGNOSIS = ["애착유형", "회피형", "불안형", "번아웃", "우울증", "공황"];

describe("deriveShadow (그림자·결핍 파생)", () => {
  it("psych/axes로 그림자 블록을 만든다", () => {
    const shadow = deriveShadow(buildPsychLayer(chart), buildCapacityAxes(chart));
    expect(shadow).not.toBeNull();
    expect(shadow!.headline.length).toBeGreaterThan(5);
    expect(shadow!.lines.length).toBeGreaterThan(0);
  });

  it("psych/axes가 둘 다 없으면 null", () => {
    expect(deriveShadow(null, null)).toBeNull();
  });

  it("표면 문장(headline·lines)에 사주 용어·진단명을 노출하지 않는다", () => {
    const shadow = deriveShadow(buildPsychLayer(chart), buildCapacityAxes(chart))!;
    const surface = [shadow.headline, ...shadow.lines].join(" ");
    for (const term of [...JARGON, ...DIAGNOSIS]) expect(surface).not.toContain(term);
  });

  it("표면 문장에 단정·공포 표현을 쓰지 않는다", () => {
    const shadow = deriveShadow(buildPsychLayer(chart), buildCapacityAxes(chart))!;
    const surface = [shadow.headline, ...shadow.lines].join(" ");
    for (const term of FORBIDDEN) expect(surface).not.toContain(term);
  });

  it("결정론: 같은 입력이면 같은 결과", () => {
    const a = deriveShadow(buildPsychLayer(chart), buildCapacityAxes(chart));
    const b = deriveShadow(buildPsychLayer(chart), buildCapacityAxes(chart));
    expect(a).toEqual(b);
  });
});

describe("buildConfidenceTiers (확실/추정/확인 필요)", () => {
  it("원국이 있으면 5개 분야를 3분류한다", () => {
    const tiers = buildConfidenceTiers({ chart, hasLuck: true });
    expect(tiers).not.toBeNull();
    expect(tiers!.items.length).toBe(5);
    for (const it of tiers!.items) {
      expect(["확실", "추정", "확인 필요"]).toContain(it.tier);
    }
  });

  it("원국이 없으면 null", () => {
    expect(buildConfidenceTiers({ chart: null })).toBeNull();
  });

  it("출생시간 오차가 있으면 시기·선택을 '확인 필요'로 낮춘다", () => {
    const tiers = buildConfidenceTiers({ chart, hasLuck: true, timeAccuracy: "over-hour" })!;
    const timing = tiers.items.find((i) => i.area === "시기·선택")!;
    expect(timing.tier).toBe("확인 필요");
  });

  it("과거검증에서 부합한 분야는 '확실'로 올린다", () => {
    const past: PastValidationReport = { matches: [], headline: "", reliableDomains: ["career"] };
    const tiers = buildConfidenceTiers({ chart, hasLuck: true, pastValidation: past })!;
    const career = tiers.items.find((i) => i.area === "일·돈")!;
    expect(career.tier).toBe("확실");
  });

  it("결정론: 같은 입력이면 같은 결과", () => {
    expect(buildConfidenceTiers({ chart, hasLuck: true })).toEqual(buildConfidenceTiers({ chart, hasLuck: true }));
  });
});

describe("buildSelfDeepEvidence (프롬프트 근거)", () => {
  it("그림자·신뢰도 근거 블록과 활용 안내를 만든다", () => {
    const ev = buildSelfDeepEvidence({ chart, hasLuck: true });
    expect(ev).not.toBeNull();
    expect(ev!.evidence).toContain("[자기 완전분석 — 그림자·신뢰도 — 계산됨]");
    expect(ev!.evidence).toContain("▸ 그림자·결핍·방어");
    expect(ev!.evidence).toContain("▸ 분야별 신뢰도");
    expect(ev!.instruction).toContain("그림자·결핍·방어");
  });

  it("원국이 없으면 null", () => {
    expect(buildSelfDeepEvidence({ chart: null })).toBeNull();
  });
});

describe("systemPrompt 배선: 자기 완전분석(selfDeep)", () => {
  it("analysisMode=selfDeep면 12블록 구조 지시와 그림자·신뢰도 근거가 들어간다", () => {
    const msg = buildReadingUserMessage({
      type: "saju",
      question: "나는 어떤 사람인가요?",
      gender: birth.gender,
      sajuChart: chart,
      context: { analysisMode: "selfDeep", depth: "advanced" },
    });
    expect(msg).toContain("[자기 완전분석 — 출력 구조 지정]");
    expect(msg).toContain("# 그림자·결핍·방어");
    expect(msg).toContain("# 확실 / 추정 / 확인 필요");
    expect(msg).toContain("[자기 완전분석 — 그림자·신뢰도 — 계산됨]");
  });

  it("selfDeep면 표준/고급 섹션 지시를 태우지 않는다", () => {
    const msg = buildReadingUserMessage({
      type: "saju",
      question: "나는 어떤 사람인가요?",
      gender: birth.gender,
      sajuChart: chart,
      context: { analysisMode: "selfDeep", depth: "advanced" },
    });
    expect(msg).not.toContain("[고급 리딩]");
    expect(msg).not.toContain("[기본 리딩 구조]");
  });

  it("selfCheck 입력이 있으면 별도 근거 블록으로 들어간다", () => {
    const msg = buildReadingUserMessage({
      type: "saju",
      question: "나는 어떤 사람인가요?",
      gender: birth.gender,
      sajuChart: chart,
      context: {
        analysisMode: "selfDeep",
        depth: "advanced",
        selfCheck: { angerStyle: "참았다 나중에 터진다" },
      },
    });
    expect(msg).toContain("[자기 행동 체크 — 사용자 입력]");
    expect(msg).toContain("참았다 나중에 터진다");
  });

  it("일반 리딩(selfDeep 아님)에는 완전분석 구조가 들어가지 않는다", () => {
    const msg = buildReadingUserMessage({ type: "saju", question: "요즘 어때요?", gender: birth.gender, sajuChart: chart });
    expect(msg).not.toContain("[자기 완전분석 — 출력 구조 지정]");
  });
});
