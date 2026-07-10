import type { BirthInfo, ReadingContext, ReadingFocus } from "../../types/index.js";
import type { JudgmentCode } from "../judgmentTypes.js";
import type { GoldenCase, GoldenExpectation } from "./goldenTypes.js";

/**
 * Golden Test Cases — 31개 고정 케이스 (실제 엔진 출력에서 도출, 허용범위 회귀검사).
 * 구성: 기본 21(g01~g21) + S-2b 4대 고전 심화 5(g22~g26) + V-2 운 흐름 관찰 5(g27~g31).
 *
 * 기대값은 현재 결정론 엔진 출력을 기준으로 하되, 정확값이 아니라 "허용 범위"로 고정한다:
 *   - judgment code: 부분집합(필수)/배타(금지)만 검사 → 무해한 추가는 통과
 *   - 도메인: 핵심 도메인 필수 + 최소 개수 → 도메인이 빠지면 감지
 *   - confidence: 넓은 밴드 → 산식 급변만 감지(미세 튜닝은 통과)
 *   - contradiction: 알려진 집합 밖이면 실패 + 개수 상한
 *   - evidence: 안정적 핵심 id 소수만 필수
 * 계산·룰·판단 로직은 수정하지 않는다. 이 파일은 관찰 기대값 선언일 뿐이다.
 */

const REF = "2026-07-06";

/** 모든 케이스에 공통으로 참인 골격 */
const CORE_CODES: JudgmentCode[] = ["CAREER_CHANGE_HIGH", "MOVE_CAUTION", "FAMILY_RESPONSIBILITY"];
const CORE_DOMAINS = ["career", "move", "family"] as const;
const CORE_EVIDENCE = ["chart.natal.core", "chart.elements.balance", "chart.strength.assessment"];
const KNOWN_CONTRADICTIONS = [
  "contradiction.career_change.startup_not_recommended",
  "contradiction.money_risk.startup_test_first",
  "contradiction.love_stable.love_delay",
  "contradiction.money_opportunity.money_risk",
];

type Money = "risk" | "opp" | "none";
type Startup = "notrec" | "test" | "none";

interface CaseSpec {
  id: string;
  description: string;
  birth: BirthInfo;
  referenceDate?: string;
  question?: string;
  focus?: ReadingFocus;
  context?: ReadingContext;
  money: Money;
  startup: Startup;
  maxContradictions: number;
  minDomainCoverage: number;
}

function buildExpectation(spec: CaseSpec): GoldenExpectation {
  const required: JudgmentCode[] = [...CORE_CODES];
  const forbidden: JudgmentCode[] = [];
  if (spec.money === "risk") {
    required.push("MONEY_RISK_MEDIUM");
    forbidden.push("MONEY_OPPORTUNITY");
  } else if (spec.money === "opp") {
    required.push("MONEY_OPPORTUNITY");
    forbidden.push("MONEY_RISK_MEDIUM");
  }
  if (spec.startup === "notrec") {
    required.push("STARTUP_NOT_RECOMMENDED");
    forbidden.push("STARTUP_TEST_FIRST");
  } else if (spec.startup === "test") {
    required.push("STARTUP_TEST_FIRST");
    forbidden.push("STARTUP_NOT_RECOMMENDED");
  }
  return {
    requiredJudgmentCodes: required,
    forbiddenJudgmentCodes: forbidden,
    requiredDomains: [...CORE_DOMAINS],
    minDomainCoverage: spec.minDomainCoverage,
    structurallyValid: true,
    expectNoForbiddenClaimViolation: true,
    expectGateWouldNotForceRewrite: true,
    // 넓은 밴드: 산식 급변만 감지. FAMILY_RESPONSIBILITY는 모든 케이스에서 안정적이라 code밴드 예시로 검사.
    overallConfidence: { min: 55, max: 88 },
    confidenceByCode: { FAMILY_RESPONSIBILITY: { min: 55, max: 92 } },
    allowedContradictionIds: KNOWN_CONTRADICTIONS,
    maxContradictions: spec.maxContradictions,
    requiredEvidenceIds: CORE_EVIDENCE,
  };
}

function mk(spec: CaseSpec): GoldenCase {
  return {
    id: spec.id,
    description: spec.description,
    input: {
      birth: spec.birth,
      referenceDate: spec.referenceDate ?? REF,
      type: "saju",
      question: spec.question,
      focus: spec.focus,
      // depth 미지정(기본)이 JudgmentPack Evidence Gate를 켜는 조건이라 빈 컨텍스트를 기본값으로 쓴다.
      context: spec.context ?? {},
    },
    expect: buildExpectation(spec),
  };
}

