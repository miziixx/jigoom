import { describe, expect, it } from "vitest";
import {
  buildQualityEvent,
  logReading,
} from "./qualityLogger.js";
import {
  MemoryQualityStore,
  LocalStorageQualityStore,
  type QualityStore,
} from "./qualityStorage.js";
import { computeQualityMetrics } from "./qualityMetrics.js";
import { computeEngineHealth, explainHealthChange, HEALTH_WEIGHTS } from "./qualityHealth.js";
import { buildQualityDashboard } from "./qualityDashboard.js";
import {
  ENGINE_VERSION,
  QUALITY_SCHEMA_VERSION,
  type QualityEvent,
  type QualityJudgmentPackLike,
} from "./qualityTypes.js";
import { computeLuckCycles, computeSajuChart } from "../saju.js";
import { buildReadingJudgmentPack } from "../../prompts/systemPrompt.js";
import type { BirthInfo } from "../../types/index.js";

// ── 헬퍼 ──────────

function packLike(over: Partial<QualityJudgmentPackLike> = {}): QualityJudgmentPackLike {
  return {
    judgments: [
      { code: "CAREER_CHANGE_HIGH", domain: "career", confidence: { overall: 78 }, forbiddenClaims: [{ code: "career.no_direct_resignation" }] },
      { code: "MONEY_RISK_MEDIUM", domain: "money", confidence: { overall: 62 }, forbiddenClaims: [{ code: "money.no_profit_guarantee" }] },
    ],
    triggeredRules: [{ id: "rule.career.change" }, { id: "rule.money.risk" }],
    contradictions: [{ id: "contradiction.money_opportunity.money_risk" }],
    globalForbiddenClaims: [{ code: "global.no_determinism" }],
    ...over,
  };
}

function makeEvent(over: Partial<QualityEvent> = {}): QualityEvent {
  return {
    id: Math.random().toString(36).slice(2),
    timestamp: "2026-07-06T10:00:00.000Z",
    readingType: "saju",
    schemaVersion: QUALITY_SCHEMA_VERSION,
    engineVersion: ENGINE_VERSION,
    judgmentSchemaVersion: "1.0.0",
    judgments: [
      { code: "CAREER_CHANGE_HIGH", domain: "career", confidence: 80 },
      { code: "MONEY_RISK_MEDIUM", domain: "money", confidence: 60 },
    ],
    ruleIds: ["rule.career.change", "rule.money.risk"],
    contradictionCodes: [],
    forbiddenClaimCodes: ["global.no_determinism"],
    validation: "pass",
    validationIssueCodes: [],
    gateStatus: "pass",
    rewriteAttempted: false,
    rewriteSucceeded: false,
    fallbackUsed: false,
    fallbackReasonCodes: [],
    source: "client",
    ...over,
  };
}

// ── qualityLogger / buildQualityEvent ──────────

