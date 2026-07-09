import { describe, expect, it } from "vitest";
import { renderToStaticMarkup } from "react-dom/server";
import { StaticRouter } from "react-router-dom/server";
import TrustBadges from "./TrustBadges";
import { computeSajuChart } from "../lib/saju.js";
import type { BirthInfo } from "../types";

const birth: BirthInfo = { calendarType: "solar", year: 1990, month: 12, day: 23, hour: 8, minute: 0, gender: "female" };
const chart = computeSajuChart(birth);

function render(node: React.ReactNode) {
  return renderToStaticMarkup(<StaticRouter location="/saju">{node}</StaticRouter>);
}

describe("TrustBadges (신뢰 배지, C-3)", () => {
  it("원국이 있으면 4대 고전·계산 근거 공개 배지와 안내 링크를 보여준다", () => {
    const html = render(<TrustBadges sajuChart={chart} />);
    expect(html).toContain("4대 고전 교차 검증");
    expect(html).toContain("계산 근거 전부 공개");
    expect(html).toContain("어떻게 계산하나요?");
  });

  it("출생 시각 보정이 적용된 원국이면 보정 배지를 함께 보여준다", () => {
    const html = render(<TrustBadges sajuChart={chart} />);
    if ((chart.timeCorrection?.applied.length ?? 0) > 0) {
      expect(html).toContain("출생 시각 분 단위 보정 적용");
    }
  });

  it("원국이 없으면 아무것도 렌더하지 않는다", () => {
    const html = render(<TrustBadges />);
    expect(html).toBe("");
  });
});