const SPECS: CaseSpec[] = [
  { id: "g01-f1988", description: "여 1988 오시생 · 재물 기회형 · 창업코드 없음 · 모순 0", birth: { calendarType: "solar", year: 1988, month: 7, day: 15, hour: 13, minute: 20, gender: "female" }, money: "opp", startup: "none", maxContradictions: 0, minDomainCoverage: 5, focus: "career", question: "지금 이직을 준비해도 될까요" },
  { id: "g02-f1990", description: "여 1990 진시생 · 재물 위험 · 창업 비권장 · 7도메인", birth: { calendarType: "solar", year: 1990, month: 12, day: 23, hour: 8, minute: 0, gender: "female" }, money: "risk", startup: "notrec", maxContradictions: 1, minDomainCoverage: 6 },
  { id: "g03-m1985", description: "남 1985 해시생 · 재물 위험 · 직업변화 확신 낮음", birth: { calendarType: "solar", year: 1985, month: 3, day: 2, hour: 21, minute: 0, gender: "male" }, money: "risk", startup: "notrec", maxContradictions: 1, minDomainCoverage: 6 },
  { id: "g04-m1993-nohour", description: "남 1993 시간모름 · 재물 기회 · 시주 없는 계산", birth: { calendarType: "solar", year: 1993, month: 11, day: 9, hour: null, gender: "male" }, money: "opp", startup: "notrec", maxContradictions: 1, minDomainCoverage: 6 },
  { id: "g05-f1979-lunar", description: "여 1979 음력 · 음력 입력 경로", birth: { calendarType: "lunar", year: 1979, month: 5, day: 20, hour: 6, minute: 30, gender: "female" }, money: "risk", startup: "notrec", maxContradictions: 1, minDomainCoverage: 6 },
  { id: "g06-m2000-testfirst", description: "남 2000 자시생 · 창업 검증우선 · 모순(money_risk↔test_first)", birth: { calendarType: "solar", year: 2000, month: 1, day: 1, hour: 0, minute: 30, gender: "male" }, money: "risk", startup: "test", maxContradictions: 1, minDomainCoverage: 6 },
  { id: "g07-f1975-nomoney", description: "여 1975 신시생 · 재물 코드 없음 · 창업 비권장", birth: { calendarType: "solar", year: 1975, month: 9, day: 30, hour: 15, minute: 0, gender: "female" }, money: "none", startup: "notrec", maxContradictions: 1, minDomainCoverage: 5 },
  { id: "g08-m1982-nomoney-test", description: "남 1982 오시생 · 재물 없음 · 검증우선 · 모순 0", birth: { calendarType: "solar", year: 1982, month: 8, day: 25, hour: 11, minute: 0, gender: "male" }, money: "none", startup: "test", maxContradictions: 0, minDomainCoverage: 5 },
  { id: "g09-f2003-nolove", description: "여 2003 진시생 · 기회+검증우선 · 애정 코드 없음", birth: { calendarType: "solar", year: 2003, month: 4, day: 18, hour: 7, minute: 0, gender: "female" }, money: "opp", startup: "test", maxContradictions: 0, minDomainCoverage: 5 },
  { id: "g10-m1978-5dom", description: "남 1978 미시생 · 애정·건강 코드 없음 · 5도메인", birth: { calendarType: "solar", year: 1978, month: 4, day: 4, hour: 14, minute: 0, gender: "male" }, money: "risk", startup: "notrec", maxContradictions: 1, minDomainCoverage: 4 },
  { id: "g11-f1994-opp-test", description: "여 1994 신시생 · 기회+검증우선 · 모순 0 · 7도메인", birth: { calendarType: "solar", year: 1994, month: 10, day: 3, hour: 16, minute: 0, gender: "female" }, money: "opp", startup: "test", maxContradictions: 0, minDomainCoverage: 6 },
  { id: "g12-m1972-nomoney", description: "남 1972 해시생 · 재물 없음 · 창업 비권장", birth: { calendarType: "solar", year: 1972, month: 7, day: 19, hour: 22, minute: 0, gender: "male" }, money: "none", startup: "notrec", maxContradictions: 1, minDomainCoverage: 5 },
  { id: "g13-f2001", description: "여 2001 술시생 · 재물 위험 · 창업 비권장", birth: { calendarType: "solar", year: 2001, month: 9, day: 9, hour: 20, minute: 0, gender: "female" }, money: "risk", startup: "notrec", maxContradictions: 1, minDomainCoverage: 6 },
  { id: "g14-m1971-latezi", description: "남 1971 자시(23시) · 야자시 경계 계산", birth: { calendarType: "solar", year: 1971, month: 10, day: 10, hour: 23, minute: 0, gender: "male" }, money: "risk", startup: "notrec", maxContradictions: 1, minDomainCoverage: 6 },
  { id: "g15-f1965", description: "여 1965 인시생 · 고연령 · 재물 위험", birth: { calendarType: "solar", year: 1965, month: 1, day: 29, hour: 5, minute: 0, gender: "female" }, money: "risk", startup: "notrec", maxContradictions: 1, minDomainCoverage: 6 },
  { id: "g16-m1959", description: "남 1959 오시생 · 최고령 · 재물 위험", birth: { calendarType: "solar", year: 1959, month: 12, day: 31, hour: 12, minute: 0, gender: "male" }, money: "risk", startup: "notrec", maxContradictions: 1, minDomainCoverage: 6 },
  { id: "g17-f1996-decision", description: "여 1996 술시생 · 선택 고민 focus", birth: { calendarType: "solar", year: 1996, month: 2, day: 14, hour: 19, minute: 0, gender: "female" }, focus: "decision", question: "회사를 계속 다닐지 고민이에요", money: "risk", startup: "notrec", maxContradictions: 1, minDomainCoverage: 6 },
  { id: "g18-m1998-wellness", description: "남 1998 유시생 · 건강 focus", birth: { calendarType: "solar", year: 1998, month: 7, day: 7, hour: 17, minute: 0, gender: "male" }, focus: "wellness", money: "risk", startup: "notrec", maxContradictions: 1, minDomainCoverage: 6 },
  { id: "g19-f1987", description: "여 1987 사시생 · 재물 위험 · 창업 비권장", birth: { calendarType: "solar", year: 1987, month: 11, day: 22, hour: 9, minute: 0, gender: "female" }, money: "risk", startup: "notrec", maxContradictions: 1, minDomainCoverage: 6 },
  { id: "g20-m1983", description: "남 1983 사시생 · 재물 위험 · 창업 비권장", birth: { calendarType: "solar", year: 1983, month: 2, day: 28, hour: 10, minute: 0, gender: "male" }, money: "risk", startup: "notrec", maxContradictions: 1, minDomainCoverage: 6 },
  { id: "g21-f1992-relationship", description: "여 1992 축시생 · 관계 focus", birth: { calendarType: "solar", year: 1992, month: 6, day: 15, hour: 2, minute: 0, gender: "female" }, focus: "relationship", question: "지금 만나는 사람과 잘 맞을까요", money: "risk", startup: "notrec", maxContradictions: 1, minDomainCoverage: 6 },
];

