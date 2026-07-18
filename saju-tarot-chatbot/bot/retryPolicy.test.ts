import { describe, expect, it } from "vitest";
import { isTransientApiError, retryBackoffMs, MAX_STREAM_ATTEMPTS } from "./retryPolicy.js";

describe("isTransientApiError", () => {
  it("과부하/rate limit/5xx 상태는 일시적으로 본다", () => {
    for (const status of [408, 429, 500, 502, 503, 529]) {
      expect(isTransientApiError({ status })).toBe(true);
    }
  });

  it("네트워크 계열 SDK 오류 이름은 일시적으로 본다", () => {
    expect(isTransientApiError({ name: "APIConnectionError" })).toBe(true);
    expect(isTransientApiError({ name: "APIConnectionTimeoutError" })).toBe(true);
  });

  it("우리가 건 타임아웃/중단은 재시도하지 않는다(시간을 이미 다 씀)", () => {
    expect(isTransientApiError({ name: "TimeoutError" })).toBe(false);
    expect(isTransientApiError({ name: "AbortError" })).toBe(false);
  });

  it("400·401·403 같은 요청 자체 오류는 재시도하지 않는다", () => {
    expect(isTransientApiError({ status: 400 })).toBe(false);
    expect(isTransientApiError({ status: 401 })).toBe(false);
    expect(isTransientApiError({ status: 403 })).toBe(false);
  });

  it("null/문자열/빈 값은 안전하게 false", () => {
    expect(isTransientApiError(null)).toBe(false);
    expect(isTransientApiError(undefined)).toBe(false);
    expect(isTransientApiError("boom")).toBe(false);
    expect(isTransientApiError({})).toBe(false);
  });
});

describe("retryBackoffMs", () => {
  it("시도마다 지수적으로 늘고 4초+지터로 상한선이 걸린다", () => {
    const fixed = () => 0; // 지터 0
    expect(retryBackoffMs(1, fixed)).toBe(400);
    expect(retryBackoffMs(2, fixed)).toBe(800);
    expect(retryBackoffMs(3, fixed)).toBe(1600);
    expect(retryBackoffMs(10, fixed)).toBe(4000); // 상한
  });

  it("지터가 더해진다", () => {
    expect(retryBackoffMs(1, () => 150)).toBe(550);
  });

  it("최대 시도 횟수는 2회 이상이다(재시도가 실제로 일어남)", () => {
    expect(MAX_STREAM_ATTEMPTS).toBeGreaterThanOrEqual(2);
  });
});
