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
});