describe("buildQualityEvent", () => {
  it("JudgmentPack에서 PII 없는 신호만 추출한다", () => {
    const event = buildQualityEvent({
      readingType: "saju",
      judgmentPack: packLike(),
      validation: { status: "pass", issues: [] },
      gate: { status: "pass", reasonCodes: [] },
      now: () => new Date("2026-07-06T00:00:00.000Z"),
      id: "fixed",
    });
    expect(event).not.toBeNull();
    expect(event!.judgments.map((j) => j.code)).toEqual(["CAREER_CHANGE_HIGH", "MONEY_RISK_MEDIUM"]);
    expect(event!.judgments[0].confidence).toBe(78);
    expect(event!.ruleIds).toEqual(["rule.career.change", "rule.money.risk"]);
    expect(event!.contradictionCodes).toEqual(["contradiction.money_opportunity.money_risk"]);
    expect(event!.forbiddenClaimCodes).toContain("global.no_determinism");
    expect(event!.forbiddenClaimCodes).toContain("career.no_direct_resignation");
    // PII 필드가 존재하지 않는다
    expect(JSON.stringify(event)).not.toMatch(/birth|name|question|reply/i);
  });

  it("pack이 없으면 null", () => {
    expect(buildQualityEvent({ readingType: "saju", judgmentPack: null })).toBeNull();
  });

  it("gate rewrite → rewriteAttempted/succeeded 반영", () => {
    const event = buildQualityEvent({
      readingType: "combo",
      judgmentPack: packLike(),
      gate: { status: "rewrite", reasonCodes: ["forbidden-claim"] },
    });
    expect(event!.gateStatus).toBe("rewrite");
    expect(event!.rewriteAttempted).toBe(true);
    expect(event!.rewriteSucceeded).toBe(true);
    expect(event!.fallbackUsed).toBe(false);
    expect(event!.fallbackReasonCodes).toContain("forbidden-claim");
  });

  it("gate fallback → fallbackUsed, validation error 요약", () => {
    const event = buildQualityEvent({
      readingType: "saju",
      judgmentPack: packLike(),
      validation: { issues: [{ code: "missing-evidence", severity: "error" }] },
      gate: { status: "fallback", reasonCodes: ["semantic-claim-violation"] },
    });
    expect(event!.gateStatus).toBe("fallback");
    expect(event!.fallbackUsed).toBe(true);
    expect(event!.rewriteSucceeded).toBe(false);
    expect(event!.validation).toBe("error");
    expect(event!.validationIssueCodes).toContain("missing-evidence");
  });

  it("warning은 error 없이 이슈만 있을 때", () => {
    const event = buildQualityEvent({
      readingType: "saju",
      judgmentPack: packLike(),
      validation: { issues: [{ code: "generic-sentence", severity: "warning" }] },
    });
    expect(event!.validation).toBe("warning");
  });
});

describe("logReading (Observer)", () => {
  it("이벤트를 저장소에 append하고 반환한다", () => {
    const store = new MemoryQualityStore();
    const ev = logReading({ readingType: "saju", judgmentPack: packLike() }, store);
    expect(ev).not.toBeNull();
    expect(store.count()).toBe(1);
  });

  it("pack이 없으면 저장하지 않는다", () => {
    const store = new MemoryQualityStore();
    expect(logReading({ readingType: "saju", judgmentPack: null }, store)).toBeNull();
    expect(store.count()).toBe(0);
  });

  it("저장소가 throw해도 로거는 throw하지 않는다 (리딩 보호)", () => {
    const throwing: QualityStore = {
      append() {
        throw new Error("quota exceeded");
      },
      readAll: () => [],
      clear() {},
      count: () => 0,
    };
    expect(() => logReading({ readingType: "saju", judgmentPack: packLike() }, throwing)).not.toThrow();
    expect(logReading({ readingType: "saju", judgmentPack: packLike() }, throwing)).toBeNull();
  });
});

describe("실제 엔진 JudgmentPack 대상 검증 (PII 미저장)", () => {
  const birth: BirthInfo = {
    displayName: "홍길동테스트", // 이름은 절대 이벤트에 남으면 안 된다
    calendarType: "solar",
    year: 1988,
    month: 7,
    day: 15,
    hour: 13,
    minute: 20,
    gender: "female",
  };
  const question = "회사를그만두고이직해야할까요"; // 질문 원문도 남으면 안 된다
  const chart = computeSajuChart(birth);
  const luck = computeLuckCycles(birth, new Date("2026-07-06"));
  // light depth라야 compactEvidence 경로로 실제 JudgmentPack이 생성된다
  const pack = buildReadingJudgmentPack({
    type: "saju",
    question,
    gender: birth.gender,
    sajuChart: chart,
    luckCycles: luck,
    context: { depth: "light" },
  });

  it("실제 엔진이 JudgmentPack을 생성한다", () => {
    expect(pack).not.toBeNull();
    expect(pack!.judgments.length).toBeGreaterThan(0);
  });

  it("실제 pack에서 code/rule/confidence를 추출한다", () => {
    const event = buildQualityEvent({ readingType: "saju", judgmentPack: pack });
    expect(event).not.toBeNull();
    expect(event!.judgments.length).toBe(pack!.judgments.length);
    for (const j of event!.judgments) {
      expect(j.confidence).toBeGreaterThanOrEqual(0);
      expect(j.confidence).toBeLessThanOrEqual(100);
    }
  });

  it("저장 이벤트에 개인정보(이름·생년·질문 원문)가 없다", () => {
    const event = buildQualityEvent({ readingType: "saju", judgmentPack: pack });
    const serialized = JSON.stringify(event);
    expect(serialized).not.toContain("홍길동테스트");
    expect(serialized).not.toContain("회사를그만두고");
    expect(serialized).not.toContain("1988");
    // 사주 원국 간지 같은 계산 결과도 새지 않는다 (일간)
    expect(serialized).not.toContain(chart.dayMasterGan);
  });
});

