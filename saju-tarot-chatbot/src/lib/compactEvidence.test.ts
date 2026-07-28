import { describe, expect, it } from "vitest";
import { buildCompactEvidence, formatCompactEvidence } from "./compactEvidence.js";
import { computeLuckCycles, computeSajuChart } from "./saju.js";
import type { BirthInfo } from "../types/index.js";

const birth: BirthInfo = {
  calendarType: "solar",
  year: 1990,
  month: 12,
  day: 23,
  hour: 8,
  minute: 0,
  gender: "female",
};

describe("compactEvidence", () => {
  it("기본 리딩에 필요한 핵심 판단만 압축한다", () => {
    const chart = computeSajuChart(birth);
    const luck = computeLuckCycles(birth, new Date("2026-07-03T03:00:00Z"));
    const evidence = buildCompactEvidence(chart, luck, birth.gender);

    expect(evidence.dayMaster).toBe(chart.dayMasterGan);
    expect(evidence.strength?.label).toBe(chart.strength?.label);
    expect(evidence.topFindings.length).toBeGreaterThan(0);
    expect(evidence.domainScores.length).toBeGreaterThan(0);
    expect(Object.keys(evidence.evidenceIds)).toContain("natal_core");
    expect(Object.keys(evidence.evidenceIds)).toContain("current_luck");
  });

  it("4대 고전 심화 필드를 노출하되 evidenceIds에는 연결하지 않는다 (엔진 업그레이드 S-1)", () => {
    const chart = computeSajuChart(birth);
    const luck = computeLuckCycles(birth, new Date("2026-07-03T03:00:00Z"));
    const evidence = buildCompactEvidence(chart, luck, birth.gender);

    // 격국 심화: 기존 계산값의 읽기 전용 압축
    expect(evidence.structure?.name).toBe(chart.gyeokguk?.name);
    expect(evidence.structure?.established).toBe(chart.gyeokguk?.classic?.established);
    expect(evidence.structure?.failures).toEqual(chart.gyeokguk?.classic?.failures.map((f) => f.name) ?? []);

    // 십성 그룹 분포: 5그룹 전부 + 합계 > 0
    expect(evidence.tenGodProfile).toBeDefined();
    const groups = evidence.tenGodProfile!.groups;
    expect(Object.keys(groups).sort()).toEqual(["관성", "비겁", "식상", "인성", "재성"].sort());
    expect(Object.values(groups).reduce((a, b) => a + b, 0)).toBeGreaterThan(0);
    expect(evidence.tenGodProfile!.dominant.length).toBeGreaterThan(0);

    // 궁통보감 조후: 우선 천간과 1순위 오행이 원본과 일치
    expect(evidence.climateClassic?.priorityStems.length).toBeGreaterThan(0);
    expect(evidence.climateClassic?.primaryElement).toBe(chart.yongshin?.climaticClassic?.primaryElement);
    expect(evidence.climateClassic?.satisfied).toBe(chart.yongshin?.climaticClassic?.satisfied);

    // 핵심 신살: 최대 6개, 전부 원본 sinsal에 존재하는 항목
    expect(evidence.sinsalTop!.length).toBeGreaterThan(0);
    expect(evidence.sinsalTop!.length).toBeLessThanOrEqual(6);
    for (const hit of evidence.sinsalTop!) {
      expect(chart.sinsal?.some((s) => s.name === hit.name && s.position === hit.position)).toBe(true);
    }

    // S-2: 심화 필드가 evidenceIds(EvidenceRef 원천)에도 연결된다.
    // (S-1에서는 의도적으로 비연결이었고, S-2에서 룰 4종과 함께 연결됨 — engine-upgrade-2026-07.md)
    expect(evidence.evidenceIds.structure_classic).toContain("자평진전");
    expect(evidence.evidenceIds.tengod_profile).toContain("십성 세기 분포");
    expect(evidence.evidenceIds.climate_classic).toContain("궁통보감");
    expect(evidence.evidenceIds.sinsal_key).toContain("핵심 신살");
  });

  it("직렬화 결과에는 원자료 전체 대신 판단 JSON 필드가 중심이 된다", () => {
    const chart = computeSajuChart(birth);
    const luck = computeLuckCycles(birth, new Date("2026-07-03T03:00:00Z"));
    const text = formatCompactEvidence(buildCompactEvidence(chart, luck, birth.gender));

    expect(text).toContain('"topFindings"');
    expect(text).toContain('"domainScores"');
    expect(text).toContain('"riskFlags"');
    expect(text).not.toContain("지장간");
    expect(text).not.toContain("12운성");
    expect(text).not.toContain("앞으로 10년");
    expect(text).not.toContain("올해 1월");
  });
});
