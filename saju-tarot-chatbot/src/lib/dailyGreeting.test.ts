import { describe, expect, it } from "vitest";
import { buildDailyGreeting } from "./dailyGreeting.js";

describe("buildDailyGreeting (홈 개편 — 출생정보 없이 오늘 계산, 재기획안 §5)", () => {
  it("2026-07-09(KST)는 갑신일 · 소서 무렵으로 계산된다(ganzhiForKstDate와 동일 엔진 재사용 확인)", () => {
    // 정오 UTC로 넘겨 KST 날짜 경계와 무관하게 고정
    const g = buildDailyGreeting(new Date("2026-07-09T03:00:00Z"));
    expect(g.dateLabel).toBe("7월 9일 목요일");
    expect(g.dayGanZhi).toBe("갑신");
    expect(g.solarTerm).toBe("소서");
    expect(g.headline).toBe("7월 9일 목요일 · 갑신일 · 소서 무렵");
  });

  it("결정론: 같은 날짜면 항상 같은 결과", () => {
    const a = buildDailyGreeting(new Date("2026-01-01T03:00:00Z"));
    const b = buildDailyGreeting(new Date("2026-01-01T03:00:00Z"));
    expect(a).toEqual(b);
  });

  it("날짜가 바뀌면 일진도 바뀐다(계산 기반임을 확인)", () => {
    const day1 = buildDailyGreeting(new Date("2026-07-09T03:00:00Z"));
    const day2 = buildDailyGreeting(new Date("2026-07-10T03:00:00Z"));
    expect(day1.dayGanZhi).not.toBe(day2.dayGanZhi);
  });
});
