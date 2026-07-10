import { describe, expect, it } from "vitest";
import { buildCompactEvidence, type CompactEvidence } from "./compactEvidence.js";
import { evidenceRefsFromCompactEvidence } from "./evidenceIds.js";
import { mockCompactEvidence } from "./judgmentTestFixture.js";
import { triggerRules } from "./ruleEngine.js";
import { computeLuckCycles, computeSajuChart } from "./saju.js";
import type { BirthInfo } from "../types/index.js";

function fire(compactEvidence: CompactEvidence, question?: string) {
  const evidence = evidenceRefsFromCompactEvidence(compactEvidence);
  return triggerRules({ readingType: "saju", compactEvidence, evidence, question });
}

describe("ruleEngine", () => {
  it("compact evidence에서 rule id와 근거를 가진 rule을 발동한다", () => {
    const rules = fire(mockCompactEvidence(), "퇴사 후 창업해도 될까요?");

    expect(rules.map((rule) => rule.id)).toContain("rule.career.change");
    expect(rules.map((rule) => rule.id)).toContain("rule.money.risk");
    expect(rules.map((rule) => rule.id)).toContain("rule.startup.not_recommended");
    expect(rules.every((rule) => rule.evidence.length > 0)).toBe(true);
  });
});

describe("ruleEngine — 4대 고전 심화 규칙 (엔진 업그레이드 S-2)", () => {
  function withDeep(overrides: Partial<CompactEvidence>, ids: Record<string, string>): CompactEvidence {
    const base = mockCompactEvidence();
    return { ...base, ...overrides, evidenceIds: { ...base.evidenceIds, ...ids } };
  }

  it("성격 패턴이 갖춰진 격국은 structure.solid를 발동한다", () => {
    const ce = withDeep(
      {
        structure: {
          name: "식신격", status: "성격 경향", pattern: "식신생재(食神生財)",
          failures: [], established: "성격", note: "성격 패턴: 식신생재",
        },
      },
      { structure_classic: "격국 심화(자평진전): 식신격 성격 / 패턴 식신생재(食神生財)" },
    );
    const ids = fire(ce).map((r) => r.id);
    expect(ids).toContain("rule.structure.solid");
    expect(ids).not.toContain("rule.structure.broken");
  });

  it("간이 성패가 파격 경향(월지 충)이면 성격이어도 solid를 내지 않는다 — 층위 모순 회피", () => {
    const ce = withDeep(
      {
        structure: {
          name: "식신격", status: "파격 경향", pattern: "식신생재(食神生財)",
          failures: [], established: "성격", note: "",
        },
      },
      { structure_classic: "격국 심화(자평진전): 식신격 성격" },
    );
    expect(fire(ce).map((r) => r.id)).not.toContain("rule.structure.solid");
  });

  it("파격 요인이 있으면 structure.broken을 constraint로 발동하고 도메인을 요인에 맞춘다", () => {
    const ce = withDeep(
      {
        structure: {
          name: "정재격", status: "성격 경향", failures: ["재다신약(財多身弱)"],
          established: "파격", note: "파격 요인: 재다신약",
        },
      },
      { structure_classic: "격국 심화(자평진전): 정재격 파격 / 파격 요인 재다신약(財多身弱)" },
    );
    const rules = fire(ce);
    const broken = rules.find((r) => r.id === "rule.structure.broken");
    expect(broken).toBeDefined();
    expect(broken?.domain).toBe("money");
    expect(broken?.result).toBe("constraint");
  });

  it("궁통보감 1순위 조후 미충족이면 climate.unmet을 health constraint로 발동한다", () => {
    const ce = withDeep(
      {
        climateClassic: {
          priorityStems: ["계", "정"], primaryElement: "수", satisfied: false,
          missingStems: ["계"], note: "1순위 계(수)가 원국에 뚜렷하지 않습니다.",
        },
      },
      { climate_classic: "조후(궁통보감): 우선 천간 계→정 / 1순위 수 미충족" },
    );
    const rule = fire(ce).find((r) => r.id === "rule.climate.unmet");
    expect(rule).toBeDefined();
    expect(rule?.domain).toBe("health");
    expect(rule?.result).toBe("constraint");
  });

  it("십성 분포가 절반 이상 몰리거나 두 그룹이 비면 tengod.skew를 발동한다", () => {
    const ce = withDeep(
      {
        tenGodProfile: {
          groups: { 비겁: 6, 식상: 0, 재성: 0, 관성: 2, 인성: 2 },
          dominant: ["비겁"], missing: ["식상", "재성"],
        },
      },
      { tengod_profile: "십성 세기 분포(연해자평 가중 합산): 비겁:6 식상:0 재성:0 관성:2 인성:2" },
    );
    const rule = fire(ce).find((r) => r.id === "rule.tengod.skew");
    expect(rule).toBeDefined();
    expect(rule?.domain).toBe("personality");
  });

  it("고른 십성 분포에서는 tengod.skew를 발동하지 않는다", () => {
    const ce = withDeep(
      {
        tenGodProfile: {
          groups: { 비겁: 2, 식상: 2.2, 재성: 1.8, 관성: 2, 인성: 2 },
          dominant: ["식상"], missing: [],
        },
      },
      { tengod_profile: "십성 세기 분포(연해자평 가중 합산): 고른 분포" },
    );
    expect(fire(ce).map((r) => r.id)).not.toContain("rule.tengod.skew");
  });

  it("실제 원국(1972-01-30 06:00 남)에서 탐재괴인 파격이 결정론적으로 재현된다", () => {
    const birth: BirthInfo = { calendarType: "solar", year: 1972, month: 1, day: 30, hour: 6, minute: 0, gender: "male" };
    const chart = computeSajuChart(birth);
    const luck = computeLuckCycles(birth, new Date("2026-07-03T03:00:00Z"));
    const ce = buildCompactEvidence(chart, luck, birth.gender);
    const broken = fire(ce).find((r) => r.id === "rule.structure.broken");
    expect(ce.structure?.failures.some((f) => f.includes("탐재괴인"))).toBe(true);
    expect(broken).toBeDefined();
    expect(broken?.domain).toBe("career");
  });
});
