import { describe, expect, it } from "vitest";
import { scoreMatch, expectationFor, CODE_EXPECTATION } from "./caseScore.js";
import { validateCase, validateCases } from "./caseValidator.js";
import { computeMetrics } from "./caseMetrics.js";
import {
  addCase,
  addCases,
  createDataset,
  deserializeDataset,
  filterByDomain,
  filterBySource,
  getCase,
  serializeDataset,
  withExpertReview,
  withUserFeedback,
} from "./caseDataset.js";
import { buildCaseReport, formatCaseReport } from "./caseReport.js";
import { caseFixtures, fixturePairs, makeJudgment, makePack } from "./caseFixtures.js";
import type { Case, CaseDomainOutcome } from "./caseTypes.js";
import type { BirthInfo } from "../../types/index.js";

const birth: BirthInfo = { calendarType: "solar", year: 1988, month: 7, day: 15, hour: 13, minute: 20, gender: "female" };

function outcome(
  domain: CaseDomainOutcome["domain"],
  happened: boolean,
  valence: CaseDomainOutcome["valence"],
): CaseDomainOutcome {
  return { domain, happened, valence };
}

function caseWith(id: string, outcomes: CaseDomainOutcome[], extra: Partial<Case> = {}): Case {
  return {
    id,
    source: "fixture",
    birth,
    readingType: "saju",
    observedYearFrom: 2022,
    observedYearTo: 2023,
    actualOutcomes: outcomes,
    ...extra,
  };
}

describe("caseScore", () => {
  it("모든 JudgmentCode에 예측 매핑이 있다", () => {
    const codes = Object.keys(CODE_EXPECTATION);
    expect(codes.length).toBeGreaterThanOrEqual(12);
    expect(expectationFor("CAREER_CHANGE_HIGH").predicted).toBe("event");
    expect(expectationFor("GENERAL_MIXED_FLOW").predicted).toBe("none");
  });

  it("event 예측: 발생하면 match, 없으면 miss", () => {
    expect(scoreMatch("event", outcome("career", true, "positive")).level).toBe("match");
    expect(scoreMatch("event", outcome("career", false, "neutral")).level).toBe("miss");
  });

  it("stability 예측: 사건 없으면 match, 부정 사건이면 miss", () => {
    expect(scoreMatch("stability", outcome("love", false, "neutral")).level).toBe("match");
    expect(scoreMatch("stability", outcome("love", true, "negative")).level).toBe("miss");
    expect(scoreMatch("stability", outcome("love", true, "positive")).level).toBe("partial");
  });

  it("risk 예측: 부정 사건 match, 긍정 사건 miss, 사건 없음 partial", () => {
    expect(scoreMatch("risk", outcome("money", true, "negative")).level).toBe("match");
    expect(scoreMatch("risk", outcome("money", true, "positive")).level).toBe("miss");
    expect(scoreMatch("risk", outcome("money", false, "neutral")).level).toBe("partial");
    expect(scoreMatch("risk", outcome("money", true, "neutral")).level).toBe("partial");
  });

  it("opportunity 예측: 긍정 사건 match, 부정 사건 miss, 사건 없음 partial", () => {
    expect(scoreMatch("opportunity", outcome("money", true, "positive")).level).toBe("match");
    expect(scoreMatch("opportunity", outcome("money", true, "negative")).level).toBe("miss");
    expect(scoreMatch("opportunity", outcome("money", false, "neutral")).level).toBe("partial");
  });

  it("등급은 점수로 환산된다", () => {
    expect(scoreMatch("event", outcome("career", true, "positive")).score).toBe(100);
    expect(scoreMatch("event", outcome("career", false, "neutral")).score).toBe(0);
  });
});

