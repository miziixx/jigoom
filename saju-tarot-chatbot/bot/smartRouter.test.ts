import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { heuristicTarotFlags, fallbackRoute, routeMessage, type RouteInput } from "./smartRouter.js";

const baseInput = (over: Partial<RouteInput> = {}): RouteInput => ({
  text: "요즘 어때",
  history: [],
  keywordHint: "generalChat",
  hasSaju: false,
  hasBirth: false,
  hasTarot: false,
  ...over,
});

describe("heuristicTarotFlags", () => {
  it("뽑은 카드가 없으면 무조건 새로 뽑는다", () => {
    expect(heuristicTarotFlags("타로 봐줘", false)).toEqual({ newDraw: true, tarotFollowUp: false });
  });

  it("카드가 있고 다시 뽑으라는 말이 있으면 새로 뽑는다", () => {
    expect(heuristicTarotFlags("한 장 더 뽑아줘", true)).toEqual({ newDraw: true, tarotFollowUp: false });
    expect(heuristicTarotFlags("다시 뽑아줘", true)).toEqual({ newDraw: true, tarotFollowUp: false });
  });

  it("카드가 있고 새로 뽑으란 말이 없으면 후속 질문으로 본다", () => {
    expect(heuristicTarotFlags("그 카드 무슨 뜻이야?", true)).toEqual({ newDraw: false, tarotFollowUp: true });
  });
});

describe("fallbackRoute", () => {
  it("키워드 힌트를 그대로 의도로 쓴다", () => {
    expect(fallbackRoute(baseInput({ keywordHint: "sajuReading" })).intent).toBe("sajuReading");
  });

  it("파괴적(삭제/초기화) 힌트만 방어적으로 generalChat으로 좁힌다", () => {
    expect(fallbackRoute(baseInput({ keywordHint: "memoryDelete" })).intent).toBe("generalChat");
    expect(fallbackRoute(baseInput({ keywordHint: "resetContext" })).intent).toBe("generalChat");
  });

  it("저장/조회/보안 힌트는 라우터가 판단하므로 폴백에서도 그대로 통과한다", () => {
    expect(fallbackRoute(baseInput({ keywordHint: "memorySave" })).intent).toBe("memorySave");
    expect(fallbackRoute(baseInput({ keywordHint: "memoryLookup" })).intent).toBe("memoryLookup");
    expect(fallbackRoute(baseInput({ keywordHint: "privacyCheck" })).intent).toBe("privacyCheck");
  });

  it("타로 힌트면 뽑기 플래그를 규칙으로 채운다", () => {
    const r = fallbackRoute(baseInput({ keywordHint: "tarotReading", text: "타로 봐줘", hasTarot: false }));
    expect(r.intent).toBe("tarotReading");
    expect(r.newDraw).toBe(true);
    expect(r.usedLlm).toBe(false);
  });
});

describe("routeMessage (라우터 OFF)", () => {
  const prev = process.env.BOT_SMART_ROUTER;
  beforeEach(() => {
    process.env.BOT_SMART_ROUTER = "0";
  });
  afterEach(() => {
    if (prev === undefined) delete process.env.BOT_SMART_ROUTER;
    else process.env.BOT_SMART_ROUTER = prev;
  });

  it("라우터가 꺼져 있으면 LLM 없이 키워드 폴백을 쓴다", async () => {
    const r = await routeMessage(baseInput({ keywordHint: "tarotReading", text: "타로 봐줘" }));
    expect(r.usedLlm).toBe(false);
    expect(r.intent).toBe("tarotReading");
    expect(r.newDraw).toBe(true);
  });
});