/**
 * 4대 고전 심화 판단 케이스 (엔진 업그레이드 S-2b, docs/engine-upgrade-2026-07.md).
 * STRUCTURE_SOLID_SUPPORT / STRUCTURE_BROKEN_CAUTION / CLIMATE_BALANCE_NEEDED / TENGOD_SKEW_TRAIT가
 * "나와야 할 원국에서 나오고, 나오면 안 되는 원국에서는 안 나오는지"를 회귀로 고정한다.
 * 기대값은 2026-07-10 실제 엔진 출력 프로브에서 도출 (허용범위 원칙은 기존과 동일).
 */
interface DeepCaseSpec {
  id: string;
  description: string;
  birth: BirthInfo;
  requiredCodes: JudgmentCode[];
  forbiddenCodes: JudgmentCode[];
  requiredDomains: GoldenExpectation["requiredDomains"];
  extraEvidenceIds: string[];
  maxContradictions: number;
}

function mkDeep(spec: DeepCaseSpec): GoldenCase {
  return {
    id: spec.id,
    description: spec.description,
    input: {
      birth: spec.birth,
      referenceDate: REF,
      type: "saju",
      context: {},
    },
    expect: {
      requiredJudgmentCodes: [...CORE_CODES, ...spec.requiredCodes],
      forbiddenJudgmentCodes: spec.forbiddenCodes,
      requiredDomains: spec.requiredDomains,
      minDomainCoverage: 6,
      structurallyValid: true,
      expectNoForbiddenClaimViolation: true,
      expectGateWouldNotForceRewrite: true,
      overallConfidence: { min: 55, max: 88 },
      allowedContradictionIds: KNOWN_CONTRADICTIONS,
      maxContradictions: spec.maxContradictions,
      requiredEvidenceIds: [...CORE_EVIDENCE, ...spec.extraEvidenceIds],
    },
  };
}

