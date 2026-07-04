import { afterEach, describe, expect, it, vi } from "vitest";
import { serverErrorText, streamReading } from "./readingApi.js";

describe("serverErrorText — 서버 오류를 읽을 수 있는 문자열로", () => {
  it("문자열은 그대로 쓴다", () => {
    expect(serverErrorText("크레딧 부족", "기본")).toBe("크레딧 부족");
  });
  it("객체는 [object Object]로 만들지 않고 message/error를 꺼낸다", () => {
    expect(serverErrorText({ message: "인증 실패" }, "기본")).toBe("인증 실패");
    expect(serverErrorText({ error: "429 초과" }, "기본")).toBe("429 초과");
  });
  it("풀 수 없는 객체는 JSON으로, 빈 값은 fallback", () => {
    expect(serverErrorText({ code: 500 }, "기본")).toContain("500");
    expect(serverErrorText({}, "기본")).toBe("기본");
    expect(serverErrorText(undefined, "기본")).toBe("기본");
  });
});

// NDJSON 라인들을 하나의 스트리밍 응답(Response 유사 객체)으로 만든다
function ndjsonResponse(lines: string[]): Response {
  const encoder = new TextEncoder();
  let i = 0;
  const body = {
    getReader() {
      return {
        read() {
          if (i < lines.length) {
            const chunk = encoder.encode(lines[i] + "\n");
            i += 1;
            return Promise.resolve({ done: false, value: chunk });
          }
          return Promise.resolve({ done: true, value: undefined });
        },
      };
    },
  };
  return {
    ok: true,
    status: 200,
    headers: { get: () => "application/x-ndjson; charset=utf-8" },
    body,
  } as unknown as Response;
}

afterEach(() => {
  vi.restoreAllMocks();
});

