import { renderToStaticMarkup } from "react-dom/server";
import { StaticRouter } from "react-router-dom/server";
import { describe, expect, it } from "vitest";
import LandingPage from "./LandingPage.js";

describe("LandingPage (홈 카드 전면 개편, 시안 ①)", () => {
  const html = renderToStaticMarkup(
    <StaticRouter location="/">
      <LandingPage />
    </StaticRouter>,
  );

  it("오늘 인사말(일진·절기 계산 기반)을 헤더에 보여준다", () => {
    expect(html).toContain("요일");
    expect(html).toContain("무렵");
  });

  it("무료 오늘의 흐름 카드가 /fortune로 연결된다", () => {
    expect(html).toContain("오늘의 흐름 자세히");
    expect(html).toMatch(/href="\/fortune"[^>]*>[\s\S]*?오늘의 흐름 자세히/);
  });

  it("토픽 5종(택일 제외)이 모두 /saju로 연결된다", () => {
    for (const label of ["연애운", "재물운", "직업운", "건강운", "올해운"]) {
      expect(html).toContain(label);
    }
    expect(html).not.toContain("택일");
  });

  it("깊게 보기 3종 리포트를 보여준다(가격 노출 없음)", () => {
    expect(html).toContain("평생사주 리포트");
    expect(html).toContain("나 해부 리포트");
    expect(html).toContain("고민상담 리딩");
    expect(html).not.toMatch(/\d,\d{3}\s*원?/);
  });

  it("관계 섹션(정밀 궁합·상대 해부)을 보여준다", () => {
    expect(html).toContain("정밀 궁합");
    expect(html).toContain("상대 해부");
  });

  it("이름 감정·작명 링크를 하단에 보여준다", () => {
    expect(html).toContain("이름 감정·작명");
  });
});
