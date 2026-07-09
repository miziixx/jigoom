import { describe, expect, it } from "vitest";
import { renderToStaticMarkup } from "react-dom/server";
import BasicReadingSection from "./BasicReadingSection";
import { computeSajuChart, computeLuckCycles } from "../lib/saju.js";
import type { BirthInfo } from "../types";

const birth: BirthInfo = { calendarType: "solar", year: 1990, month: 12, day: 23, hour: 8, minute: 0, gender: "female" };
const chart = computeSajuChart(birth);
const luck = computeLuckCycles(birth, new Date("2026-07-03T03:00:00Z"), { includeMonthlyFlow: true });

// 사주 전문용어는 근거에만 있어야 하고 표면 문구에는 나오면 안 된다 (CLAUDE.md 규칙).
const SAJU_JARGON = ["일간", "월지", "천간", "지지", "십성", "비겁", "식상", "재성", "관성", "인성"];

describe("BasicReadingSection (무료 기본 리딩 상단 노출)", () => {
  it("원국·대운이 있으면 내 사용 설명서 + 올해 흐름 캘린더를 렌더한다", () => {
    const html = renderToStaticMarkup(
      <BasicReadingSection sajuChart={chart} luckCycles={luck} gender="female" />,
    );
    expect(html).toContain("내 사용 설명서");
    expect(html).toContain("올해 흐름 미니 캘린더");
    expect(html).toContain("바로 보는 요약"); // 승격된 InstantSummary
  });

  it("입력이 없으면 아무것도 렌더하지 않는다", () => {
    const html = renderToStaticMarkup(<BasicReadingSection />);
    expect(html).toBe("");
  });

  it("표면 문구에 사주 전문용어를 노출하지 않는다", () => {
    const html = renderToStaticMarkup(
      <BasicReadingSection sajuChart={chart} luckCycles={luck} gender="female" />,
    );
    for (const term of SAJU_JARGON) expect(html).not.toContain(term);
  });

  it("원국이 있으면 토픽 심화 진입 칩 5개(연애/재물/직업/건강/올해)를 보여준다 (A-2 CTA 연결)", () => {
    const html = renderToStaticMarkup(
      <BasicReadingSection sajuChart={chart} luckCycles={luck} gender="female" />,
    );
    for (const label of ["연애운 더 보기", "재물운 더 보기", "직업운 더 보기", "건강운 더 보기", "올해운 더 보기"]) {
      expect(html).toContain(label);
    }
  });

  it("아직 아무 토픽도 클릭하지 않았으면 토픽 심화 말풍선 영역은 렌더하지 않는다", () => {
    const html = renderToStaticMarkup(
      <BasicReadingSection sajuChart={chart} luckCycles={luck} gender="female" />,
    );
    expect(html).not.toContain("topic-deep-chat");
  });

  it("원국이 없으면 토픽 심화 칩도 렌더하지 않는다", () => {
    const html = renderToStaticMarkup(<BasicReadingSection />);
    expect(html).not.toContain("topic-deep-chip");
  });
});
