import { renderToStaticMarkup } from "react-dom/server";
import { StaticRouter } from "react-router-dom/server";
import { describe, expect, it } from "vitest";
import MethodologyPage from "./MethodologyPage.js";

describe("MethodologyPage (신뢰 배지 표면화, C-3)", () => {
  const html = renderToStaticMarkup(
    <StaticRouter location="/methodology">
      <MethodologyPage />
    </StaticRouter>,
  );

  it("출생 시각 보정(서머타임·진태양시)을 설명한다", () => {
    expect(html).toContain("서머타임 보정");
    expect(html).toContain("진태양시 보정");
  });

  it("4대 고전 교차 검증을 설명한다", () => {
    for (const classic of ["자평진전", "연해자평", "궁통보감", "삼명통회"]) {
      expect(html).toContain(classic);
    }
  });

  it("계산 근거 공개를 설명한다", () => {
    expect(html).toContain("계산 근거는 전부 공개");
  });

  it("한계를 정직하게 밝힌다", () => {
    expect(html).toContain("한계도 정직하게");
    expect(html).toContain("판본");
  });
});
