import { describe, expect, it } from "vitest";
import { computeSajuChart } from "./saju.js";
import type { BirthInfo } from "../types/index.js";

// 원국 경오 무자 임술 갑진 (일간 임·water, 일지 술)
const female1990: BirthInfo = { calendarType: "solar", year: 1990, month: 12, day: 23, hour: 8, minute: 0, gender: "female" };

describe("삼명통회 계열 추가 신살", () => {
  const chart = computeSajuChart(female1990);
  const names = (chart.sinsal ?? []).map((s) => s.name);
  const at = (name: string, position: string) =>
    (chart.sinsal ?? []).some((s) => s.name === name && s.position === position);

  it("천간 갑·무·경이 모두 있으면 천상삼기가 성립한다", () => {
    // 연간 경 · 월간 무 · 시간 갑 → 천상삼기(갑무경)
    expect(names).toContain("천상삼기");
  });

  it("재고귀인: 재성(화)의 묘고 술이 일지에 있으면 성립한다", () => {
    // 일간 임(水) → 재성 火, 火의 고지 술. 일지 술 → 재고귀인
    expect(at("재고귀인", "일지 술")).toBe(true);
  });

  it("성립하지 않는 신살은 넣지 않는다 (태극귀인·관귀학관 미해당)", () => {
    // 태극귀인(임계→사·신) 지지 없음, 관귀학관(관성 토 장생 인) 지지 없음
    expect(at("태극귀인", "연지 오")).toBe(false);
    expect(names).not.toContain("관귀학관");
  });
});