// ── qualityStorage ──────────

describe("qualityStorage", () => {
  it("MemoryStore append/readAll/clear/count", () => {
    const s = new MemoryQualityStore();
    s.append(makeEvent());
    s.append(makeEvent());
    expect(s.count()).toBe(2);
    expect(s.readAll().length).toBe(2);
    // readAll은 복사본
    s.readAll().push(makeEvent());
    expect(s.count()).toBe(2);
    s.clear();
    expect(s.count()).toBe(0);
  });

  it("cap을 넘으면 오래된 것부터 버린다(링버퍼)", () => {
    const s = new MemoryQualityStore(3);
    for (let i = 0; i < 5; i++) s.append(makeEvent({ id: `e${i}` }));
    expect(s.count()).toBe(3);
    expect(s.readAll().map((e) => e.id)).toEqual(["e2", "e3", "e4"]);
  });

  it("localStorage가 없어도 안전하다(throw 없음)", () => {
    const s = new LocalStorageQualityStore();
    expect(() => s.append(makeEvent())).not.toThrow();
    expect(s.readAll()).toEqual([]);
    expect(s.count()).toBe(0);
  });
});

// ── qualityMetrics ──────────

describe("qualityMetrics", () => {
  const now = new Date("2026-07-06T12:00:00.000Z");
  const events: QualityEvent[] = [
    makeEvent({ timestamp: "2026-07-06T09:00:00.000Z", validation: "pass" }),
    makeEvent({ timestamp: "2026-07-05T09:00:00.000Z", validation: "warning", validationIssueCodes: ["generic-sentence"] }),
    makeEvent({
      timestamp: "2026-07-02T09:00:00.000Z",
      validation: "error",
      validationIssueCodes: ["missing-evidence"],
      gateStatus: "rewrite",
      rewriteAttempted: true,
      rewriteSucceeded: true,
    }),
    makeEvent({
      timestamp: "2026-06-20T09:00:00.000Z",
      validation: "error",
      gateStatus: "fallback",
      rewriteAttempted: true,
      rewriteSucceeded: false,
      fallbackUsed: true,
      fallbackReasonCodes: ["forbidden-claim"],
    }),
  ];

  it("기간별 리딩 수", () => {
    const m = computeQualityMetrics(events, now);
    expect(m.readingCounts.total).toBe(4);
    expect(m.readingCounts.today).toBe(1); // 7/6
    expect(m.readingCounts.thisWeek).toBe(3); // 7/6,7/5,7/2 (최근 7일)
    expect(m.readingCounts.thisMonth).toBe(3); // 7월 3건
  });

  it("validation 비율", () => {
    const m = computeQualityMetrics(events, now);
    expect(m.validation.pass).toBe(1);
    expect(m.validation.warning).toBe(1);
    expect(m.validation.error).toBe(2);
    expect(m.validation.passRate).toBe(25);
  });

  it("rewrite/fallback 집계", () => {
    const m = computeQualityMetrics(events, now);
    expect(m.rewrite.attempted).toBe(2);
    expect(m.rewrite.succeeded).toBe(1);
    expect(m.rewrite.failed).toBe(1);
    expect(m.rewrite.successRate).toBe(50);
    expect(m.fallback.count).toBe(1);
    expect(m.fallback.reasonsTop[0]).toEqual({ key: "forbidden-claim", count: 1 });
  });

  it("confidence domain 평균 / judgment·rule top", () => {
    const m = computeQualityMetrics(events, now);
    const career = m.confidenceByDomain.find((d) => d.domain === "career");
    expect(career!.avgConfidence).toBe(80);
    expect(m.judgmentTop20[0].count).toBe(4); // 모든 이벤트에 CAREER_CHANGE_HIGH
    expect(m.ruleTop20.some((r) => r.key === "rule.career.change")).toBe(true);
  });

  it("recentFailures는 실패만, 최신순", () => {
    const m = computeQualityMetrics(events, now);
    expect(m.recentFailures.length).toBe(3); // pass 1건 제외
    expect(Date.parse(m.recentFailures[0].timestamp)).toBeGreaterThan(
      Date.parse(m.recentFailures[1].timestamp),
    );
  });
});

