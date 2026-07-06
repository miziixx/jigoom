import type { BirthInfo, ReadingType } from "../../types/index.js";
import type {
  EvidenceRef,
  JudgmentAuditLog,
  JudgmentCandidate,
  JudgmentCode,
  JudgmentDomain,
  JudgmentPack,
} from "../judgmentTypes.js";
import { JUDGMENT_SCHEMA_VERSION } from "../judgmentTypes.js";
import type {
  Case,
  CaseDomainOutcome,
  CaseEventKind,
  CaseSource,
  CaseUserFeedback,
  CaseValence,
  ExpertReview,
} from "./caseTypes.js";
import { CODE_EXPECTATION, RULE_FOR_CODE } from "./caseScore.js";

/**
 * 사례 검증 테스트 픽스처 + 판단 팩 팩토리.
 *
 * 실제 엔진(saju.ts/judgmentEngine)을 돌리지 않고도 검증 로직을 테스트할 수 있도록,
 * 실 구조와 동일한 JudgmentPack을 가볍게 만들어 Case와 짝지운다.
 * 계산·룰·판단 로직은 전혀 건드리지 않는다 (테스트 데이터 생성 전용).
 */

function ev(id: string): EvidenceRef {
  return { id, source: "chart", strength: 3, direction: "support", summary: id };
}

export interface MakeJudgmentOptions {
  id?: string;
  confidence?: number;
  ruleIds?: JudgmentCandidate["triggeredRuleIds"];
}

/** JudgmentCode 하나로 실 구조와 동일한 JudgmentCandidate를 만든다. */
export function makeJudgment(code: JudgmentCode, opts: MakeJudgmentOptions = {}): JudgmentCandidate {
  const exp = CODE_EXPECTATION[code];
  const defaultRule = RULE_FOR_CODE[code];
  const ruleIds = opts.ruleIds ?? (defaultRule ? [defaultRule] : []);
  return {
    id: opts.id ?? `j.${code}`,
    code,
    domain: exp.domain as JudgmentDomain,
    kind: "timing",
    plainConclusion: code,
    evidence: [ev(`ev.${code}`)],
    counterEvidence: [],
    confidence: {
      chart: 0,
      luck: 0,
      event: 0,
      context: 0,
      overall: opts.confidence ?? 60,
      reasons: [],
    },
    allowedTone: { stance: "balanced", modality: "should_say", wordingHints: [] },
    forbiddenClaims: [],
    triggeredRuleIds: ruleIds,
    actionFrame: { do: [], avoid: [], checkSignals: [] },
    uncertainty: { level: "medium", reasons: [] },
  };
}

export interface MakePackOptions {
  readingType?: ReadingType;
  audit?: Partial<JudgmentAuditLog>;
  generatedAt?: string;
}

/** JudgmentCandidate 배열로 실 구조와 동일한 JudgmentPack을 만든다. */
export function makePack(judgments: JudgmentCandidate[], opts: MakePackOptions = {}): JudgmentPack {
  return {
    schemaVersion: JUDGMENT_SCHEMA_VERSION,
    readingType: opts.readingType ?? "saju",
    generatedAt: opts.generatedAt ?? "2026-01-01T00:00:00.000Z",
    evidence: judgments.flatMap((j) => j.evidence),
    triggeredRules: [],
    judgments,
    contradictions: [],
    globalForbiddenClaims: [],
    decisionTrace: [],
    audit: {
      schemaVersion: JUDGMENT_SCHEMA_VERSION,
      evidenceIds: judgments.flatMap((j) => j.evidence.map((e) => e.id)),
      ruleIds: [],
      judgmentIds: judgments.map((j) => j.id),
      ...opts.audit,
    },
  };
}

function outcome(
  domain: CaseDomainOutcome["domain"],
  happened: boolean,
  valence: CaseValence,
  events?: CaseEventKind[],
  note?: string,
): CaseDomainOutcome {
  return { domain, happened, valence, events, note };
}

