import { describe, expect, it } from "vitest";
import { computeZiweiChart } from "./ziwei.js";
import { deriveZiweiDomainVerdicts } from "./ziweiInterpretation.js";
import type { BirthInfo } from "../types/index.js";

const birthA: BirthInfo = { calendarType: "solar", year: 1990, month: 12, day: 23, hour: 8, minute: 0, gender: "female" };
const birthB: BirthInfo = { calendarType: "solar", year: 1988, month: 5, day: 2, hour: 14, minute: 30, gender: "male" };

// 표면 note에 나오면 안 되는 자미두수 용어
const JARGON = ["자미", "천부", "칠살", "파군", "거문", "관록", "재백", "부처", "질액", "복덕", "사화", "명궁", "지지"];

describe("deriveZiweiDomainVerdicts (자미두수 분야 판정)", () => {
  it("6개 분야(직업·재물·애정·건강·멘탈·가족) 판정을 낸다", () => {
    const v = deriveZiweiDomainVerdicts(computeZiweiChart(birthA)!);
    expect(v.map((x) => x.domain).sort()).toEqual(["career", "family", "health", "love", "mental", "money"]);
    for (const x of v) {
      expect(["좋음", "보통", "주의"]).toContain(x.tone);
      expect(x.note.length).toBeGreaterThan(8);
    }
  });

  it("결정론: 같은 입력이면 같은 결과", () => {
    const c = computeZiweiChart(birthA)!;
    expect(deriveZiweiDomainVerdicts(c)).toEqual(deriveZiweiDomainVerdicts(c));
  });

  it("표면 note에 자미두수 용어를 노출하지 않는다", () => {
    const surface = deriveZiweiDomainVerdicts(computeZiweiChart(birthB)!).map((x) => x.note).join(" ");
    for (const term of JARGON) expect(surface).not.toContain(term);
  });

  it("evidence(전문가 근거)에는 궁·별 근거를 남긴다", () => {
    const v = deriveZiweiDomainVerdicts(computeZiweiChart(birthA)!);
    expect(v.every((x) => x.evidence.includes("궁"))).toBe(true);
  });

  it("서로 다른 사람은 분야 판정 조합이 달라진다(개인차)", () => {
    const a = deriveZiweiDomainVerdicts(computeZiweiChart(birthA)!).map((x) => x.tone).join("");
    const b = deriveZiweiDomainVerdicts(computeZiweiChart(birthB)!).map((x) => x.tone).join("");
    expect(a).not.toBe(b);
  });
});
