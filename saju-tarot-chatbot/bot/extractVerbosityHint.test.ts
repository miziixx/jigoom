import { describe, expect, it } from "vitest";
import { extractVerbosityHint } from "./extractVerbosityHint.js";

describe("extractVerbosityHint", () => {
  it("힌트가 없으면 override 없이 질문을 그대로 둔다", () => {
    const r = extractVerbosityHint("나 왜 신약사주야?");
    expect(r.override).toBeUndefined();
    expect(r.cleanQuestion).toBe("나 왜 신약사주야?");
  });

  it("'짧게'가 있으면 brief로 잡고 힌트를 질문에서 뺀다", () => {
    const r = extractVerbosityHint("나 왜 신약사주야? 짧게");
    expect(r.override).toBe("brief");
    expect(r.cleanQuestion).not.toContain("짧게");
    expect(r.cleanQuestion).toContain("신약사주");
  });

  it("'간단히', '요약', '핵심만'도 brief로 잡는다", () => {
    expect(extractVerbosityHint("성격 간단히 봐줘").override).toBe("brief");
    expect(extractVerbosityHint("요약해줘").override).toBe("brief");
    expect(extractVerbosityHint("핵심만 알려줘").override).toBe("brief");
  });

  it("'자세히', '길게', '깊게'는 detailed로 잡는다", () => {
    expect(extractVerbosityHint("오늘 일진 자세히 풀어줘").override).toBe("detailed");
    expect(extractVerbosityHint("궁합 길게 봐줘").override).toBe("detailed");
    expect(extractVerbosityHint("깊게 설명해").override).toBe("detailed");
  });

  it("'일반', '보통'은 normal로 리셋한다", () => {
    expect(extractVerbosityHint("일반적으로 설명해").override).toBe("normal");
    expect(extractVerbosityHint("보통 길이로").override).toBe("normal");
  });

  it("힌트를 뺀 질문의 앞뒤 공백은 정리된다", () => {
    const r = extractVerbosityHint("짧게 신강신약 설명");
    expect(r.override).toBe("brief");
    expect(r.cleanQuestion).toBe("신강신약 설명");
  });
});