const DEEP_SPECS: DeepCaseSpec[] = [
  {
    id: "g22-m1972-broken",
    description: "남 1972 묘시생 · 탐재괴인 파격(career) + 조후 미충족 · solid/skew 금지",
    birth: { calendarType: "solar", year: 1972, month: 1, day: 30, hour: 6, minute: 0, gender: "male" },
    requiredCodes: ["MONEY_RISK_MEDIUM", "STRUCTURE_BROKEN_CAUTION", "CLIMATE_BALANCE_NEEDED"],
    forbiddenCodes: ["STRUCTURE_SOLID_SUPPORT", "TENGOD_SKEW_TRAIT", "MONEY_OPPORTUNITY"],
    requiredDomains: ["career", "move", "family", "health"],
    extraEvidenceIds: ["chart.gyeokguk.classic", "chart.climate.classic"],
    maxContradictions: 1,
  },
  {
    id: "g23-f1993-skew",
    description: "여 1993 유시생 · 종강격 solid + 십성 편중(식상·재성 공백, 60% 점유) + 조후 미충족",
    birth: { calendarType: "solar", year: 1993, month: 9, day: 28, hour: 18, minute: 0, gender: "female" },
    requiredCodes: ["STRUCTURE_SOLID_SUPPORT", "CLIMATE_BALANCE_NEEDED", "TENGOD_SKEW_TRAIT"],
    forbiddenCodes: ["STRUCTURE_BROKEN_CAUTION"],
    requiredDomains: ["career", "move", "family", "personality"],
    extraEvidenceIds: ["chart.gyeokguk.classic", "chart.tengods.profile", "chart.climate.classic"],
    maxContradictions: 1,
  },
  {
    id: "g24-f1995-solid",
    description: "여 1995 신시생 · 관인상생 성격 패턴 solid만 · 조후 충족이라 climate 금지",
    birth: { calendarType: "solar", year: 1995, month: 3, day: 17, hour: 16, minute: 0, gender: "female" },
    requiredCodes: ["STRUCTURE_SOLID_SUPPORT", "STARTUP_TEST_FIRST"],
    forbiddenCodes: ["STRUCTURE_BROKEN_CAUTION", "CLIMATE_BALANCE_NEEDED", "TENGOD_SKEW_TRAIT"],
    requiredDomains: ["career", "move", "family", "personality"],
    extraEvidenceIds: ["chart.gyeokguk.classic"],
    maxContradictions: 1,
  },
  {
    id: "g25-f1996-climate",
    description: "여 1996 해시생 · 조후 미충족만 · est=성격이어도 간이 성패 파격 경향이라 solid 금지(층위 모순 회피)",
    birth: { calendarType: "solar", year: 1996, month: 7, day: 15, hour: 22, minute: 0, gender: "female" },
    requiredCodes: ["CLIMATE_BALANCE_NEEDED"],
    forbiddenCodes: ["STRUCTURE_SOLID_SUPPORT", "STRUCTURE_BROKEN_CAUTION", "TENGOD_SKEW_TRAIT"],
    requiredDomains: ["career", "move", "family", "health"],
    extraEvidenceIds: ["chart.climate.classic"],
    maxContradictions: 1,
  },
  {
    // g02와 같은 원국 — 심화 판단이 "하나도 안 나와야" 하는 네거티브 컨트롤.
    // (est=성격이지만 간이 성패 파격 경향 + 패턴/종격 없음, 조후 충족, 십성 고른 분포)
    id: "g26-f1990-nodeep",
    description: "여 1990 진시생(g02 동일 원국) · 심화 판단 4종 전부 미발동 — 변별력 네거티브 컨트롤",
    birth: { calendarType: "solar", year: 1990, month: 12, day: 23, hour: 8, minute: 0, gender: "female" },
    requiredCodes: ["MONEY_RISK_MEDIUM"],
    forbiddenCodes: ["STRUCTURE_SOLID_SUPPORT", "STRUCTURE_BROKEN_CAUTION", "CLIMATE_BALANCE_NEEDED", "TENGOD_SKEW_TRAIT"],
    requiredDomains: ["career", "move", "family"],
    extraEvidenceIds: [],
    maxContradictions: 1,
  },
];

