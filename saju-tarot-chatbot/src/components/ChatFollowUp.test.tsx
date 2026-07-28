import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import ChatFollowUp from "./ChatFollowUp.js";
import type { ReadingSession } from "../types/index.js";

function makeSession(): ReadingSession {
  return {
    id: "chat1",
    type: "saju",
    createdAt: "2026-07-04T00:00:00.000Z",
    question: "연애운",
    messages: [
      { role: "user", content: "연애운" },
      { role: "assistant", content: "리딩" },
    ],
  };
}

describe("ChatFollowUp", () => {
  it("정밀 리딩 주제를 더 깊게 물어볼 수 있음을 안내한다", () => {
    const html = renderToStaticMarkup(<ChatFollowUp session={makeSession()} onSend={() => {}} loading={false} />);

    expect(html).toContain("연애운·금전운·직업운");
    expect(html).toContain("더 깊게 파고들");
    expect(html).toContain("예: 왜 관계에서 비슷한 패턴이 반복되는지");
    expect(html).toContain("예: 돈이 새는 습관");
    expect(html).toContain("예: 지금 일에서 버틸지 바꿀지");
  });
});
