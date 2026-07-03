import { describe, expect, it } from "vitest";
import { buildMysticEvidence } from "./evidenceMapper";
import { buildFallbackReading } from "./buildFallbackReading";
import type { BirthInfo, MysticReadingResult, ReadingInterest } from "../../types";

const BIRTH: BirthInfo = {
  calendarType: "solar",
  year: 1988,
  month: 7,
  day: 15,
  hour: 13,
  minute: 0,
  birthPlace: "none",
  gender: "male",
};

const BIRTH_NO_HOUR: BirthInfo = { ...BIRTH, hour: null };

const NOW = new Date("2026-07-03T04:00:00Z");

// 요구사항의 금지 표현
const FORBIDDEN = [
  "100% 맞습니다",
  "반드시 일어납니다",
  "무조건 헤어집니다",
  "죽습니다",
  "병에 걸립니다",
  "바람납니다",
  "저주받았습니다",
  "조상 문제입니다",
  "굿을 해야",
  "신이 말합니다",
  "귀신이 붙",
  "운명은 정해져",
];

function allStrings(obj: unknown): string[] {
  const out: string[] = [];
  const walk = (v: unknown) => {
    if (typeof v === "string") out.push(v);
    else if (Array.isArray(v)) v.forEach(walk);
    else if (v && typeof v === "object") Object.values(v).forEach(walk);
  };
  walk(obj);
  return out;
}

describe("buildMysticEvidence", () => {
  it("근거(notes)를 최소 1개 이상 만든다", () => {
    const ev = buildMysticEvidence(BIRTH, "money", NOW);
    expect(ev.notes.length).toBeGreaterThan(0);
    expect(ev.dayMaster).toBeTruthy();
  });

  it("관심사가 근거에 반영된다", () => {
    const ev = buildMysticEvidence(BIRTH, "money", NOW);
    expect(ev.interest).toBe("money");
    expect(ev.notes.some((n) => n.includes("돈/재물"))).toBe(true);
  });

  it("출생시간 미입력 시 안내 근거를 남긴다", () => {
    const ev = buildMysticEvidence(BIRTH_NO_HOUR, "all", NOW);
    expect(ev.hasHour).toBe(false);
    expect(ev.notes.some((n) => n.includes("출생시간 미입력"))).toBe(true);
  });
});

describe("buildFallbackReading", () => {
  const interests: ReadingInterest[] = ["work", "money", "love", "all"];

  it("모든 필드를 빈 문자열 없이 채운다", () => {
    for (const interest of interests) {
      const ev = buildMysticEvidence(BIRTH, interest, NOW);
      const r = buildFallbackReading(ev);
      const strings = allStrings(r);
      expect(strings.length).toBeGreaterThan(10);
      for (const s of strings) expect(s.trim().length).toBeGreaterThan(0);
    }
  });

  it("주요 섹션의 evidence가 최소 1개 이상이다", () => {
    const ev = buildMysticEvidence(BIRTH, "work", NOW);
    const r: MysticReadingResult = buildFallbackReading(ev);
    expect(r.openingOracle.evidence.length).toBeGreaterThan(0);
    expect(r.currentState.evidence.length).toBeGreaterThan(0);
    expect(r.outerInnerSelf.evidence.length).toBeGreaterThan(0);
    expect(r.hiddenConcerns.length).toBeGreaterThanOrEqual(3);
    expect(r.yearlyTurningPoints.length).toBeGreaterThan(0);
  });

  it("금지 표현을 포함하지 않는다", () => {
    for (const interest of interests) {
      const ev = buildMysticEvidence(BIRTH, interest, NOW);
      const text = allStrings(buildFallbackReading(ev)).join(" ");
      for (const bad of FORBIDDEN) expect(text.includes(bad)).toBe(false);
    }
  });

  it("관심사에 따라 말하지 않은 고민의 우선순위가 달라진다", () => {
    const money = buildFallbackReading(buildMysticEvidence(BIRTH, "money", NOW));
    const love = buildFallbackReading(buildMysticEvidence(BIRTH, "love", NOW));
    expect(money.hiddenConcerns[0].category).not.toBe(love.hiddenConcerns[0].category);
  });

  it("상대방 미입력 시 partnerReading이 없다", () => {
    const r = buildFallbackReading(buildMysticEvidence(BIRTH, "love", NOW));
    expect(r.partnerReading).toBeUndefined();
  });
});

describe("관계 리딩 (상대방 입력)", () => {
  const PARTNER: BirthInfo = { ...BIRTH, year: 1990, month: 3, day: 22, hour: 9 };

  it("상대방 입력 시 partner 근거와 partnerReading을 채운다", () => {
    const ev = buildMysticEvidence(BIRTH, "love", NOW, { partner: PARTNER });
    expect(ev.partner).toBeDefined();
    expect(ev.partner!.dayMaster).toBeTruthy();
    expect(["생함", "생받음", "극함", "극받음", "비화"]).toContain(ev.partner!.elementRelation);

    const r = buildFallbackReading(ev);
    expect(r.partnerReading).toBeDefined();
    for (const v of Object.values(r.partnerReading!)) {
      if (typeof v === "string") expect(v.trim().length).toBeGreaterThan(0);
    }
    expect(r.partnerReading!.evidence.length).toBeGreaterThan(0);
  });

  it("관계 리딩에 단정 금지 표현이 없다", () => {
    const ev = buildMysticEvidence(BIRTH, "marriage", NOW, { partner: PARTNER });
    const text = allStrings(buildFallbackReading(ev)).join(" ");
    for (const bad of FORBIDDEN) expect(text.includes(bad)).toBe(false);
  });
});