/**
 * 운 흐름 관찰 케이스 (엔진 업그레이드 V-2, docs/engine-upgrade-2026-07.md).
 * JudgmentPack 밖 신호 — S-3 세운 상문·조객(`YearFlowInfo.sinsalHits`), S-4 대운 방향(`daYunDirection`)·
 * 운한 중첩(`daYunYearOverlap.combo`) — 을 golden 러너가 luck에서 직접 관찰해 회귀로 고정한다.
 * 기준일 2026-07-06(세운 병오). 상문살=년지+2, 조객살=년지+10 자리에 세운 지지(오)가 들면 발동:
 * 진년생→상문, 신년생→조객, 오년생→미발동(네거티브). 기대값은 2026-07-10 실제 엔진 프로브에서 도출.
 */
interface LuckCaseSpec {
  id: string;
  description: string;
  birth: BirthInfo;
  money: Money;
  startup: Startup;
  minDomainCoverage: number;
  maxContradictions: number;
  requiredYearSinsal?: string[];
  forbiddenYearSinsal?: string[];
  daYunDirection?: "forward" | "reverse";
  overlapCombo?: string;
}

function mkLuck(spec: LuckCaseSpec): GoldenCase {
  const base = buildExpectation({
    id: spec.id,
    description: spec.description,
    birth: spec.birth,
    money: spec.money,
    startup: spec.startup,
    maxContradictions: spec.maxContradictions,
    minDomainCoverage: spec.minDomainCoverage,
  });
  return {
    id: spec.id,
    description: spec.description,
    input: { birth: spec.birth, referenceDate: REF, type: "saju", context: {} },
    expect: {
      ...base,
      // 운한 근거가 pack에 실려야 함(운한 교차검증 관찰 지점)
      requiredEvidenceIds: [...CORE_EVIDENCE, "luck.current.summary", "luck.overlap.daeyun_year", "luck.interactions.current"],
      requiredYearSinsal: spec.requiredYearSinsal,
      forbiddenYearSinsal: spec.forbiddenYearSinsal,
      expectDaYunDirection: spec.daYunDirection,
      expectLuckOverlapCombo: spec.overlapCombo,
    },
  };
}

const LUCK_SPECS: LuckCaseSpec[] = [
  { id: "g27-m1988-sangmun", description: "남 1988(진년) · 세운 병오=상문살 발동 + 대운 순행 · 운한 중첩 mixed", birth: { calendarType: "solar", year: 1988, month: 5, day: 5, hour: 14, minute: 0, gender: "male" }, money: "risk", startup: "notrec", minDomainCoverage: 6, maxContradictions: 1, requiredYearSinsal: ["상문살"], forbiddenYearSinsal: ["조객살"], daYunDirection: "forward", overlapCombo: "mixed" },
  { id: "g28-f2000-sangmun-rev", description: "여 2000(진년) · 세운 상문살 + 대운 역행 · 창업 검증우선", birth: { calendarType: "solar", year: 2000, month: 6, day: 10, hour: 9, minute: 0, gender: "female" }, money: "risk", startup: "test", minDomainCoverage: 6, maxContradictions: 1, requiredYearSinsal: ["상문살"], daYunDirection: "reverse" },
  { id: "g29-f1992-jogaek", description: "여 1992(신년) · 세운 병오=조객살 발동 + 대운 역행", birth: { calendarType: "solar", year: 1992, month: 3, day: 20, hour: 7, minute: 0, gender: "female" }, money: "risk", startup: "notrec", minDomainCoverage: 6, maxContradictions: 1, requiredYearSinsal: ["조객살"], forbiddenYearSinsal: ["상문살"], daYunDirection: "reverse" },
  { id: "g30-m1980-jogaek-fwd", description: "남 1980(신년) · 세운 조객살 + 대운 순행", birth: { calendarType: "solar", year: 1980, month: 10, day: 15, hour: 20, minute: 0, gender: "male" }, money: "risk", startup: "notrec", minDomainCoverage: 6, maxContradictions: 1, requiredYearSinsal: ["조객살"], daYunDirection: "forward" },
  { id: "g31-f1990-nosinsal", description: "여 1990(오년, g02 동일 원국) · 세운 상문·조객 미발동 + 운한 중첩 amplify-good — 세운 신살 네거티브 컨트롤", birth: { calendarType: "solar", year: 1990, month: 12, day: 23, hour: 8, minute: 0, gender: "female" }, money: "risk", startup: "notrec", minDomainCoverage: 6, maxContradictions: 1, forbiddenYearSinsal: ["상문살", "조객살"], overlapCombo: "amplify-good" },
];

export const goldenCases: GoldenCase[] = [...SPECS.map(mk), ...DEEP_SPECS.map(mkDeep), ...LUCK_SPECS.map(mkLuck)];
