import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { getTodayFortune } from "./fortuneApi.js";
import type { BirthInfo, FortuneContent } from "../types/index.js";

// ── localStorage 목 (node 환경) ──────────────────────────────
class MemStorage {
  private m = new Map<string, string>();
  get length() {
    return this.m.size;
  }
  key(i: number) {
    return [...this.m.keys()][i] ?? null;
  }
  getItem(k: string) {
    return this.m.has(k) ? this.m.get(k)! : null;
  }
  setItem(k: string, v: string) {
    this.m.set(k, v);
  }
  removeItem(k: string) {
    this.m.delete(k);
  }
  clear() {
    this.m.clear();
  }
}

const SAMPLE: FortuneContent = {
  summary: "s",
  keywords: ["a", "b", "c"],
  good_areas: ["x", "y"],
  caution_points: ["p", "q"],
  do_actions: ["1", "2", "3"],
  avoid_actions: ["n1", "n2"],
  categories: { love: "l", work: "w", money: "m", relationship: "r", condition: "c" },
  share_text: "share",
};

const birth: BirthInfo = { calendarType: "solar", year: 1990, month: 12, day: 23, hour: 8, minute: 0, gender: "female" };

function okFetch() {
  return vi.fn(async () => ({ ok: true, json: async () => ({ content: SAMPLE, source: "llm" }) }) as unknown as Response);
}

beforeEach(() => {
  (globalThis as unknown as { localStorage: MemStorage }).localStorage = new MemStorage();
});

afterEach(() => {
  vi.restoreAllMocks();
});

describe("오늘의 운세 캐시", () => {
  const now = new Date("2026-07-03T03:00:00Z"); // KST 12:00

  it("첫 호출은 API를 부르고, 같은 날 재방문은 캐시를 반환한다 (LLM 비용 절감)", async () => {
    const fetchMock = okFetch();
    vi.stubGlobal("fetch", fetchMock);

    const first = await getTodayFortune(birth, { now });
    expect(first.source).toBe("llm");
    expect(fetchMock).toHaveBeenCalledTimes(1);

    const second = await getTodayFortune(birth, { now });
    expect(fetchMock).toHaveBeenCalledTimes(1); // 캐시 히트 — 추가 호출 없음
    expect(second.content).toEqual(SAMPLE);
  });

  it("force 옵션은 캐시를 무시하고 다시 생성한다", async () => {
    const fetchMock = okFetch();
    vi.stubGlobal("fetch", fetchMock);

    await getTodayFortune(birth, { now });
    await getTodayFortune(birth, { now, force: true });
    expect(fetchMock).toHaveBeenCalledTimes(2);
  });

  it("KST 날짜가 바뀌면(자정 경과) 새로 생성한다", async () => {
    const fetchMock = okFetch();
    vi.stubGlobal("fetch", fetchMock);

    await getTodayFortune(birth, { now }); // 2026-07-03 KST
    const nextDay = new Date("2026-07-04T03:00:00Z"); // 2026-07-04 KST
    await getTodayFortune(birth, { now: nextDay });
    expect(fetchMock).toHaveBeenCalledTimes(2);
  });

  it("같은 KST 날짜의 서로 다른 시각은 캐시를 공유한다", async () => {
    const fetchMock = okFetch();
    vi.stubGlobal("fetch", fetchMock);

    await getTodayFortune(birth, { now: new Date("2026-07-03T00:00:00Z") }); // KST 09:00
    await getTodayFortune(birth, { now: new Date("2026-07-03T13:00:00Z") }); // KST 22:00
    expect(fetchMock).toHaveBeenCalledTimes(1);
  });

  it("서버 실패 시 룰 기반 폴백으로 결과를 만든다", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn(async () => {
        throw new Error("network down");
      }),
    );
    const result = await getTodayFortune(birth, { now });
    expect(result.source).toBe("fallback");
    expect(result.content.summary.length).toBeGreaterThan(0);
    expect(result.evidence.ganzhi.day).toBe("무인");
  });
});
