import { describe, expect, it } from "vitest";
import { buildPsychLayer, formatPsychLayer } from "./psychLayer.js";
import { computeSajuChart, computeLuckCycles } from "./saju.js";
import { buildReadingUserMessage } from "../prompts/systemPrompt.js";
import type { BirthInfo, SajuChart } from "../types/index.js";

const birth: BirthInfo = { calendarType: "solar", year: 1990, month: 12, day: 23, hour: 8, minute: 0, gender: "female" };
const chart = computeSajuChart(birth);
const luck = computeLuckCycles(birth, new Date("2026-07-03T03:00:00Z"));

// 표면 문장에 절대 나오면 안 되는 사주 용어(다음절만; 단음절 한자어는 평범한 한글과 겹쳐 오탐).
const SAJU_JARGON = [
  "일간", "월지", "천간", "지지", "십성", "비겁", "식상", "재성", "관성", "인성",
  "세운", "대운", "월운", "용신", "기신", "신강", "신약",
];
// 표면에 노출하면 안 되는 심리·상담 용어(심리 검사처럼 보이면 실패).
const PSYCH_JARGON = ["애착", "회피형", "불안형", "방어기제", "번아웃", "우울증", "불안장애"];
const FORBIDDEN = ["반드시", "무조건", "100%", "절대", "망한다", "이혼합니다"];

const surfaceOf = (p: ReturnType<typeof buildPsychLayer>) =>
  [
    p!.coreDesire,
    p!.outerInner ?? "",
    p!.defense,
    p!.recognitionDecision,
    p!.attachment,
    p!.stressPattern,
    p!.repeatedPattern,
  ].join(" ");

describe("buildPsychLayer (속마음 레이어 엔진)", () => {
  it("원국이 있으면 속마음 레이어를 계산해 낸다", () => {
    const p = buildPsychLayer(chart);
    expect(p).not.toBeNull();
    expect(p!.coreDesire.length).toBeGreaterThan(10);
    expect(p!.defense.length).toBeGreaterThan(10);
    expect(p!.repeatedPattern.length).toBeGreaterThan(10);
    expect(["확실", "추정"]).toContain(p!.confidence);
  });

  it("원국이 없으면 null (순수 타로 등)", () => {
    expect(buildPsychLayer(undefined)).toBeNull();
  });

  it("십성 근거가 전혀 없으면 null", () => {
    const empty: SajuChart = { ...chart, tenGods: [], branchTenGods: [], tenGodDistribution: undefined };
    expect(buildPsychLayer(empty)).toBeNull();
  });

  it("결정론: 같은 입력이면 항상 같은 결과", () => {
    expect(buildPsychLayer(chart)).toEqual(buildPsychLayer(chart));
  });

  it("표면 문장에 사주 용어를 노출하지 않는다", () => {
    const surface = surfaceOf(buildPsychLayer(chart));
    for (const term of SAJU_JARGON) expect(surface).not.toContain(term);
  });

  it("표면 문장에 심리·상담 용어(진단명 포함)를 노출하지 않는다", () => {
    const surface = surfaceOf(buildPsychLayer(chart));
    for (const term of PSYCH_JARGON) expect(surface).not.toContain(term);
  });

  it("표면 문장에 단정·공포 표현을 쓰지 않는다", () => {
    const surface = surfaceOf(buildPsychLayer(chart));
    for (const term of FORBIDDEN) expect(surface).not.toContain(term);
  });

  it("겉(천간)과 속(지지) 지배 그룹이 다르면 '겉과 속' 대비를 만든다", () => {
    const split: SajuChart = {
      ...chart,
      tenGods: ["연간 갑: 편재", "월간 갑: 편재", "시간 갑: 편재"], // 겉 = 재성
      branchTenGods: ["연지 자: 정인", "월지 자: 정인", "일지 자: 정인", "시지 자: 정인"], // 속 = 인성
      tenGodDistribution: undefined,
    };
    const p = buildPsychLayer(split)!;
    expect(p.outerInner).not.toBeNull();
    expect(p.outerInner).toContain("겉으로는");
    expect(p.outerInner).toContain("속으로는");
  });

  it("지배 십성 그룹에 맞는 핵심 욕구·방어 문장을 고른다", () => {
    const officer: SajuChart = { ...chart, tenGodDistribution: { 정관: 10, 편재: 1 } };
    const p = buildPsychLayer(officer)!;
    expect(p.coreDesire).toContain("책임을 지려는");
    expect(p.confidence).toBe("확실");
  });

  it("일지(가장 가까운 관계 자리)의 십성으로 애착 경향을 잡는다", () => {
    const p = buildPsychLayer(chart)!;
    expect(p.attachment.length).toBeGreaterThan(10);
    // 일지 근거가 evidence에 남는다.
    expect(p.evidence.join(" ")).toMatch(/일지|관계 축/);
  });

  it("formatPsychLayer는 근거 블록 문자열로 직렬화한다", () => {
    const text = formatPsychLayer(buildPsychLayer(chart)!);
    expect(text).toContain("핵심 욕구:");
    expect(text).toContain("(근거)");
  });
});

describe("systemPrompt 배선: 속마음 레이어가 원국 리딩에 붙는다", () => {
  it("사주 리딩에 [속마음 레이어] 블록과 활용 안내를 전달한다", () => {
    const msg = buildReadingUserMessage({ type: "saju", question: "요즘 지쳐요", gender: birth.gender, sajuChart: chart, luckCycles: luck });
    expect(msg).toContain("[속마음 레이어 — 계산됨");
    expect(msg).toContain("속마음 레이어 활용 안내");
  });

  it("가벼운(light) 리딩에도 [속마음 레이어]가 붙는다", () => {
    const msg = buildReadingUserMessage({
      type: "saju",
      question: "요즘 지쳐요",
      gender: birth.gender,
      sajuChart: chart,
      luckCycles: luck,
      context: { depth: "light" },
    });
    expect(msg).toContain("[속마음 레이어 — 계산됨");
  });

  it("순수 타로(원국 없음)에는 [속마음 레이어]가 붙지 않는다", () => {
    const msg = buildReadingUserMessage({ type: "tarot", question: "이 관계 어때요?", tarotCards: [] });
    expect(msg).not.toContain("[속마음 레이어 — 계산됨");
  });
});