describe("streamReading 이어쓰기(continue)", () => {
  it("saju 새 리딩은 앞/뒤 섹션을 병렬 호출해 순서대로 합친다", async () => {
    const calls: Array<Record<string, unknown>> = [];
    const fetchMock = vi.fn((_, init: RequestInit) => {
      const parsed = JSON.parse(init.body as string) as Record<string, unknown>;
      calls.push(parsed);
      if (parsed.sectionGroup === "front") {
        return Promise.resolve(
          ndjsonResponse([
            JSON.stringify({ meta: { userMessage: "front-user" } }),
            JSON.stringify({ text: "# 첫 점괘\n앞" }),
            JSON.stringify({ done: true, stopReason: "end_turn" }),
          ]),
        );
      }
      return Promise.resolve(
        ndjsonResponse([
          JSON.stringify({ meta: { userMessage: "back-user" } }),
          JSON.stringify({ text: "# 건강과 컨디션\n뒤" }),
          JSON.stringify({ done: true, stopReason: "end_turn" }),
        ]),
      );
    });
    vi.stubGlobal("fetch", fetchMock);

    const result = await streamReading({ type: "saju", question: "전체" });

    expect(fetchMock).toHaveBeenCalledTimes(2);
    expect(calls.map((c) => c.sectionGroup).sort()).toEqual(["back", "front"]);
    expect(result.reply).toBe("# 첫 점괘\n앞\n\n# 건강과 컨디션\n뒤");
    expect(result.meta?.userMessage).toBe("front-user");
  });

  it("followup은 병렬 호출하지 않는다", async () => {
    const calls: Array<Record<string, unknown>> = [];
    const fetchMock = vi.fn((_input: RequestInfo | URL, init?: RequestInit) => {
      if (!init?.body) throw new Error("request body required");
      calls.push(JSON.parse(init.body as string));
      return Promise.resolve(
        ndjsonResponse([
          JSON.stringify({ text: "후속 답변" }),
          JSON.stringify({ done: true, stopReason: "end_turn" }),
        ]),
      );
    });
    vi.stubGlobal("fetch", fetchMock);

    const result = await streamReading({
      type: "followup",
      history: [{ role: "user", content: "질문" }],
      followUpMode: "concise",
    });

    expect(fetchMock).toHaveBeenCalledTimes(1);
    expect(calls[0].followUpMode).toBe("concise");
    expect(result.reply).toBe("후속 답변");
  });

  it("가벼운 리딩은 즉시 요약 중심이라 병렬 호출하지 않는다", async () => {
    const fetchMock = vi.fn(() =>
      Promise.resolve(
        ndjsonResponse([
          JSON.stringify({ meta: { userMessage: "light-user" } }),
          JSON.stringify({ text: "가벼운 리딩" }),
          JSON.stringify({ done: true, stopReason: "end_turn" }),
        ]),
      ),
    );
    vi.stubGlobal("fetch", fetchMock);

    const result = await streamReading({ type: "saju", question: "전체", context: { depth: "light" } });

    expect(fetchMock).toHaveBeenCalledTimes(1);
    expect(result.reply).toBe("가벼운 리딩");
  });

  it("stopReason이 max_tokens면 continueFrom으로 이어서 완결한다", async () => {
    const calls: Array<Record<string, unknown>> = [];
    const fetchMock = vi.fn((_, init: RequestInit) => {
      const parsed = JSON.parse(init.body as string) as Record<string, unknown>;
      calls.push(parsed);
      if (calls.length === 1) {
        // 첫 호출: 토큰 상한으로 잘림
        return Promise.resolve(
          ndjsonResponse([
            JSON.stringify({ meta: { userMessage: "u" } }),
            JSON.stringify({ text: "앞부분" }),
            JSON.stringify({ done: true, stopReason: "max_tokens" }),
          ]),
        );
      }
      // 이어쓰기 호출: 정상 완결
      return Promise.resolve(
        ndjsonResponse([
          JSON.stringify({ text: "뒷부분" }),
          JSON.stringify({ done: true, stopReason: "end_turn" }),
        ]),
      );
    });
    vi.stubGlobal("fetch", fetchMock);

    let lastAccumulated = "";
    const result = await streamReading(
      { type: "flow", question: "" },
      { onText: (acc) => (lastAccumulated = acc) },
    );

    expect(calls).toHaveLength(2);
    expect(calls[0].continueFrom).toBeUndefined();
    expect(calls[1].continueFrom).toBe("앞부분");
    expect(result.reply).toBe("앞부분뒷부분");
    expect(lastAccumulated).toBe("앞부분뒷부분");
    expect(result.meta?.userMessage).toBe("u");
  });

  it("done 없이 텍스트만 오다 끊겨도(네트워크 절단) 이어서 완결한다", async () => {
    const calls: Array<Record<string, unknown>> = [];
    const fetchMock = vi.fn((_, init: RequestInit) => {
      calls.push(JSON.parse(init.body as string));
      if (calls.length === 1) {
        // done 라인 없이 종료 → 미완결로 간주해야 한다
        return Promise.resolve(
          ndjsonResponse([
            JSON.stringify({ meta: { userMessage: "u" } }),
            JSON.stringify({ text: "중간까지" }),
          ]),
        );
      }
      return Promise.resolve(
        ndjsonResponse([JSON.stringify({ text: "끝까지" }), JSON.stringify({ done: true, stopReason: "end_turn" })]),
      );
    });
    vi.stubGlobal("fetch", fetchMock);

    const result = await streamReading({ type: "flow", question: "" });

    expect(calls).toHaveLength(2);
    expect(calls[1].continueFrom).toBe("중간까지");
    expect(result.reply).toBe("중간까지끝까지");
  });

  it("한 번에 완결(end_turn)되면 이어쓰기하지 않는다", async () => {
    const fetchMock = vi.fn(() =>
      Promise.resolve(
        ndjsonResponse([
          JSON.stringify({ meta: { userMessage: "u" } }),
          JSON.stringify({ text: "완성된 리딩" }),
          JSON.stringify({ done: true, stopReason: "end_turn" }),
        ]),
      ),
    );
    vi.stubGlobal("fetch", fetchMock);

    const result = await streamReading({ type: "flow", question: "" });

    expect(fetchMock).toHaveBeenCalledTimes(1);
    expect(result.reply).toBe("완성된 리딩");
  });
});