// ── qualityHealth ──────────

describe("qualityHealth", () => {
  it("가중치 합은 100", () => {
    const sum = Object.values(HEALTH_WEIGHTS).reduce((a, b) => a + b, 0);
    expect(sum).toBe(100);
  });

  it("전부 pass면 높은 Health, 컴포넌트 breakdown 제공", () => {
    const events = [makeEvent(), makeEvent(), makeEvent({ judgments: [{ code: "LOVE_STABLE", domain: "love", confidence: 82 }] })];
    const health = computeEngineHealth(events);
    expect(health.hasData).toBe(true);
    expect(health.score).toBeGreaterThan(80);
    expect(health.components).toHaveLength(5);
    // 기여도 합 ≈ score
    const contrib = health.components.reduce((s, c) => s + c.contribution, 0);
    expect(Math.abs(contrib - health.score)).toBeLessThanOrEqual(1);
  });

  it("fallback이 많으면 Health가 내려간다", () => {
    const good = [makeEvent(), makeEvent()];
    const bad = [
      makeEvent({ validation: "error", gateStatus: "fallback", rewriteAttempted: true, fallbackUsed: true }),
      makeEvent({ validation: "error", gateStatus: "fallback", rewriteAttempted: true, fallbackUsed: true }),
    ];
    expect(computeEngineHealth(bad).score).toBeLessThan(computeEngineHealth(good).score);
  });

  it("데이터 없으면 hasData=false", () => {
    const health = computeEngineHealth([]);
    expect(health.hasData).toBe(false);
    expect(health.sampleCount).toBe(0);
  });

  it("explainHealthChange가 상승/하락 컴포넌트를 짚는다", () => {
    const before = computeEngineHealth([
      makeEvent({ validation: "error", gateStatus: "fallback", rewriteAttempted: true, fallbackUsed: true }),
    ]);
    const after = computeEngineHealth([makeEvent(), makeEvent()]);
    const change = explainHealthChange(before, after);
    expect(change.overallDelta).toBeGreaterThan(0);
    expect(change.movers.length).toBeGreaterThan(0);
    expect(change.notes.length).toBeGreaterThan(0);
  });
});

// ── qualityDashboard ──────────

describe("qualityDashboard", () => {
  it("health + metrics를 담은 뷰-모델을 만든다", () => {
    const now = new Date("2026-07-06T12:00:00.000Z");
    const events = [makeEvent({ timestamp: "2026-07-06T09:00:00.000Z" })];
    const model = buildQualityDashboard(events, { now });
    expect(model.eventCount).toBe(1);
    expect(model.health.score).toBeGreaterThan(0);
    expect(model.metrics.readingCounts.total).toBe(1);
    expect(model.schemaVersion).toBe(QUALITY_SCHEMA_VERSION);
  });

  it("두 창 모두 데이터가 있으면 healthTrend를 계산한다", () => {
    const now = new Date("2026-07-14T12:00:00.000Z");
    const events = [
      // 직전 7일(7/1~7/7): fallback 많음 → 낮은 health
      makeEvent({ timestamp: "2026-07-02T09:00:00.000Z", validation: "error", gateStatus: "fallback", rewriteAttempted: true, fallbackUsed: true }),
      // 최근 7일(7/8~7/14): pass → 높은 health
      makeEvent({ timestamp: "2026-07-10T09:00:00.000Z" }),
      makeEvent({ timestamp: "2026-07-12T09:00:00.000Z" }),
    ];
    const model = buildQualityDashboard(events, { now, trendWindowDays: 7 });
    expect(model.healthTrend).not.toBeNull();
    expect(model.healthTrend!.overallDelta).toBeGreaterThan(0);
  });

  it("한 창만 데이터면 healthTrend는 null", () => {
    const now = new Date("2026-07-06T12:00:00.000Z");
    const model = buildQualityDashboard([makeEvent({ timestamp: "2026-07-06T09:00:00.000Z" })], { now });
    expect(model.healthTrend).toBeNull();
  });
});
