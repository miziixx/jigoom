import type { ReadingContext, ReadingType } from "../types/index.js";
import type { CompactEvidence } from "./compactEvidence.js";
import { evidenceRefsFromCompactEvidence } from "./evidenceIds.js";
import { scoreConfidence } from "./confidenceEngine.js";
import { detectContradictions } from "./contradictionEngine.js";
import { triggerRules } from "./ruleEngine.js";
import {
  JUDGMENT_SCHEMA_VERSION,
  type AllowedTone,
  type ForbiddenClaim,
  type JudgmentCandidate,
  type JudgmentCode,
  type JudgmentPack,
  type TriggeredRule,
} from "./judgmentTypes.js";

export interface JudgmentEngineInput {
  readingType: ReadingType;
  compactEvidence: CompactEvidence;
  question?: string;
  context?: ReadingContext;
  generatedAt?: string;
}

const GLOBAL_FORBIDDEN: ForbiddenClaim[] = [
  { code: "global.no_determinism", patternHint: "반드시|무조건|100%|절대", reason: "미래 결과를 단정하지 않는다." },
  { code: "global.no_resignation_order", domain: "career", patternHint: "지금 퇴사하세요|회사를 그만두세요", reason: "퇴사 결정은 엔진 판단 범위를 넘어선 고위험 선택이다." },
  { code: "global.no_investment_promise", domain: "money", patternHint: "큰돈을 벌게 됩니다|투자하세요", reason: "수익 보장과 투자 지시는 금지한다." },
  { code: "global.no_marriage_certainty", domain: "love", patternHint: "반드시 결혼합니다|무조건 재회", reason: "결혼·재회·이별을 확정하지 않는다." },
  { code: "global.no_medical_diagnosis", domain: "health", patternHint: "암입니다|질병입니다|병에 걸립니다", reason: "의학적 진단은 하지 않는다." },
];

function domainForbidden(domain: JudgmentCandidate["domain"]): ForbiddenClaim[] {
  const byDomain: Record<JudgmentCandidate["domain"], ForbiddenClaim> = {
    career: { code: "career.no_direct_resignation", domain, patternHint: "지금 퇴사하세요|당장 이직하세요", reason: "직업 판단은 변화 가능성과 준비 조건까지만 말한다." },
    money: { code: "money.no_profit_guarantee", domain, patternHint: "큰돈을 벌게 됩니다|무조건 수익", reason: "재물운은 수익 보장이 아니라 위험·기회 조건으로만 말한다." },
    love: { code: "love.no_certain_marriage", domain, patternHint: "반드시 결혼합니다|무조건 헤어집니다", reason: "관계 결론을 확정하지 않는다." },
    health: { code: "health.no_diagnosis", domain, patternHint: "질병 진단|암입니다|간이 나쁩니다", reason: "건강은 생활 컨디션 관리로 제한한다." },
    startup: { code: "startup.no_must_start", domain, patternHint: "반드시 창업하세요|당장 창업하세요", reason: "창업은 실행 명령이 아니라 조건 검증으로만 다룬다." },
    move: { code: "move.no_forced_move", domain, patternHint: "반드시 이사하세요|당장 옮기세요", reason: "이동은 계약과 현실 조건 확인이 필요하다." },
    family: { code: "family.no_family_fate", domain, patternHint: "가족 때문에 망합니다|가족과 끊으세요", reason: "가족 문제를 공포·단절 명령으로 말하지 않는다." },
    personality: { code: "personality.no_fixed_label", domain, patternHint: "당신은 원래 안 됩니다", reason: "성향을 고정 낙인으로 만들지 않는다." },
    year: { code: "year.no_certain_event", domain, patternHint: "올해 반드시", reason: "세운은 경향으로만 말한다." },
    decision: { code: "decision.no 대신결정", domain, patternHint: "정답은 .*입니다", reason: "사용자의 결정을 대신하지 않는다." },
    general: { code: "general.no_generic_fate", domain, patternHint: "운명이 정해져 있습니다", reason: "운명론적 단정을 피한다." },
  };
  return [byDomain[domain], ...GLOBAL_FORBIDDEN.filter((claim) => claim.domain === domain || !claim.domain)];
}

