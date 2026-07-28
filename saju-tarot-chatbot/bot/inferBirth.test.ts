import { describe, expect, it } from "vitest";
import { inferBirthFromPillars } from "./inferBirth.js";
import { computeSajuChart } from "../src/lib/saju.js";

describe("inferBirthFromPillars", () => {
  it("완전한 팔자 → 실제 생일을 되짚고 대운 계산이 가능해진다", () => {
    const r = inferBirthFromPillars({ year: "경오", month: "무자", day: "임술", hour: "갑진", gender: "female" });
    expect(r.ok).toBe(true);
    expect(r.birthInfo).toMatchObject({ year: 1990, month: 12, day: 23, gender: "female" });
    // 되짚은 생일이 원래 팔자를 그대로 재현
    const chart = computeSajuChart(r.birthInfo!);
    expect(chart.year.ganZhi).toBe("경오");
    expect(chart.day.ganZhi).toBe("임술");
    expect(chart.hour?.ganZhi).toBe("갑진");
  });

  it("60년 반복이면 가장 최근(가장 어린) 연도를 고르고 다른 후보를 알려준다", () => {
    const r = inferBirthFromPillars({ year: "계해", month: "을축", day: "계묘", hour: "임자", gender: "male" });
    expect(r.ok).toBe(true);
    expect(r.birthInfo?.year).toBe(1984);
    expect(r.otherYears).toContain(1924);
  });

  it("성별 미입력이면 남성 기준으로 가정하고 표시한다", () => {
    const r = inferBirthFromPillars({ year: "계해", month: "을축", day: "계묘", hour: null });
    expect(r.ok).toBe(true);
    expect(r.genderAssumed).toBe(true);
    expect(r.birthInfo?.gender).toBe("male");
  });

  it("시주를 모르면 시주 없이(hour null) 날짜만 되짚는다", () => {
    const r = inferBirthFromPillars({ year: "경오", month: "무자", day: "임술", hour: null });
    expect(r.ok).toBe(true);
    expect(r.birthInfo?.hour).toBeNull();
    expect(r.birthInfo?.year).toBe(1990);
  });

  it("되짚을 수 없는 팔자(불가능한 조합)면 ok:false 로 폴백을 알린다", () => {
    const r = inferBirthFromPillars({ year: "갑자", month: "갑자", day: "갑자", hour: null });
    expect(r.ok).toBe(false);
  });
});
