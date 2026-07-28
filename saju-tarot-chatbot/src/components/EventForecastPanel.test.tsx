import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import EventForecastPanel from "./EventForecastPanel.js";
import { computeSajuChart, computeLuckCycles } from "../lib/saju.js";
import type { BirthInfo } from "../types/index.js";

const female1990: BirthInfo = { calendarType: "solar", year: 1990, month: 12, day: 23, hour: 8, minute: 0, gender: "female" };

describe("EventForecastPanel", () => {
  it("차트가 없으면 렌더하지 않는다", () => {
    expect(renderToStaticMarkup(<EventForecastPanel />)).toBe("");
  });

  it("분야 라벨과 헤드라인을 보여준다", () => {
    const chart = computeSajuChart(female1990);
    const luck = computeLuckCycles(female1990, new Date("2026-07-03T03:00:00Z"));
    const html = renderToStaticMarkup(
      <EventForecastPanel sajuChart={chart} luckCycles={luck} gender={female1990.gender} />,
    );
    expect(html).toContain("지금 움직이는 분야");
    // 전체 분야 접힘 영역에는 모든 분야 라벨이 있다
    expect(html).toContain("직업·일");
    expect(html).toContain("건강·컨디션");
    expect(html).toContain("이사·이동");
    // 참고 자료 안내(단정 아님)
    expect(html).toContain("정해진 길흉이 아니라");
  });

  it("표면에 사주 전문용어(십성/충/합)를 노출하지 않는다", () => {
    const chart = computeSajuChart(female1990);
    const luck = computeLuckCycles(female1990, new Date("2026-07-03T03:00:00Z"));
    const html = renderToStaticMarkup(
      <EventForecastPanel sajuChart={chart} luckCycles={luck} gender={female1990.gender} />,
    );
    for (const term of ["편재", "정관", "식신", "비견"]) expect(html).not.toContain(term);
  });
});
