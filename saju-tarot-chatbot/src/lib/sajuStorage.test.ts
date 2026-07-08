import { describe, expect, it } from "vitest";
import { computeSajuChart } from "./saju.js";
import type { BirthInfo } from "../types/index.js";

// 진술충 개고: 1981-07-07 08시 (원국에 진·술 동시 존재)
const jinsul: BirthInfo = { calendarType: "solar", year: 1981, month: 7, day: 7, hour: 8, minute: 0, gender: "male" };
// 축미충 개고: 1980-01-10 14시
const chukmi: BirthInfo = { calendarType: "solar", year: 1980, month: 1, day: 10, hour: 14, minute: 0, gender: "male" };

describe("개고(開庫) 계산", () => {
  it("storageOpenings는 항상 배열이다", () => {
    const c = computeSajuChart(jinsul);
    expect(Array.isArray(c.storageOpenings)).toBe(true);
  });

  it("진술충이면 진(수고)·술(화고)이 열린다", () => {
    const c = computeSajuChart(jinsul);
    const o = c.storageOpenings!;
    expect(o.length).toBeGreaterThanOrEqual(2);
    const jin = o.find((x) => x.zhi === "진")!;
    const sul = o.find((x) => x.zhi === "술")!;
    expect(jin.trigger).toBe("진술충");
    expect(jin.element).toBe("수");
    expect(jin.storedStem).toBe("계");
    expect(sul.element).toBe("화");
    expect(sul.storedStem).toBe("정");
    // 십성은 일간 기준으로 계산돼 있어야 한다
    for (const x of o) expect(x.tenGod.length).toBeGreaterThan(0);
  });

  it("축미충이면 축(금고)·미(목고)가 열린다", () => {
    const c = computeSajuChart(chukmi);
    const o = c.storageOpenings!;
    const chuk = o.find((x) => x.zhi === "축")!;
    const mi = o.find((x) => x.zhi === "미")!;
    expect(chuk.trigger).toBe("축미충");
    expect(chuk.element).toBe("금");
    expect(mi.element).toBe("목");
  });

  it("표면 note에 십성 용어를 던지지 않고 '창고' 은유로 쓴다", () => {
    const c = computeSajuChart(jinsul);
    for (const o of c.storageOpenings!) {
      expect(o.note).toContain("창고");
      // 십성 원어(정관·겁재 등)를 note 표면에 직접 노출하지 않는다
      for (const t of ["정관", "편관", "겁재", "비견", "상관", "식신", "편재", "정재", "편인", "정인"]) {
        expect(o.note).not.toContain(t);
      }
    }
  });

  it("결정론: 같은 입력이면 같은 결과", () => {
    expect(computeSajuChart(jinsul).storageOpenings).toEqual(computeSajuChart(jinsul).storageOpenings);
  });
});