function allowedTone(rule: TriggeredRule): AllowedTone {
  if (rule.result === "risk" || rule.result === "constraint") {
    return {
      stance: "cautious",
      modality: "must_frame_as_condition",
      wordingHints: ["가능성", "점검", "조건", "준비", "작게 확인"],
    };
  }
  if (rule.weight >= 0.8) {
    return {
      stance: "balanced",
      modality: "should_say",
      wordingHints: ["흐름이 강하다", "다만 반대 근거도 함께 본다", "선택 기준"],
    };
  }
  return {
    stance: "uncertain",
    modality: "must_frame_as_condition",
    wordingHints: ["경향", "가능성", "현재 확인되는 범위"],
  };
}

function codeForRule(rule: TriggeredRule): JudgmentCode {
  switch (rule.id) {
    case "rule.career.change": return "CAREER_CHANGE_HIGH";
    case "rule.money.risk": return "MONEY_RISK_MEDIUM";
    case "rule.money.opportunity": return "MONEY_OPPORTUNITY";
    case "rule.love.stable": return "LOVE_STABLE";
    case "rule.love.delay": return "LOVE_DELAY";
    case "rule.health.caution": return "HEALTH_CAUTION";
    case "rule.startup.not_recommended": return "STARTUP_NOT_RECOMMENDED";
    case "rule.startup.test_first": return "STARTUP_TEST_FIRST";
    case "rule.move.caution": return "MOVE_CAUTION";
    case "rule.family.responsibility": return "FAMILY_RESPONSIBILITY";
    default: return "GENERAL_MIXED_FLOW";
  }
}

const CONCLUSION_BY_CODE: Record<JudgmentCode, string> = {
  CAREER_CHANGE_HIGH: "직업·역할 변화 가능성은 높지만, 실행은 조건 확인 후 단계적으로 다루는 쪽이 안전합니다.",
  CAREER_STABLE_CAUTION: "직업 영역은 큰 확장보다 현재 역할과 부담을 정리하는 쪽이 우선입니다.",
  MONEY_RISK_MEDIUM: "돈과 수익은 기회보다 위험 관리와 고정비 점검을 먼저 둬야 합니다.",
  MONEY_OPPORTUNITY: "재물 흐름에는 살릴 만한 신호가 있으나, 수익 보장처럼 말하면 안 됩니다.",
  LOVE_STABLE: "관계는 큰 사건보다 안정 조건과 생활 리듬을 맞추는 쪽으로 보는 것이 자연스럽습니다.",
  LOVE_DELAY: "연애·관계는 결론을 서두르기보다 속도와 반복 패턴을 먼저 점검해야 합니다.",
  HEALTH_CAUTION: "건강은 질병 판단이 아니라 수면·회복·긴장도 같은 컨디션 관리로 제한해 말해야 합니다.",
  STARTUP_NOT_RECOMMENDED: "창업·독립은 바로 권하기보다 수익 구조와 안전장치를 먼저 확인해야 합니다.",
  STARTUP_TEST_FIRST: "창업·독립 에너지는 있으나 큰 실행보다 작게 검증하는 방식으로만 권할 수 있습니다.",
  MOVE_CAUTION: "이사·이동은 가능성보다 계약 조건과 시기 확인을 붙여 조심스럽게 다뤄야 합니다.",
  FAMILY_RESPONSIBILITY: "가족·집안 문제는 혼자 떠안는 결론보다 역할 분담과 경계 설정 중심으로 봐야 합니다.",
  GENERAL_MIXED_FLOW: "두드러진 사건 결론은 제한하고, 확인된 기질과 현재 흐름 안에서만 조언해야 합니다.",
};

