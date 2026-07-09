import { beforeEach, describe, expect, it } from "vitest";
import { goosebumpAccuracySummary, loadGoosebumpConfirmations, saveGoosebumpConfirmation } from "./goosebumpStorage.js";
import type { GoosebumpConfirmation, GoosebumpGuess } from "../types";

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

const guess: GoosebumpGuess = {
  year: 2021,
  domain: "career",
  domainLabel: "직업·일",
  prompt: "2021년 무렵, 직업·역할이 움직이는 흐름이 있었을 것 같아요 — 맞나요?",
  strength: 4,
  evidence: [],
};

describe("goosebumpStorage (소름 엔진 C-1 확인/부인 저장)", () => {
  beforeEach(() => {
    installMemoryLocalStorage();
    localStorage.clear();
  });

  it("빈 상태에서는 확인 기록이 없다", () => {
    expect(loadGoosebumpConfirmations()).toEqual([]);
    expect(goosebumpAccuracySummary()).toEqual({ total: 0, yes: 0, no: 0, unsure: 0 });
  });

  it("확인을 저장하면 목록 맨 앞에 쌓인다", () => {
    const a: GoosebumpConfirmation = { guess, answer: "yes", answeredAt: "2026-01-01T00:00:00.000Z" };
    const b: GoosebumpConfirmation = { guess: { ...guess, year: 2019 }, answer: "no", answeredAt: "2026-01-02T00:00:00.000Z" };
    saveGoosebumpConfirmation(a);
    saveGoosebumpConfirmation(b);
    const list = loadGoosebumpConfirmations();
    expect(list).toHaveLength(2);
    expect(list[0].guess.year).toBe(2019);
  });

  it("적중 통계를 집계한다", () => {
    saveGoosebumpConfirmation({ guess, answer: "yes", answeredAt: "2026-01-01T00:00:00.000Z" });
    saveGoosebumpConfirmation({ guess, answer: "yes", answeredAt: "2026-01-01T00:00:00.000Z" });
    saveGoosebumpConfirmation({ guess, answer: "no", answeredAt: "2026-01-01T00:00:00.000Z" });
    saveGoosebumpConfirmation({ guess, answer: "unsure", answeredAt: "2026-01-01T00:00:00.000Z" });
    expect(goosebumpAccuracySummary()).toEqual({ total: 4, yes: 2, no: 1, unsure: 1 });
  });
});