const birthA: BirthInfo = { calendarType: "solar", year: 1988, month: 7, day: 15, hour: 13, minute: 20, gender: "female" };
const birthB: BirthInfo = { calendarType: "solar", year: 1990, month: 12, day: 23, hour: 8, minute: 0, gender: "female" };
const birthC: BirthInfo = { calendarType: "solar", year: 1985, month: 3, day: 2, hour: 21, minute: 0, gender: "male" };
const birthD: BirthInfo = { calendarType: "solar", year: 1993, month: 11, day: 9, hour: null, gender: "male" };
const birthE: BirthInfo = { calendarType: "lunar", year: 1979, month: 5, day: 20, hour: 6, minute: 30, gender: "female" };

interface FixtureSpec {
  id: string;
  source?: CaseSource;
  birth: BirthInfo;
  readingType?: ReadingType;
  judgments: JudgmentCandidate[];
  outcomes: CaseDomainOutcome[];
  years?: [number, number];
  userFeedback?: CaseUserFeedback;
  expertReview?: ExpertReview;
  audit?: Partial<JudgmentAuditLog>;
  note?: string;
}

export interface CaseFixture {
  pack: JudgmentPack;
  case: Case;
}

function fixture(spec: FixtureSpec): CaseFixture {
  const [from, to] = spec.years ?? [2022, 2023];
  return {
    pack: makePack(spec.judgments, { readingType: spec.readingType, audit: spec.audit }),
    case: {
      id: spec.id,
      source: spec.source ?? "fixture",
      birth: spec.birth,
      readingType: spec.readingType ?? "saju",
      observedYearFrom: from,
      observedYearTo: to,
      actualOutcomes: spec.outcomes,
      userFeedback: spec.userFeedback,
      expertReview: spec.expertReview,
      note: spec.note,
    },
  };
}

/**
 * 20건 이상의 검증 픽스처.
 * career/money/love/health/startup/move/family + 혼합, match/partial/miss가 골고루 나오도록 구성.
 */
