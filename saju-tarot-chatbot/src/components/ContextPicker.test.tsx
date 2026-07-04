import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import ContextPicker from "./ContextPicker.js";

describe("ContextPicker", () => {
  it("풀이 말투를 카드형 선택지로 보여준다", () => {
    const html = renderToStaticMarkup(<ContextPicker value={{}} onChange={() => {}} />);

    expect(html).toContain("풀이 말투");
    expect(html).toContain("현실적으로");
    expect(html).toContain("따뜻하게");
    expect(html).toContain("냉정하게");
    expect(html).toContain("아주 자세하게");
    expect(html).toContain("같은 근거라도 원하는 말투");
  });
});
