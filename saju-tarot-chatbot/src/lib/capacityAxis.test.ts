import { describe, expect, it } from "vitest";
import { buildCapacityAxes, formatCapacityAxes } from "./capacityAxis.js";
import { computeSajuChart } from "./saju.js";
import { buildReadingUserMessage } from "../prompts/systemPrompt.js";
import type { BirthInfo, SajuChart } from "../types/index.js";

const birth: BirthInfo = { calendarType: "solar", year: 1990, month: 12, day: 23, hour: 8, minute: 0, gender: "female" };
const chart = computeSajuChart(birth);

const JARGON = ["일간", "월지", "천간", "지지", "십성", "비겁", "식상", "재성", "관성", "인성", "통근", "신강", "신약", "용신", "기신"];
const FORBIDDEN = ["반드시", "무조건", "100%", "절대", "망한다"];

describe("buildCapacityAxes (재료축/출력축 엔진)", () => {
  it("원국이 있으면 다섯 기질 각각의 재료·출력을 계산한다", () => {
    const axes = buildCapacityAxes(chart);
    expect(axes).not.toBeNull();
    expect(axes!.length).toBe(5);
    for (const a of axes!) {
      expect(["강", "중", "약"]).toContain(a.material);
      expect(["강", "중", "약"]).toContain(a.output);
      expect(a.read.length).toBeGreaterThan(10);
    }
  });

  it("원국이 없으면 null", () => {
    expect(buildCapacityAxes(undefined)).toBeNull();
  });

  it("결정론: 같은 입력이면 항상 같은 결과", () => {
    expect(buildCapacityAxes(chart)).toEqual(buildCapacityAxes(chart));
  });

  it("재료 많은 순으로 정렬한다", () => {
    const axes = buildCapacityAxes(chart)!;
    for (let i = 1; i < axes.length; i += 1) {
      expect(axes[i - 1].materialScore).toBeGreaterThanOrEqual(axes[i].materialScore);
    }
  });

  it("표면 문장(read)에 사주 용어를 노출하지 않는다", () => {
    const surface = buildCapacityAxes(chart)!.map((a) => a.read).join(" ");
    for (const term of JARGON) expect(surface).not.toContain(term);
  });

  it("표면 문장에 단정·공포 표현을 쓰지 않는다", () => {
    const surface = buildCapacityAxes(chart)!.map((a) => a.read).join(" ");
    for (const term of FORBIDDEN) expect(surface).not.toContain(term);
  });

  it("신약이면 설기 기질(식상·재성·관성)의 출력이 강으로 나오지 않는다", () => {
    const weak: SajuChart = {
      ...chart,
      strength: { supportScore: 1, totalScore: 1, label: "신약", detail: "테스트용 신약" },
    };
    const axes = buildCapacityAxes(weak)!;
    for (const g of ["식상", "재성", "관성"]) {
      const item = axes.find((a) => a.group === g)!;
      expect(item.output).not.toBe("강");
    }
  });

  it("신강이면 신약보다 설기 기질의 출력 점수가 높다", () => {
    const weak: SajuChart = { ...chart, strength: { supportScore: 1, totalScore: 1, label: "신약", detail: "약" } };
    const strong: SajuChart = { ...chart, strength: { supportScore: 9, totalScore: 9, label: "신강", detail: "강" } };
    const wRe = buildCapacityAxes(weak)!.find((a) => a.group === "재성")!;
    const sRe = buildCapacityAxes(strong)!.find((a) => a.group === "재성")!;
    expect(sRe.outputScore).toBeGreaterThan(wRe.outputScore);
  });

  it("formatCapacityAxes는 근거 블록으로 직렬화한다", () => {
    const text = formatCapacityAxes(buildCapacityAxes(chart)!);
    expect(text).toContain("재료");
    expect(text).toContain("출력");
    expect(text).toContain("(근거)");
  });
});

describe("systemPrompt 배선: 재료-출력 대비", () => {
  it("사주 리딩에 통합 심리 블록 안에 '재료 vs 실제 쓸 힘' 소재로 들어간다", () => {
    const msg = buildReadingUserMessage({ type: "saju", question: "요즘 어때요?", gender: birth.gender, sajuChart: chart });
    expect(msg).toContain("[속마음·현재 심리 — 계산됨");
    expect(msg).toContain("▸ 재료 vs 실제 쓸 힘");
  });

  it("가벼운(light) 리딩에서는 재료-출력이 빠진다(압축 유지)", () => {
    const msg = buildReadingUserMessage({ type: "saju", question: "요즘 어때요?", gender: birth.gender, sajuChart: chart, context: { depth: "light" } });
    expect(msg).not.toContain("▸ 재료 vs 실제 쓸 힘");
  });

  it("순수 타로(원국 없음)에는 붙지 않는다", () => {
    const msg = buildReadingUserMessage({ type: "tarot", question: "이 관계 어때요?", tarotCards: [] });
    expect(msg).not.toContain("▸ 재료 vs 실제 쓸 힘");
  });
});
