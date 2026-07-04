import { renderToStaticMarkup } from "react-dom/server";
import { StaticRouter } from "react-router-dom/server";
import { describe, expect, it } from "vitest";
import PrivacyPage from "./PrivacyPage.js";

describe("PrivacyPage", () => {
  const html = renderToStaticMarkup(
    <StaticRouter location="/privacy">
      <PrivacyPage />
    </StaticRouter>,
  );

  it("개인정보 처리 안내의 핵심 섹션을 보여준다", () => {
    expect(html).toContain("개인정보 안내");
    expect(html).toContain("처리하는 정보와 목적");
    expect(html).toContain("외부 AI 사용");
    expect(html).toContain("보관과 삭제");
    expect(html).toContain("이용자 권리");
  });

  it("생년월일 원본 대신 계산된 정보가 전송된다는 점을 설명한다", () => {
    expect(html).toContain("생년월일 원본 대신 계산된 사주 정보");
    expect(html).toContain("생년월일 원본은 AI 문장 생성 요청에 직접 보내지 않도록");
  });

  it("상세 고지에는 현재 외부 AI 제공자를 투명하게 표시한다", () => {
    expect(html).toContain("Anthropic API");
  });
});