export const caseFixtures: CaseFixture[] = [
  // 1. career 적중: 변화 예측 → 실제 이직
  fixture({
    id: "case-career-hit-1",
    birth: birthA,
    judgments: [makeJudgment("CAREER_CHANGE_HIGH", { confidence: 78 })],
    outcomes: [outcome("career", true, "positive", ["occupation_change"], "2022년 이직")],
    userFeedback: { rating: "accurate" },
  }),
  // 2. career 빗나감: 변화 예측 → 실제 변화 없음
  fixture({
    id: "case-career-miss-1",
    birth: birthB,
    judgments: [makeJudgment("CAREER_CHANGE_HIGH", { confidence: 72 })],
    outcomes: [outcome("career", false, "neutral", [], "한 직장 유지")],
    userFeedback: { rating: "inaccurate" },
  }),
  // 3. career 안정 예측 적중: 큰 사건 없음
  fixture({
    id: "case-career-stable-hit",
    birth: birthC,
    judgments: [makeJudgment("CAREER_STABLE_CAUTION", { confidence: 55, ruleIds: [] })],
    outcomes: [outcome("career", false, "neutral")],
    userFeedback: { rating: "partial" },
  }),
  // 4. money 위험 예측 적중: 실제 손실
  fixture({
    id: "case-money-risk-hit",
    birth: birthA,
    judgments: [makeJudgment("MONEY_RISK_MEDIUM", { confidence: 68 })],
    outcomes: [outcome("money", true, "negative", ["money_loss"], "투자 손실")],
    userFeedback: { rating: "accurate" },
    expertReview: { verdict: "correct", comment: "세운 재성 충 부합" },
  }),
  // 5. money 위험 예측 빗나감: 실제 이득
  fixture({
    id: "case-money-risk-miss",
    birth: birthB,
    judgments: [makeJudgment("MONEY_RISK_MEDIUM", { confidence: 64 })],
    outcomes: [outcome("money", true, "positive", ["money_gain"], "성과급 상승")],
    userFeedback: { rating: "inaccurate" },
  }),
  // 6. money 기회 예측 적중
  fixture({
    id: "case-money-opp-hit",
    birth: birthC,
    judgments: [makeJudgment("MONEY_OPPORTUNITY", { confidence: 70 })],
    outcomes: [outcome("money", true, "positive", ["money_gain"])],
    userFeedback: { rating: "accurate" },
  }),
  // 7. money 기회 예측 부분: 사건 없음(미실현)
  fixture({
    id: "case-money-opp-partial",
    birth: birthD,
    judgments: [makeJudgment("MONEY_OPPORTUNITY", { confidence: 60 })],
    outcomes: [outcome("money", false, "neutral")],
    userFeedback: { rating: "unsure" },
  }),
  // 8. love 안정 예측 적중
  fixture({
    id: "case-love-stable-hit",
    birth: birthA,
    judgments: [makeJudgment("LOVE_STABLE", { confidence: 66 })],
    outcomes: [outcome("love", false, "neutral", [], "관계 유지")],
    userFeedback: { rating: "accurate" },
  }),
  // 9. love 안정 예측 빗나감: 이혼
  fixture({
    id: "case-love-stable-miss",
    birth: birthE,
    judgments: [makeJudgment("LOVE_STABLE", { confidence: 62 })],
    outcomes: [outcome("love", true, "negative", ["divorce"], "이혼")],
    userFeedback: { rating: "inaccurate" },
    expertReview: { verdict: "wrong", comment: "배우자궁 충 놓침" },
  }),
  // 10. love 지연(위험) 예측 적중: 이별
  fixture({
    id: "case-love-delay-hit",
    birth: birthB,
    judgments: [makeJudgment("LOVE_DELAY", { confidence: 58 })],
    outcomes: [outcome("love", true, "negative", ["breakup"])],
    userFeedback: { rating: "partial" },
  }),
  // 11. love 지연 예측 부분: 새 인연(긍정) → 방향 어긋남은 아니고 사건 있었으나 예측은 위험
  fixture({
    id: "case-love-delay-miss",
    birth: birthC,
    judgments: [makeJudgment("LOVE_DELAY", { confidence: 54 })],
    outcomes: [outcome("love", true, "positive", ["new_relationship"], "새 인연")],
    userFeedback: { rating: "inaccurate" },
  }),
  // 12. health 위험 예측 적중
  fixture({
    id: "case-health-hit",
    birth: birthD,
    judgments: [makeJudgment("HEALTH_CAUTION", { confidence: 60 })],
    outcomes: [outcome("health", true, "negative", ["health_issue"], "과로로 컨디션 저하")],
    userFeedback: { rating: "accurate" },
  }),
  // 13. health 위험 예측 부분: 사건 없음
  fixture({
    id: "case-health-partial",
    birth: birthA,
    judgments: [makeJudgment("HEALTH_CAUTION", { confidence: 52 })],
    outcomes: [outcome("health", false, "neutral")],
    userFeedback: { rating: "partial" },
  }),
  // 14. startup 위험(비권장) 예측 적중: 창업 후 부정
  fixture({
    id: "case-startup-notrec-hit",
    birth: birthC,
    judgments: [makeJudgment("STARTUP_NOT_RECOMMENDED", { confidence: 65 })],
    outcomes: [outcome("startup", true, "negative", ["startup"], "창업 후 어려움")],
    userFeedback: { rating: "accurate" },
    expertReview: { verdict: "correct" },
  }),
  // 15. startup 검증우선(기회) 예측 적중
  fixture({
    id: "case-startup-test-hit",
    birth: birthB,
    judgments: [makeJudgment("STARTUP_TEST_FIRST", { confidence: 58 })],
    outcomes: [outcome("startup", true, "positive", ["startup"], "소규모 시작 성공")],
    userFeedback: { rating: "accurate" },
  }),
  // 16. move 위험 예측 적중
  fixture({
    id: "case-move-hit",
    birth: birthE,
    judgments: [makeJudgment("MOVE_CAUTION", { confidence: 56 })],
    outcomes: [outcome("move", true, "negative", ["move"], "이사 후 계약 문제")],
    userFeedback: { rating: "partial" },
  }),
  // 17. move 위험 예측 부분: 이사했지만 문제 없음(중립)
  fixture({
    id: "case-move-neutral",
    birth: birthD,
    judgments: [makeJudgment("MOVE_CAUTION", { confidence: 50 })],
    outcomes: [outcome("move", true, "neutral", ["move"])],
    userFeedback: { rating: "partial" },
  }),
  // 18. family 사건 예측 적중
  fixture({
    id: "case-family-hit",
    birth: birthA,
    judgments: [makeJudgment("FAMILY_RESPONSIBILITY", { confidence: 62 })],
    outcomes: [outcome("family", true, "neutral", ["family_event"], "가족 부양 이슈")],
    userFeedback: { rating: "accurate" },
  }),
  // 19. 일반 흐름 판단: 대조 대상 아님 (unscored 확인용)
  fixture({
    id: "case-general-unscored",
    birth: birthB,
    judgments: [makeJudgment("GENERAL_MIXED_FLOW", { confidence: 45 })],
    outcomes: [outcome("career", true, "positive", ["promotion"])],
    userFeedback: { rating: "unsure" },
  }),
  // 20. 다중 판단 혼합 + rewrite 발생
  fixture({
    id: "case-multi-rewrite",
    birth: birthC,
    judgments: [
      makeJudgment("CAREER_CHANGE_HIGH", { id: "j.multi.career", confidence: 74 }),
      makeJudgment("MONEY_RISK_MEDIUM", { id: "j.multi.money", confidence: 66 }),
      makeJudgment("HEALTH_CAUTION", { id: "j.multi.health", confidence: 58 }),
    ],
    outcomes: [
      outcome("career", true, "positive", ["occupation_change"]),
      outcome("money", true, "negative", ["money_loss"]),
      outcome("health", false, "neutral"),
    ],
    audit: { validationStatus: "rewrite", rewriteAttempted: true },
    userFeedback: { rating: "accurate" },
    expertReview: {
      verdict: "partially_correct",
      ruleVerdicts: [
        { ruleId: "rule.career.change", verdict: "correct" },
        { ruleId: "rule.health.caution", verdict: "partially_correct", comment: "과잉 경고" },
      ],
    },
  }),
  // 21. 다중 판단 혼합 + fallback 발생
  fixture({
    id: "case-multi-fallback",
    birth: birthE,
    readingType: "combo",
    judgments: [
      makeJudgment("LOVE_STABLE", { id: "j.fb.love", confidence: 60 }),
      makeJudgment("MONEY_OPPORTUNITY", { id: "j.fb.money", confidence: 68 }),
    ],
    outcomes: [
      outcome("love", false, "neutral"),
      outcome("money", true, "positive", ["money_gain"]),
    ],
    audit: { validationStatus: "fallback", fallbackUsed: true },
    userFeedback: { rating: "partial" },
  }),
  // 22. career 부분 적중: 사건 없는데 안정 예측 아님 → 변화 예측 miss + money 기회 미실현
  fixture({
    id: "case-mixed-lowscore",
    birth: birthD,
    judgments: [
      makeJudgment("CAREER_CHANGE_HIGH", { id: "j.mix.career", confidence: 70 }),
      makeJudgment("MONEY_OPPORTUNITY", { id: "j.mix.money", confidence: 62 }),
    ],
    outcomes: [
      outcome("career", false, "neutral"),
      outcome("money", false, "neutral"),
    ],
    userFeedback: { rating: "inaccurate" },
  }),
];

/** 픽스처를 (pack, case) 쌍으로 반환 (검증기 입력용) */
export function fixturePairs(): { pack: JudgmentPack; case: Case }[] {
  return caseFixtures.map((f) => ({ pack: f.pack, case: f.case }));
}
