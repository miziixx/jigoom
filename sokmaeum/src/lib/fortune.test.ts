import { describe, expect, it } from "vitest";
import { tenGodOf } from "./saju.js";
import {
  branchRelationsBetween,
  computeFortuneEvidence,
  ganzhiForKstDate,
  kstDateOf,
  tenGodGroupOf,
} from "./fortune.js";
import type { BirthInfo } from "../types/index.js";

// ──────────────────────────────────────────────────────────────
// 독립 오라클: 율리우스 적일수(JDN) → 일진 간지
// lunar-javascript와 무관한 공개 천문 상수(stem=(JDN+9)%10, branch=(JDN+1)%12)로
// 계산하므로 라이브러리 값과의 대조는 순환 검증이 아니다.
// ──────────────────────────────────────────────────────────────
const GAN = ["갑", "을", "병", "정", "무", "기", "경", "신", "임", "계"];
const ZHI = ["자", "축", "인", "묘", "진", "사", "오", "미", "신", "유", "술", "해"];

function jdn(y: number, m: number, d: number): number {
  const a = Math.floor((14 - m) / 12);
  const yy = y + 4800 - a;
  const mm = m + 12 * a - 3;
  return d + Math.floor((153 * mm + 2) / 5) + 365 * yy + Math.floor(yy / 4) - Math.floor(yy / 100) + Math.floor(yy / 400) - 32045;
}

function oracleDayGanZhi(y: number, m: number, d: number): string {
  const j = jdn(y, m, d);
  return GAN[(((j + 9) % 10) + 10) % 10] + ZHI[(((j + 1) % 12) + 12) % 12];
}

function dayGanZhiFor(y: number, m: number, d: number): string {
  return ganzhiForKstDate({ year: y, month: m, day: d, iso: "", weekday: "" }).day;
}

describe("일진 간지 계산 (Asia/Seoul)", () => {
  it("알려진 날짜의 일진을 정확히 계산한다", () => {
    // 독립 오라클로 검증된 값 (양력)
    expect(dayGanZhiFor(2000, 1, 1)).toBe("무오");
    expect(dayGanZhiFor(2024, 1, 1)).toBe("갑자");
    expect(dayGanZhiFor(2024, 2, 4)).toBe("무술");
    expect(dayGanZhiFor(2025, 1, 1)).toBe("경오");
    expect(dayGanZhiFor(2026, 7, 3)).toBe("무인");
    expect(dayGanZhiFor(2020, 1, 1)).toBe("계묘");
  });

  it("400일 연속 구간 전체가 독립 JDN 오라클과 일치한다 (연속성·정확성)", () => {
    const start = Date.UTC(2024, 0, 1);
    for (let i = 0; i < 400; i++) {
      const dt = new Date(start + i * 86400000);
      const y = dt.getUTCFullYear();
      const m = dt.getUTCMonth() + 1;
      const d = dt.getUTCDate();
      expect(dayGanZhiFor(y, m, d)).toBe(oracleDayGanZhi(y, m, d));
    }
  });

  it("일진은 매 민간일마다 정확히 1씩 전진한다 (60갑자 순환)", () => {
    const ORDER: string[] = [];
    for (let i = 0; i < 60; i++) ORDER.push(GAN[i % 10] + ZHI[i % 12]);
    const start = Date.UTC(2026, 5, 1);
    for (let i = 0; i < 65; i++) {
      const a = new Date(start + i * 86400000);
      const b = new Date(start + (i + 1) * 86400000);
      const ia = ORDER.indexOf(dayGanZhiFor(a.getUTCFullYear(), a.getUTCMonth() + 1, a.getUTCDate()));
      const ib = ORDER.indexOf(dayGanZhiFor(b.getUTCFullYear(), b.getUTCMonth() + 1, b.getUTCDate()));
      expect((ia + 1) % 60).toBe(ib);
    }
  });
});

describe("KST 날짜 경계", () => {
  it("UTC 저녁이 KST 다음날로 넘어간다", () => {
    // 2026-07-03T15:30:00Z = 2026-07-04 00:30 KST
    expect(kstDateOf(new Date("2026-07-03T15:30:00Z")).iso).toBe("2026-07-04");
    // 2026-07-03T14:00:00Z = 2026-07-03 23:00 KST
    expect(kstDateOf(new Date("2026-07-03T14:00:00Z")).iso).toBe("2026-07-03");
    // 자정 직후 KST
    expect(kstDateOf(new Date("2026-07-03T15:00:00Z")).iso).toBe("2026-07-04");
  });
});

describe("십성 판정 테이블 (일간 갑 기준 10천간)", () => {
  const table: Array<[string, string]> = [
    ["갑", "비견"],
    ["을", "겁재"],
    ["병", "식신"],
    ["정", "상관"],
    ["무", "편재"],
    ["기", "정재"],
    ["경", "편관"],
    ["신", "정관"],
    ["임", "편인"],
    ["계", "정인"],
  ];
  it.each(table)("갑 vs %s → %s", (target, expected) => {
    expect(tenGodOf("갑", target)).toBe(expected);
  });

  it("십성 5분류 매핑", () => {
    expect(tenGodGroupOf("비견")).toBe("비겁");
    expect(tenGodGroupOf("겁재")).toBe("비겁");
    expect(tenGodGroupOf("식신")).toBe("식상");
    expect(tenGodGroupOf("편재")).toBe("재성");
    expect(tenGodGroupOf("정관")).toBe("관성");
    expect(tenGodGroupOf("정인")).toBe("인성");
  });
});

