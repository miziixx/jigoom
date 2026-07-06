import { renderToStaticMarkup } from "react-dom/server";
import { StaticRouter } from "react-router-dom/server";
import { describe, expect, it } from "vitest";
import QualityDashboardPage from "./QualityDashboardPage.js";

describe("QualityDashboardPage", () => {
  // 테스트(vitest)에서는 import.meta.env.DEV=true → 대시보드가 활성 경로로 렌더된다.
  const html = renderToStaticMarkup(
    <StaticRouter location="/_internal/quality">
      <QualityDashboardPage />
    </StaticRouter>,
  );

  it("활성 환경에서 핵심 카드를 렌더한다", () => {
    expect(html).toContain("AI Engine Health");
    expect(html).toContain("총 리딩");
    expect(html).toContain("Validation");
    expect(html).toContain("Rewrite");
    expect(html).toContain("Fallback");
    expect(html).toContain("개인정보 미저장");
  });

  it("개인정보(생년월일·이름·질문·원문)를 렌더하지 않는다", () => {
    expect(html).not.toMatch(/birthInfo|displayName|생년월일/);
  });
});
