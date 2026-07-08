import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import ArcGauge from "./ArcGauge.js";
import ElementRadarChart from "./ElementRadarChart.js";
import MonthlyFlowChart from "./MonthlyFlowChart.js";
import { describeMonthFlow } from "../../lib/monthFlowNarrative.js";
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

  it("describeMonthFlow는 상호작용이 없으면 잔잔한 문구를 반환한다", () => {
    const quiet = describeMonthFlow({ month: 1, ganZhi: "갑자", interactions: [] });
    expect(quiet.label).toBe("잔잔함");
    expect(quiet.level).toBe(0);
  });

  it("describeMonthFlow는 실제 상호작용 내용(관계 종류·자리)에 따라 서로 다른 문구를 만든다", () => {
    const clash = describeMonthFlow({ month: 3, ganZhi: "병인", interactions: ["일지-월운 자오충"] });
    const combine = describeMonthFlow({ month: 7, ganZhi: "을미", interactions: ["일간-월운 을경합(금)"] });
    // 같은 개수(1개)여도 관계 종류·자리가 다르면 문구가 달라야 한다 (기존엔 둘 다 "가벼운 자극"으로 뭉뚱그려짐)
    expect(clash.label).not.toBe(combine.label);
    expect(clash.detail).not.toBe(combine.detail);
    expect(clash.detail).toContain("배우자");
    expect(combine.detail).toContain("나 자신");
  });

  it("describeMonthFlow의 level은 상호작용 개수를 기준으로 차트 높이를 유지한다", () => {
    expect(describeMonthFlow({ month: 1, ganZhi: "갑자", interactions: [] }).level).toBe(0);
    expect(describeMonthFlow({ month: 1, ganZhi: "갑자", interactions: ["일지-월운 자오충"] }).level).toBe(1);
    expect(describeMonthFlow({ month: 1, ganZhi: "갑자", interactions: ["일지-월운 자오충", "일간-월운 을경합(금)"] }).level).toBe(2);
    expect(
      describeMonthFlow({
        month: 1,
        ganZhi: "갑자",
        interactions: ["일지-월운 자오충", "일간-월운 을경합(금)", "월지-월운 묘유충", "시지-월운 축미충"],
      }).level,
    ).toBe(3);
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