describe("caseValidator", () => {
  it("변화 예측이 실제 사건과 맞으면 match 100", () => {
    const pack = makePack([makeJudgment("CAREER_CHANGE_HIGH", { confidence: 78 })]);
    const result = validateCase(pack, caseWith("c1", [outcome("career", true, "positive")]));
    expect(result.matchRate).toBe(100);
    expect(result.scoredCount).toBe(1);
    expect(result.unscoredCount).toBe(0);
    expect(result.outcomes[0].level).toBe("match");
  });

  it("일반 흐름 판단(none)은 대조 대상에서 제외된다", () => {
    const pack = makePack([makeJudgment("GENERAL_MIXED_FLOW")]);
    const result = validateCase(pack, caseWith("c2", [outcome("career", true, "positive")]));
    expect(result.matchRate).toBeNull();
    expect(result.scoredCount).toBe(0);
    expect(result.unscoredCount).toBe(1);
    expect(result.outcomes[0].scored).toBe(false);
  });

  it("해당 분야 실제 결과가 없으면 대조 불가", () => {
    const pack = makePack([makeJudgment("MONEY_RISK_MEDIUM")]);
    const result = validateCase(pack, caseWith("c3", [outcome("career", true, "positive")]));
    expect(result.scoredCount).toBe(0);
    expect(result.outcomes[0].scored).toBe(false);
  });

  it("여러 판단의 평균으로 matchRate를 낸다", () => {
    const pack = makePack([
      makeJudgment("CAREER_CHANGE_HIGH", { id: "a", confidence: 74 }),
      makeJudgment("MONEY_RISK_MEDIUM", { id: "b", confidence: 66 }),
      makeJudgment("HEALTH_CAUTION", { id: "c", confidence: 58 }),
    ]);
    const result = validateCase(
      pack,
      caseWith("c4", [
        outcome("career", true, "positive"), // match 100
        outcome("money", true, "negative"), // match 100
        outcome("health", false, "neutral"), // partial 70
      ]),
    );
    expect(result.matchRate).toBe(90); // (100+100+70)/3
  });

  it("audit의 rewrite/fallback을 반영한다", () => {
    const rewrite = makePack([makeJudgment("CAREER_CHANGE_HIGH")], {
      audit: { validationStatus: "rewrite", rewriteAttempted: true },
    });
    const r = validateCase(rewrite, caseWith("c5", [outcome("career", true, "positive")]));
    expect(r.rewriteUsed).toBe(true);
    expect(r.validationStatus).toBe("rewrite");
  });

  it("사용자/전문가 평가를 결과에 담는다", () => {
    const pack = makePack([makeJudgment("CAREER_CHANGE_HIGH")]);
    const r = validateCase(
      pack,
      caseWith("c6", [outcome("career", true, "positive")], {
        userFeedback: { rating: "accurate" },
        expertReview: { verdict: "correct" },
      }),
    );
    expect(r.userRating).toBe("accurate");
    expect(r.expertVerdict).toBe("correct");
  });
});

describe("caseFixtures", () => {
  it("최소 20개 픽스처가 있다", () => {
    expect(caseFixtures.length).toBeGreaterThanOrEqual(20);
  });

  it("모든 픽스처는 실 구조 JudgmentPack을 가진다", () => {
    for (const f of caseFixtures) {
      expect(f.pack.schemaVersion).toBeDefined();
      expect(f.pack.judgments.length).toBeGreaterThan(0);
      expect(f.case.actualOutcomes.length).toBeGreaterThan(0);
    }
  });

  it("모든 픽스처는 검증기를 통과한다(예외 없이 결과 생성)", () => {
    const results = validateCases(fixturePairs());
    expect(results.length).toBe(caseFixtures.length);
    // career/money/love/health/startup/move/family가 최소 한 번씩 대조된다
    const domains = new Set(
      results.flatMap((r) => r.outcomes.filter((o) => o.scored).map((o) => o.domain)),
    );
    for (const d of ["career", "money", "love", "health", "startup", "move", "family"]) {
      expect(domains.has(d as never)).toBe(true);
    }
  });
});