describe("지지 관계 판정 테이블", () => {
  const eq = (a: string[], b: string[]) => expect([...a].sort()).toEqual([...b].sort());

  it("육합(묘술)", () => eq(branchRelationsBetween("묘", "술"), ["육합"]));
  it("자축은 육합이자 부분방합(해자축, 왕지 자)", () => eq(branchRelationsBetween("자", "축"), ["육합", "방합"]));
  it("왕지 없는 부분삼합은 성립하지 않는다(신-진)", () => eq(branchRelationsBetween("신", "진"), []));
  it("충", () => eq(branchRelationsBetween("자", "오"), ["충"]));
  it("인신은 충이면서 형(삼형 인사신)", () => eq(branchRelationsBetween("인", "신"), ["충", "형"]));
  it("삼합(반합)", () => eq(branchRelationsBetween("인", "오"), ["삼합"]));
  it("방합", () => eq(branchRelationsBetween("인", "묘"), ["방합"]));
  it("자형(같은 글자)", () => eq(branchRelationsBetween("진", "진"), ["형"]));
  it("파", () => eq(branchRelationsBetween("자", "유"), ["파"]));
  it("해+원진 중복(자미)", () => eq(branchRelationsBetween("자", "미"), ["해", "원진"]));
  it("원진", () => eq(branchRelationsBetween("인", "유"), ["원진"]));
  it("육합+파 중복(인해)", () => eq(branchRelationsBetween("인", "해"), ["육합", "파"]));
  it("관계 없음", () => eq(branchRelationsBetween("자", "인"), []));
});

describe("오늘의 운세 근거 데이터 통합", () => {
  const birth: BirthInfo = {
    calendarType: "solar",
    year: 1990,
    month: 12,
    day: 23,
    hour: 8,
    minute: 0,
    gender: "female",
  };
  // 고정 시각: 2026-07-03 정오 KST 근처 (UTC 03:00)
  const fixedNow = new Date("2026-07-03T03:00:00Z");

  it("KST 날짜와 일진을 근거에 담는다", () => {
    const ev = computeFortuneEvidence(birth, fixedNow);
    expect(ev.date).toBe("2026-07-03");
    expect(ev.ganzhi.day).toBe("무인");
    expect(ev.ganzhi.dayGan).toBe("무");
    expect(ev.ganzhi.dayZhi).toBe("인");
  });

  it("십성은 내 일간 vs 오늘 천간의 tenGodOf와 일치한다", () => {
    const ev = computeFortuneEvidence(birth, fixedNow);
    expect(ev.tenGod.name).toBe(tenGodOf(ev.natal.dayMaster, ev.ganzhi.dayGan));
    expect(["비겁", "식상", "재성", "관성", "인성"]).toContain(ev.tenGod.group);
  });

  it("모든 카테고리 점수는 0~100 정수이다", () => {
    const ev = computeFortuneEvidence(birth, fixedNow);
    for (const v of Object.values(ev.categories)) {
      expect(Number.isInteger(v)).toBe(true);
      expect(v).toBeGreaterThanOrEqual(0);
      expect(v).toBeLessThanOrEqual(100);
    }
  });

  it("오행 조력도는 -100~+100 범위이다", () => {
    const ev = computeFortuneEvidence(birth, fixedNow);
    expect(ev.elementSupport.score).toBeGreaterThanOrEqual(-100);
    expect(ev.elementSupport.score).toBeLessThanOrEqual(100);
  });

  it("12운성 에너지 레벨은 0~100 이다", () => {
    const ev = computeFortuneEvidence(birth, fixedNow);
    expect(ev.twelveStage.energyLevel).toBeGreaterThanOrEqual(0);
    expect(ev.twelveStage.energyLevel).toBeLessThanOrEqual(100);
  });

  it("행운 시간대는 오늘 지지와 육합인 시지이다", () => {
    const ev = computeFortuneEvidence(birth, fixedNow);
    // 오늘 지지 '인'의 육합 파트너는 '해'
    expect(ev.luckyItems.timeSlot.zhi).toBe("해");
    expect(ev.luckyItems.timeSlot.range).toBe("21:00–23:00");
  });

  it("동일 입력·동일 날짜는 완전히 결정론적이다", () => {
    const a = computeFortuneEvidence(birth, fixedNow);
    const b = computeFortuneEvidence(birth, fixedNow);
    expect(JSON.stringify(a)).toBe(JSON.stringify(b));
  });

  it("출생 시간을 몰라도(시주 제외) 계산이 성립한다", () => {
    const noHour: BirthInfo = { ...birth, hour: null };
    const ev = computeFortuneEvidence(noHour, fixedNow);
    expect(ev.natal.hasHour).toBe(false);
    // 시지가 없으므로 지지 관계는 3자리(연/월/일)만
    expect(ev.branchRelations).toHaveLength(3);
  });
});
