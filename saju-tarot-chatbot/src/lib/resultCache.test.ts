import { beforeEach, describe, expect, it } from "vitest";
import { getCachedResult, periodBucket, setCachedResult } from "./resultCache.js";

// node 환경에는 localStorage가 없으므로 인메모리로 대체한다.
function installMemoryLocalStorage() {
  const store = new Map<string, string>();
  const mock = {
    getItem: (k: string) => (store.has(k) ? store.get(k)! : null),
    setItem: (k: string, v: string) => void store.set(k, v),
    removeItem: (k: string) => void store.delete(k),
    clear: () => store.clear(),
    key: (i: number) => Array.from(store.keys())[i] ?? null,
    get length() {
      return store.size;
    },
  };
  (globalThis as unknown as { localStorage: typeof mock }).localStorage = mock;
}

describe("결과 캐시", () => {
  beforeEach(() => {
    installMemoryLocalStorage();
    localStorage.clear();
  });

  it("같은 입력이면 저장한 값을 그대로 돌려준다", () => {
    const key = { type: "saju", chart: { day: "갑자" }, q: "직업" };
    expect(getCachedResult<string>("reading", key)).toBeNull();
    setCachedResult("reading", key, "결과 텍스트");
    expect(getCachedResult<string>("reading", key)).toBe("결과 텍스트");
  });

  it("키 순서가 달라도 같은 항목으로 취급한다", () => {
    setCachedResult("reading", { a: 1, b: 2 }, "X");
    expect(getCachedResult<string>("reading", { b: 2, a: 1 })).toBe("X");
  });

  it("입력이 다르면 캐시가 분리된다", () => {
    setCachedResult("reading", { q: "A" }, "aa");
    expect(getCachedResult<string>("reading", { q: "B" })).toBeNull();
  });

  it("네임스페이스가 다르면 분리된다", () => {
    setCachedResult("reading", { q: "A" }, "aa");
    expect(getCachedResult<string>("naming-recommend", { q: "A" })).toBeNull();
  });

  it("기간 버킷은 월/일 형식을 낸다", () => {
    expect(periodBucket("month")).toMatch(/^\d{4}-\d{2}$/);
    expect(periodBucket("day")).toMatch(/^\d{4}-\d{2}-\d{2}$/);
  });
});