describe("caseMetrics", () => {
  it("rule/judgment/confidence 통계를 집계한다", () => {
    const results = validateCases(fixturePairs());
    const metrics = computeMetrics(results);
    expect(metrics.totalCases).toBe(caseFixtures.length);
    expect(metrics.overallMatchRate).not.toBeNull();
    expect(metrics.overallMatchRate! >= 0 && metrics.overallMatchRate! <= 100).toBe(true);

    const careerRule = metrics.ruleMetrics.find((r) => r.ruleId === "rule.career.change");
    expect(careerRule).toBeDefined();
    expect(careerRule!.triggerCount).toBeGreaterThan(0);
    expect(careerRule!.matchCount + careerRule!.partialCount + careerRule!.missCount).toBe(
      careerRule!.scoredCount,
    );

    const changeJudgment = metrics.judgmentMetrics.find((j) => j.code === "CAREER_CHANGE_HIGH");
    expect(changeJudgment).toBeDefined();

    // confidence bin 합 = scored 판단 수
    const binTotal = metrics.confidenceBins.reduce((s, b) => s + b.count, 0);
    expect(binTotal).toBe(metrics.scoredJudgments);
  });

  it("rewrite/fallback 발생률을 계산한다", () => {
    const results = validateCases(fixturePairs());
    const metrics = computeMetrics(results);
    expect(metrics.rewriteRate).toBeGreaterThan(0);
    expect(metrics.fallbackRate).toBeGreaterThan(0);
  });

  it("사용자 피드백 평균이 rule에 연결된다", () => {
    const results = validateCases(fixturePairs());
    const metrics = computeMetrics(results);
    const careerRule = metrics.ruleMetrics.find((r) => r.ruleId === "rule.career.change");
    expect(careerRule!.avgUserFeedback).not.toBeNull();
  });
});

describe("caseDataset", () => {
  const cases = caseFixtures.map((f) => f.case);

  it("생성 시 id 중복을 제거한다", () => {
    const dup = createDataset([cases[0], cases[0], cases[1]]);
    expect(dup.cases.length).toBe(2);
  });

  it("addCase는 불변이며 같은 id는 교체한다", () => {
    const ds = createDataset([cases[0]]);
    const next = addCase(ds, cases[1]);
    expect(ds.cases.length).toBe(1); // 원본 불변
    expect(next.cases.length).toBe(2);
    const replaced = addCase(next, { ...cases[0], note: "updated" });
    expect(replaced.cases.length).toBe(2);
    expect(getCase(replaced, cases[0].id)!.note).toBe("updated");
  });

  it("source/domain/피드백/전문가로 필터링한다", () => {
    const ds = addCases(createDataset(), cases);
    expect(filterBySource(ds, "fixture").length).toBe(cases.length);
    expect(filterByDomain(ds, "career").length).toBeGreaterThan(0);
    expect(withUserFeedback(ds).length).toBeGreaterThan(0);
    expect(withExpertReview(ds).length).toBeGreaterThan(0);
  });

  it("직렬화/역직렬화 round-trip이 보존된다", () => {
    const ds = addCases(createDataset(), cases);
    const restored = deserializeDataset(serializeDataset(ds));
    expect(restored.cases.length).toBe(ds.cases.length);
    expect(getCase(restored, cases[0].id)).toBeDefined();
  });
});

describe("caseReport", () => {
  it("전체/분야별/Rule/보정 후보 리포트를 만든다", () => {
    const results = validateCases(fixturePairs());
    const report = buildCaseReport(results, { now: () => new Date("2026-07-06T00:00:00.000Z") });
    expect(report.generatedAt).toBe("2026-07-06T00:00:00.000Z");
    expect(report.totalCases).toBe(caseFixtures.length);
    expect(report.overallMatchRate).not.toBeNull();
    expect(report.domainMatches.some((d) => d.domain === "career")).toBe(true);
    expect(report.topRules.length).toBeGreaterThan(0);
    expect(report.confidenceBins.length).toBe(5);
    // 20건 이상이므로 "사례 부족" 경고는 없다
    expect(report.humanReviewNotes.some((n) => n.includes("20건 이상"))).toBe(false);
  });

  it("보정 후보는 confidence와 실제 적중 gap이 큰 rule만 담는다", () => {
    const results = validateCases(fixturePairs());
    const report = buildCaseReport(results, { calibrationGap: 20 });
    for (const s of report.calibrationSuggestions) {
      expect(Math.abs(s.gap)).toBeGreaterThanOrEqual(20);
    }
  });

  it("사례가 적으면 사람 검토 경고를 붙인다", () => {
    const results = validateCases(fixturePairs().slice(0, 3));
    const report = buildCaseReport(results);
    expect(report.humanReviewNotes.some((n) => n.includes("20건 이상"))).toBe(true);
  });

  it("텍스트 포맷을 생성한다", () => {
    const results = validateCases(fixturePairs());
    const text = formatCaseReport(buildCaseReport(results));
    expect(text).toContain("사례 검증 리포트");
    expect(text).toContain("분야별 적중");
    expect(text).toContain("Confidence 분포");
  });
});
