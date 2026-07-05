import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import LoadingNotice from "./LoadingNotice.js";

describe("LoadingNotice", () => {
  it("리딩 대기 중 미니게임을 함께 보여준다", () => {
    const html = renderToStaticMarkup(<LoadingNotice type="saju" hasQuestion replyText="# 첫 점괘\n작성 중" />);

    expect(html).toContain("계산은 끝났고");
    expect(html).toContain("loading-game");
    expect(html).toMatch(/미니 오목|윷놀이/);
  });
});
