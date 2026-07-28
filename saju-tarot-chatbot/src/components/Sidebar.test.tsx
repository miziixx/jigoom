import { beforeEach, describe, expect, it } from "vitest";
import { renderToStaticMarkup } from "react-dom/server";
import { StaticRouter } from "react-router-dom/server";
import Sidebar from "./Sidebar";

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

describe("Sidebar (C-4 사이드바)", () => {
  beforeEach(() => {
    installMemoryLocalStorage();
    localStorage.clear();
  });

  it("초기 상태(닫힘)에서는 햄버거 토글 버튼만 렌더한다 — 나머지 상호작용은 브라우저로 검증", () => {
    const html = renderToStaticMarkup(
      <StaticRouter location="/">
        <Sidebar />
      </StaticRouter>,
    );
    expect(html).toContain("메뉴 열기");
    // 패널(저장된 사주 전환 등)은 open=false 초기 상태에서는 렌더되지 않는다.
    expect(html).not.toContain("저장된 사주 전환");
  });
});
