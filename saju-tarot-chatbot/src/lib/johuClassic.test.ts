import { describe, expect, it } from "vitest";
import { computeSajuChart } from "./saju.js";
import type { BirthInfo } from "../types/index.js";

// 원국 경오 무자 임술 갑진 (일간 임, 월지 자)
const female1990: BirthInfo = { calendarType: "solar", year: 1990, month: 12, day: 23, hour: 8, minute: 0, gender: "female" };

describe("궁통보감 조후용신 정밀표", () => {
  const chart = computeSajuChart(female1990);
  const cc = chart.yongshin?.climaticClassic;

  it("임 일간 자월의 조후용신을 궁통보감 표대로 낸다 (무·병)", () => {
    expect(cc).toBeTruthy();
    expect(cc!.priorityStems).toEqual(["무", "병"]);
    expect(cc!.primaryElement).toBe("토");
    expect(cc!.source).toBe("궁통보감");
  });

  it("원국에 있는 우선 천간은 present, 없는 것은 missing으로 나눈다", () => {
    // 월간 무 + 술/진 지장 무 → 무 present, 오 지장 병 → 병 present
    expect(cc!.presentStems).toContain("무");
    expect(cc!.presentStems).toContain("병");
    expect(cc!.satisfied).toBe(true);
  });

  it("기존 간이 조후(climatic)는 그대로 두고 별도 필드로 공존한다", () => {
    // 임 자월은 간이 한난 판정상 '화'(찬 사주). 궁통보감 1순위는 '토'. 둘이 달라도 climatic은 불변.
    expect(chart.yongshin?.climatic?.element).toBe("화");
    expect(cc!.primaryElement).toBe("토");
  });
});
