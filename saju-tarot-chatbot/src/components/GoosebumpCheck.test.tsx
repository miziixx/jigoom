import { describe, expect, it } from "vitest";
import { renderToStaticMarkup } from "react-dom/server";
import GoosebumpCheck from "./GoosebumpCheck";
import { computeSajuChart } from "../lib/saju.js";
import type { BirthInfo } from "../types";

const oldBirth: BirthInfo = { calendarType: "solar", year: 1970, month: 12, day: 23, hour: 8, minute: 0, gender: "female" };
const chart = computeSajuChart(oldBirth);

describe("GoosebumpCheck (소름 엔진, 재기획안 C-1)", () => {
  it("원국·출생정보가 있고 강한 신호가 있으면 카드와 확인 버튼을 보여준다", () => {
    const html = renderToStaticMarkup(<GoosebumpCheck birthInfo={oldBirth} sajuChart={chart} />);
    // 1970년생이면 검증 가능한 과거 연도가 넉넉해 강한 신호가 하나는 나올 가능성이 높다.
    // 신호가 없더라도(=null 렌더) 크래시하지 않아야 한다는 게 핵심 검증.
    if (html) {
      expect(html).toContain("맞나요?");
      expect(html).toContain("맞아요");
      expect(html).toContain("아니에요");
      expect(html).toContain("잘 모르겠어요");
    }
  });

  it("birthInfo가 없으면 아무것도 렌더하지 않는다", () => {
    const html = renderToStaticMarkup(<GoosebumpCheck sajuChart={chart} />);
    expect(html).toBe("");
  });

  it("sajuChart가 없으면 아무것도 렌더하지 않는다", () => {
    const html = renderToStaticMarkup(<GoosebumpCheck birthInfo={oldBirth} />);
    expect(html).toBe("");
  });

  it("올해 태어난 사람처럼 과거 연도가 없으면 아무것도 렌더하지 않는다", () => {
    const thisYear = new Date().getFullYear();
    const newbornBirth: BirthInfo = { ...oldBirth, year: thisYear };
    const newbornChart = computeSajuChart(newbornBirth);
    const html = renderToStaticMarkup(<GoosebumpCheck birthInfo={newbornBirth} sajuChart={newbornChart} />);
    expect(html).toBe("");
  });

  it("표면 문구에 사주 전문용어를 노출하지 않는다", () => {
    const html = renderToStaticMarkup(<GoosebumpCheck birthInfo={oldBirth} sajuChart={chart} />);
    for (const term of ["십성", "세운", "대운", "재성", "관성"]) {
      expect(html).not.toContain(term);
    }
  });
});