function actionFrame(code: JudgmentCode): JudgmentCandidate["actionFrame"] {
  const common = {
    do: ["현실 조건을 숫자와 일정으로 확인하세요."],
    avoid: ["한 문장 결론으로 인생 결정을 확정하지 마세요."],
    checkSignals: ["최근 1~3개월의 실제 변화가 계산 신호와 맞는지 확인하세요."],
  };
  switch (code) {
    case "CAREER_CHANGE_HIGH":
      return {
        do: ["현재 역할에서 바뀌는 업무·상사·팀 구조를 기록하세요.", "이직·퇴사 전 고정비와 준비 기간을 먼저 계산하세요."],
        avoid: ["즉시 퇴사나 무계획 독립으로 번역하지 마세요."],
        checkSignals: ["역할 변경 제안", "조직 개편", "반복되는 번아웃 신호"],
      };
    case "MONEY_RISK_MEDIUM":
      return {
        do: ["고정비, 빌려준 돈, 동업·투자 노출을 먼저 점검하세요."],
        avoid: ["큰 수익 보장이나 공격적 투자 조언을 하지 마세요."],
        checkSignals: ["예상 밖 지출", "수익 변동", "동업·대여 요청"],
      };
    case "STARTUP_NOT_RECOMMENDED":
      return {
        do: ["작은 유료 테스트와 3개월 버틸 현금 흐름을 먼저 확인하세요."],
        avoid: ["바로 창업하라는 결론을 내지 마세요."],
        checkSignals: ["반복 구매", "고정 고객", "손익분기 가능성"],
      };
    case "HEALTH_CAUTION":
      return {
        do: ["수면, 식사, 긴장도, 회복 시간을 생활 체크리스트로 보세요."],
        avoid: ["질병명이나 진단처럼 말하지 마세요."],
        checkSignals: ["수면 질", "소화 리듬", "피로 회복 속도"],
      };
    default:
      return common;
  }
}

function uncertainty(overall: number, counterCount: number): JudgmentCandidate["uncertainty"] {
  if (overall < 55 || counterCount >= 2) return { level: "high", reasons: ["확신 점수가 낮거나 반대 근거가 있습니다."] };
  if (overall < 70 || counterCount === 1) return { level: "medium", reasons: ["일부 반대 근거 또는 제한 조건이 있습니다."] };
  return { level: "low", reasons: ["주요 계산 근거가 같은 방향입니다."] };
}

function judgmentFromRule(rule: TriggeredRule, index: number, context?: ReadingContext): JudgmentCandidate {
  const code = codeForRule(rule);
  const confidence = scoreConfidence(rule, context ? 8 : 0);
  return {
    id: `judgment.${index + 1}.${code.toLowerCase()}`,
    code,
    domain: rule.domain,
    kind: rule.result === "risk" || rule.result === "constraint" ? "caution" : code.includes("STARTUP") ? "strategy" : "timing",
    plainConclusion: CONCLUSION_BY_CODE[code],
    evidence: rule.evidence,
    counterEvidence: rule.counterEvidence,
    confidence,
    allowedTone: allowedTone(rule),
    forbiddenClaims: domainForbidden(rule.domain),
    triggeredRuleIds: [rule.id],
    actionFrame: actionFrame(code),
    uncertainty: uncertainty(confidence.overall, rule.counterEvidence.length),
  };
}

export function buildJudgmentPack(input: JudgmentEngineInput): JudgmentPack {
  const evidence = evidenceRefsFromCompactEvidence(input.compactEvidence);
  const triggeredRules = triggerRules({
    readingType: input.readingType,
    compactEvidence: input.compactEvidence,
    evidence,
    question: input.question,
    context: input.context,
  });
  const judgments = triggeredRules.map((rule, index) => judgmentFromRule(rule, index, input.context));
  const contradictions = detectContradictions(judgments);
  const decisionTrace = [
    { stage: "evidence" as const, refId: "evidence.compact", summary: `${evidence.length}개 근거 객체 생성` },
    { stage: "rule" as const, refId: "rules.triggered", summary: `${triggeredRules.length}개 Rule 발동` },
    { stage: "judgment" as const, refId: "judgments.generated", summary: `${judgments.length}개 JudgmentCandidate 생성` },
    { stage: "confidence" as const, refId: "confidence.scored", summary: "chart/luck/event/context/overall 확신도 산정" },
    { stage: "contradiction" as const, refId: "contradictions.detected", summary: `${contradictions.length}개 모순 또는 긴장 탐지` },
  ];
  return {
    schemaVersion: JUDGMENT_SCHEMA_VERSION,
    readingType: input.readingType,
    generatedAt: input.generatedAt ?? new Date().toISOString(),
    evidence,
    triggeredRules,
    judgments,
    contradictions,
    globalForbiddenClaims: GLOBAL_FORBIDDEN,
    decisionTrace,
    audit: {
      schemaVersion: JUDGMENT_SCHEMA_VERSION,
      evidenceIds: evidence.map((ref) => ref.id),
      ruleIds: triggeredRules.map((rule) => rule.id),
      judgmentIds: judgments.map((judgment) => judgment.id),
    },
  };
}
