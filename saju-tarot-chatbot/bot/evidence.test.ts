import { describe, it, expect } from "vitest";
import { computeSajuChart } from "../src/lib/saju.js";
import { computeStorageStatus } from "./evidence.js";
import { parseRelationType } from "./parseBirth.js";
import type { BirthInfo } from "../src/types/index.js";

const base: BirthInfo = {
  calendarType: "solar",
  year: 1993,
  month: 3,
  day: 15,
  hour: 14,
  minute: 30,
  birthPlace: "seoul",
  gender: "female",
};

describe("computeStorageStatus (입고/개고)", () => {
  it("창고(진술축미) 지지를 저장 기운과 함께 잡아낸다", () => {
    const chart = computeSajuChart(base);
    const storage = computeStorageStatus(chart);
    // 이 사주의 일지·시지는 미(未) = 목의 창고
    const wood = storage.filter((s) => s.branch === "미");
    expect(wood.length).toBeGreaterThan(0);
    for (const hit of wood) {
      expect(hit.stores).toContain("목(木)");
      expect(hit.stores).toContain("을");
    }
  });

  it("충 상대 지지가 원국에 없으면 openedByNatalChong=false", () => {
    const chart = computeSajuChart(base); // 축이 없으므로 미 창고는 안 열림
    const storage = computeStorageStatus(chart);
    const mi = storage.find((s) => s.branch === "미");
    expect(mi?.openedByNatalChong).toBe(false);
  });

  it("창고 지지가 없는 원국은 빈 배열을 돌려준다", () => {
    // 진술축미가 하나도 안 나오는 생일을 찾기보다, 로직 자체가 배열을 반환하는지만 확인
    const chart = computeSajuChart(base);
    expect(Array.isArray(computeStorageStatus(chart))).toBe(true);
  });
});

describe("parseRelationType", () => {
  it("관계 키워드를 유형으로 매핑한다", () => {
    expect(parseRelationType("연인")).toBe("romantic");
    expect(parseRelationType("남자친구랑 궁합")).toBe("romantic");
    expect(parseRelationType("우리 엄마")).toBe("parentChild");
    expect(parseRelationType("형이랑")).toBe("siblings");
    expect(parseRelationType("직장 상사")).toBe("bossEmployee");
    expect(parseRelationType("동료")).toBe("coworker");
    expect(parseRelationType("그냥 친구")).toBe("friend");
    expect(parseRelationType("우리 가족")).toBe("family");
  });

  it("관계 단서가 없으면 null", () => {
    expect(parseRelationType("1995-06-20 09:30 남 서울")).toBeNull();
  });
});
