import { describe, it, expect } from "vitest";
import { buildTodayGanzhiFact } from "./evidence.js";
import { carriesRealQuestion } from "./questionHeuristics.js";

describe("buildTodayGanzhiFact — 등록 없이도 오늘 간지 계산", () => {
  it("주어진 날짜의 일진 간지를 계산해 사실 블록으로 만든다", () => {
    // 2026-07-20 (KST) — 실제 만세력 계산값이 담겨야 한다.
    const fact = buildTodayGanzhiFact(new Date("2026-07-20T03:00:00Z"));
    expect(fact).toContain("2026-07-20");
    expect(fact).toContain("일진");
    // 간지 두 글자(천간+지지)가 실제로 채워져 있어야 한다.
    expect(fact).toMatch(/일진\(오늘 간지\): [가-힣]{2}/);
    // 등록 안내가 포함돼, 개인 상호작용은 등록해야 함을 LLM이 알 수 있다.
    expect(fact).toContain("생년월일시 등록");
  });
});

describe("carriesRealQuestion — 부분 팔자 안내를 가로채면 안 되는 이론 질문 감지", () => {
  it("물음표나 십성/이론 용어가 있으면 true", () => {
    expect(carriesRealQuestion("정축일주 을미일, 편재와 상관 성격을 띠는 날이야?")).toBe(true);
    expect(carriesRealQuestion("갑자 정축 병인 이거 무슨 격국이야?")).toBe(true);
    expect(carriesRealQuestion("신강 신약 어떻게 봐")).toBe(true);
  });

  it("순수 간지 조각만 있으면 false (안내를 띄워도 되는 경우)", () => {
    expect(carriesRealQuestion("갑자년 정축월")).toBe(false);
    expect(carriesRealQuestion("정축일 을미")).toBe(false);
  });
});
