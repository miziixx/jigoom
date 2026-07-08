import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import ArcGauge from "./ArcGauge.js";
import ElementRadarChart from "./ElementRadarChart.js";
import MonthlyFlowChart, { monthTone } from "./MonthlyFlowChart.js";
import RatingCell from "./RatingCell.js";
import TarotCardArt, { tarotSuitKeyOf } from "./TarotCardArt.js";
import { PartIcon, SectionIcon, VizIcon } from "./icons.js";
import { SealStamp, SectionDivider } from "./Motif.js";
import type { MonthFlowInfo } from "../../types/index.js";

describe("ElementRadarChart", () => {
  const balance = { wood: 3, fire: 1, earth: 2, metal: 0, water: 2 };

  it("데이터가 없으면 렌더하지 않는다", () => {
    expect(renderToStaticMarkup(<ElementRadarChart fiveElements={null} />)).toBe("");
  });

  it("오행 이름·수치·풀이 라벨을 모두 보여준다 (색만으로 구분 금지)", () => {
    const html = renderToStaticMarkup(<ElementRadarChart fiveElements={balance} />);
    expect(html).toContain("목 3");
    expect(html).toContain("화 1");
    expect(html).toContain("금 0");
    expect(html).toContain("성장·배움");
    expect(html).toContain("판단·정리");
  });

  it("캡션을 자동 생성해 최강/최약 기운을 설명한다", () => {
    const html = renderToStaticMarkup(<ElementRadarChart fiveElements={balance} />);
    expect(html).toContain("목(성장·배움) 기운이 가장 강하고");
    expect(html).toContain("금(판단·정리) 기운이 가장 옅어요");
  });
});

describe("ArcGauge", () => {
  it("tierLabel을 주면 숫자 대신 생활 언어 라벨을 보여준다", () => {
    const html = renderToStaticMarkup(<ArcGauge label="애정" score={72} tierLabel="잘 맞아요" />);
    expect(html).toContain("잘 맞아요");
    expect(html).not.toContain(">72<");
  });

  it("숫자 모드에서는 점수와 단위를 보여준다", () => {
    const html = renderToStaticMarkup(<ArcGauge label="총운" score={68} />);
    expect(html).toContain(">68<");
    expect(html).toContain("점");
    expect(html).toContain("viz-arc__fill--high");
  });

  it("neutral 톤은 좋고 나쁨 색을 쓰지 않는다", () => {
    const html = renderToStaticMarkup(<ArcGauge label="신강" score={62} tone="neutral" unit="%" />);
    expect(html).toContain("viz-arc__fill--neutral");
  });
});

describe("MonthlyFlowChart", () => {
  const flow: MonthFlowInfo[] = Array.from({ length: 12 }, (_, i) => ({
    month: i + 1,
    ganZhi: "갑자",
    interactions: i === 2 ? ["자오충", "인해합"] : i === 5 ? ["묘유충", "진술충", "축미충", "자묘형"] : [],
  }));

  it("데이터가 없거나 부족하면 렌더하지 않는다 (스트리밍 내성)", () => {
    expect(renderToStaticMarkup(<MonthlyFlowChart monthlyFlow={null} />)).toBe("");
    expect(renderToStaticMarkup(<MonthlyFlowChart monthlyFlow={[]} />)).toBe("");
  });

  it("12개 달 버튼과 4단계 톤 라벨을 렌더한다", () => {
    const html = renderToStaticMarkup(<MonthlyFlowChart monthlyFlow={flow} />);
    for (let m = 1; m <= 12; m += 1) expect(html).toContain(`${m}월`);
    expect(html).toContain("잔잔함");
    expect(html).toContain("흔들림 큼");
    expect(html).not.toMatch(/상호작용\s*\d+개/); // 숫자 노출 금지
  });

  it("선택된 달에 AI 월별 상세(키워드/조언)를 연결한다", () => {
    const currentMonth = new Date().getMonth() + 1;
    const details = [{ month: `${currentMonth}월`, keyword: "정리와 재정비", advice: "지출 점검" }];
    const html = renderToStaticMarkup(<MonthlyFlowChart monthlyFlow={flow} monthDetails={details} />);
    expect(html).toContain("정리와 재정비");
    expect(html).toContain("지출 점검");
  });

  it("monthTone은 개수를 쉬운 말 4단계로 바꾼다", () => {
    expect(monthTone(0).label).toBe("잔잔함");
    expect(monthTone(1).label).toBe("가벼운 자극");
    expect(monthTone(2).label).toBe("변화 있음");
    expect(monthTone(4).label).toBe("흔들림 큼");
  });
});

describe("TarotCardArt", () => {
  it("수트를 이름에서 판별한다", () => {
    expect(tarotSuitKeyOf("Ace of Cups (컵 에이스)", "minor")).toBe("cups");
    expect(tarotSuitKeyOf("The Fool (바보)", "major")).toBe("major");
    expect(tarotSuitKeyOf("Nine of Wands", "minor")).toBe("wands");
  });

  it("수트 배너·영문 이름·한글 이름을 렌더한다", () => {
    const html = renderToStaticMarkup(<TarotCardArt name="Knight of Pentacles (펜타클 기사)" arcana="minor" koName="펜타클 기사" />);
    expect(html).toContain("PENTACLES");
    expect(html).toContain("Knight of");
    expect(html).toContain("펜타클 기사");
    expect(html).toContain("tarot-card-art--pentacles");
  });
});

describe("RatingCell", () => {
  it("등급 단어를 항상 함께 보여준다", () => {
    expect(renderToStaticMarkup(<RatingCell rating="good" />)).toContain("좋음");
    expect(renderToStaticMarkup(<RatingCell rating="mid" />)).toContain("보통");
    expect(renderToStaticMarkup(<RatingCell rating="caution" />)).toContain("주의");
  });
});

describe("icons & motifs", () => {
  it("아이콘은 장식으로 렌더된다 (aria-hidden)", () => {
    expect(renderToStaticMarkup(<SectionIcon tone="money" />)).toContain('aria-hidden="true"');
    expect(renderToStaticMarkup(<PartIcon tone="caution" />)).toContain('aria-hidden="true"');
    expect(renderToStaticMarkup(<VizIcon name="compass" />)).toContain("viz-icon");
  });

  it("모르는 tone은 기본 아이콘으로 조용히 폴백한다", () => {
    expect(renderToStaticMarkup(<SectionIcon tone="없는톤" />)).toContain("svg");
  });

  it("모티프는 장식이고 낙관은 글자를 담는다", () => {
    expect(renderToStaticMarkup(<SectionDivider />)).toContain('aria-hidden="true"');
    expect(renderToStaticMarkup(<SealStamp text="갑자" />)).toContain("갑자");
  });
});
