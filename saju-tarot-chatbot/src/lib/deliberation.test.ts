import { describe, expect, it } from "vitest";
import { buildDeliberation, formatDeliberation } from "./deliberation.js";
import { computeSajuChart, computeLuckCycles } from "./saju.js";
import { buildReadingUserMessage } from "../prompts/systemPrompt.js";
import type { BirthInfo } from "../types/index.js";

const birth: BirthInfo = { calendarType: "solar", year: 1990, month: 12, day: 23, hour: 8, minute: 0, gender: "female" };
const chart = computeSajuChart(birth);
const luck = computeLuckCycles(birth, new Date("2026-07-08T03:00:00Z"));

const JARGON = ["일간", "월지", "천간", "지지", "십성", "비겁", "식상", "재성", "관성", "인성", "세운", "대운", "용신"];
const FORBIDDEN = ["반드시", "무조건", "100%", "절대", "망한다"];

describe("buildDeliberation (지금 저울질 신호 엔진)", () => {
  it("원국이 없으면 null", () => {
    expect(buildDeliberation(undefined, luck)).toBeNull();
  });

  it("결정론: 같은 입력이면 같은 결과", () => {
    expect(buildDeliberation(chart, luck)).toEqual(buildDeliberation(chart, luck));
  });

  it("신호가 나오면 상위 1~2개 저울질 가설을 담는다", () => {
    const d = buildDeliberation(chart, luck);
    if (d) {
      expect(d.signals.length).toBeGreaterThanOrEqual(1);
      expect(d.signals.length).toBeLessThanOrEqual(2);
      expect(d.headline).toContain("오가는");
      for (const s of d.signals) expect(s.hypothesis).toContain("때입니다");
    }
  });

  it("표면 문장에 사주 용어·단정 표현을 노출하지 않는다", () => {
    const d = buildDeliberation(chart, luck);
    if (d) {
      const surface = [d.headline, ...d.signals.map((s) => s.hypothesis)].join(" ");
      for (const term of [...JARGON, ...FORBIDDEN]) expect(surface).not.toContain(term);
    }
  });

  it("되짚어 묻는 톤: 저울질 가설은 '~쉬운 때'처럼 경향으로 쓴다", () => {
    const d = buildDeliberation(chart, luck);
    if (d) for (const s of d.signals) expect(s.hypothesis).toMatch(/쉬운 때|고민이 들기 쉬운/);
  });

  it("formatDeliberation은 근거 블록으로 직렬화한다", () => {
    const d = buildDeliberation(chart, luck);
    if (d) {
      const text = formatDeliberation(d);
      expect(text).toContain("(근거)");
    }
  });
});

describe("systemPrompt 배선: 지금 저울질 신호", () => {
  it("사주 리딩에 신호가 있으면 블록과 활용 안내를 전달한다", () => {
    const msg = buildReadingUserMessage({ type: "saju", question: "", gender: birth.gender, sajuChart: chart, luckCycles: luck });
    if (msg.includes("[지금 저울질 신호 — 계산됨")) {
      expect(msg).toContain("지금 저울질 신호 활용 안내");
      expect(msg).toContain("확인을 청하는 톤");
    }
  });

  it("순수 타로(원국 없음)에는 붙지 않는다", () => {
    const msg = buildReadingUserMessage({ type: "tarot", question: "이 관계 어때요?", tarotCards: [] });
    expect(msg).not.toContain("[지금 저울질 신호");
  });
});
