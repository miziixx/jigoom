import type { ReadingContext, ReadingType } from "../types/index.js";
import type { CompactDomainScore, CompactEvidence } from "./compactEvidence.js";
import type { EvidenceRef, RuleId, TriggeredRule } from "./judgmentTypes.js";

export interface RuleEngineInput {
  readingType: ReadingType;
  compactEvidence: CompactEvidence;
  evidence: EvidenceRef[];
  question?: string;
  context?: ReadingContext;
}

function findEvidence(evidence: EvidenceRef[], idPrefix: string): EvidenceRef[] {
  return evidence.filter((ref) => ref.id.startsWith(idPrefix));
}

function domainEvidence(evidence: EvidenceRef[], domain: string): EvidenceRef[] {
  return findEvidence(evidence, `event.${domain}.`);
}

function chartLuckEvidence(evidence: EvidenceRef[]): EvidenceRef[] {
  return evidence.filter((ref) => ref.source === "chart" || ref.source === "luck").slice(0, 4);
}

function riskEvidence(evidence: EvidenceRef[], domain?: string): EvidenceRef[] {
  return evidence.filter((ref) => {
    if (domain && !ref.id.includes(`.${domain}.`)) return false;
    return ref.direction === "risk" || ref.direction === "constraint";
  });
}

function domain(compact: CompactEvidence, key: string): CompactDomainScore | undefined {
  return compact.domainScores.find((score) => score.domain === key);
}

function buildRule(params: {
  id: RuleId;
  domain: TriggeredRule["domain"];
  code: string;
  evidence: EvidenceRef[];
  counterEvidence?: EvidenceRef[];
  weight: number;
  result: TriggeredRule["result"];
  summary: string;
}): TriggeredRule | null {
  const evidence = params.evidence.filter(Boolean);
  if (evidence.length === 0) return null;
  return {
    id: params.id,
    domain: params.domain,
    code: params.code,
    evidence,
    counterEvidence: params.counterEvidence ?? [],
    weight: params.weight,
    result: params.result,
    summary: params.summary,
  };
}

function mentions(text: string, words: string[]): boolean {
  return words.some((word) => text.includes(word));
}

export function triggerRules(input: RuleEngineInput): TriggeredRule[] {
  const { compactEvidence, evidence, question = "", context } = input;
  const rules: TriggeredRule[] = [];
  const query = [question, context?.concernArea, context?.optionsText, context?.recentContext].filter(Boolean).join(" ");
  const base = chartLuckEvidence(evidence);

  const career = domain(compactEvidence, "career");
  if (career && (career.activation === "high" || career.activationScore >= 65)) {
    const rule = buildRule({
      id: "rule.career.change",
      domain: "career",
      code: "career.change",
      evidence: [...domainEvidence(evidence, "career"), ...base].slice(0, 6),
      counterEvidence: riskEvidence(evidence, "money").slice(0, 2),
      weight: career.activation === "high" ? 0.9 : 0.75,
      result: "support",
      summary: "직업·역할 영역이 강하게 활성화되어 변화 가능성은 높게 본다.",
    });
    if (rule) rules.push(rule);
  }

  const money = domain(compactEvidence, "money");
  if (money && (money.risk >= 45 || money.balance === "caution")) {
    const rule = buildRule({
      id: "rule.money.risk",
      domain: "money",
      code: "money.risk",
      evidence: [...domainEvidence(evidence, "money"), ...base].slice(0, 6),
      counterEvidence: money.benefit >= 35 ? domainEvidence(evidence, "money").filter((ref) => ref.direction === "support").slice(0, 2) : [],
      weight: money.risk >= 65 ? 0.9 : 0.7,
      result: "risk",
      summary: "재물·수익 영역은 기회보다 손실 관리와 고정비 점검을 먼저 둔다.",
    });
    if (rule) rules.push(rule);
  } else if (money && money.balance === "opportunity" && money.benefit >= 45) {
    const rule = buildRule({
      id: "rule.money.opportunity",
      domain: "money",
      code: "money.opportunity",
      evidence: [...domainEvidence(evidence, "money"), ...base].slice(0, 6),
      counterEvidence: riskEvidence(evidence, "money").slice(0, 2),
      weight: 0.7,
      result: "support",
      summary: "재물·성과 흐름은 살릴 만한 신호가 있으나 단정 수익으로 말하지 않는다.",
    });
    if (rule) rules.push(rule);
  }

  const love = domain(compactEvidence, "love");
  if (love && love.activation === "low" && love.balance === "calm") {
    const rule = buildRule({
      id: "rule.love.stable",
      domain: "love",
      code: "love.stable",
      evidence: [...domainEvidence(evidence, "love"), ...base].slice(0, 5),
      weight: 0.55,
      result: "support",
      summary: "관계 영역은 큰 흔들림보다 생활 리듬과 안정 조건을 보는 쪽이 맞다.",
    });
    if (rule) rules.push(rule);
  } else if (love && (love.balance === "caution" || love.risk >= 45)) {
    const rule = buildRule({
      id: "rule.love.delay",
      domain: "love",
      code: "love.delay",
      evidence: [...domainEvidence(evidence, "love"), ...base].slice(0, 5),
      counterEvidence: love.benefit >= 35 ? domainEvidence(evidence, "love").filter((ref) => ref.direction === "support").slice(0, 2) : [],
      weight: 0.7,
      result: "risk",
      summary: "관계는 결론을 서두르기보다 반복 패턴과 속도 조절을 먼저 본다.",
    });
    if (rule) rules.push(rule);
  }

  const health = domain(compactEvidence, "health");
  if (health && (health.risk >= 35 || health.balance === "caution" || compactEvidence.riskFlags.length > 0)) {
    const rule = buildRule({
      id: "rule.health.caution",
      domain: "health",
      code: "health.caution",
      evidence: [...domainEvidence(evidence, "health"), ...riskEvidence(evidence), ...base].slice(0, 7),
      weight: health.risk >= 55 ? 0.75 : 0.6,
      result: "constraint",
      summary: "건강은 질병 판단이 아니라 컨디션·회복 리듬 점검으로 제한한다.",
    });
    if (rule) rules.push(rule);
  }

  const startup = domain(compactEvidence, "startup");
  const startupAsked = mentions(query, ["창업", "독립", "프리랜서", "퇴사"]);
  if (startup && (startup.balance === "caution" || startup.risk >= 45 || (startupAsked && money && money.risk >= 45))) {
    const rule = buildRule({
      id: "rule.startup.not_recommended",
      domain: "startup",
      code: "startup.not_recommended",
      evidence: [...domainEvidence(evidence, "startup"), ...domainEvidence(evidence, "money"), ...base].slice(0, 7),
      counterEvidence: startup.benefit >= 40 ? domainEvidence(evidence, "startup").filter((ref) => ref.direction === "support").slice(0, 2) : [],
      weight: startup.risk >= 60 || (money?.risk ?? 0) >= 60 ? 0.85 : 0.7,
      result: "risk",
      summary: "창업·독립은 바로 권하기보다 수익 구조와 안전장치 확인이 먼저다.",
    });
    if (rule) rules.push(rule);
  } else if (startup && startup.activation !== "low" && startup.balance !== "caution") {
    const rule = buildRule({
      id: "rule.startup.test_first",
      domain: "startup",
      code: "startup.test_first",
      evidence: [...domainEvidence(evidence, "startup"), ...base].slice(0, 6),
      counterEvidence: riskEvidence(evidence, "money").slice(0, 2),
      weight: 0.65,
      result: "support",
      summary: "창업·독립 에너지는 있으나 작게 검증하는 전략으로만 말한다.",
    });
    if (rule) rules.push(rule);
  }

  const move = domain(compactEvidence, "move");
  if (move && (move.activation !== "low" || move.risk >= 35)) {
    const rule = buildRule({
      id: "rule.move.caution",
      domain: "move",
      code: "move.caution",
      evidence: [...domainEvidence(evidence, "move"), ...base].slice(0, 6),
      weight: move.risk >= 45 ? 0.7 : 0.55,
      result: move.risk >= 45 ? "risk" : "support",
      summary: "이동·환경 변화는 계약 조건과 시기 확인을 붙여 조심스럽게 다룬다.",
    });
    if (rule) rules.push(rule);
  }

  const family = domain(compactEvidence, "family");
  if (family && (family.activation !== "low" || family.risk >= 35)) {
    const rule = buildRule({
      id: "rule.family.responsibility",
      domain: "family",
      code: "family.responsibility",
      evidence: [...domainEvidence(evidence, "family"), ...base].slice(0, 6),
      weight: family.risk >= 45 ? 0.7 : 0.55,
      result: family.risk >= 45 ? "risk" : "support",
      summary: "가족·집안 이슈는 역할 분담과 경계 설정 중심으로 말한다.",
    });
    if (rule) rules.push(rule);
  }

  if (rules.length === 0 && compactEvidence.topFindings.length > 0) {
    const rule = buildRule({
      id: "rule.general.mixed_flow",
      domain: "general",
      code: "general.mixed_flow",
      evidence: evidence.slice(0, 5),
      weight: 0.45,
      result: "support",
      summary: "두드러진 사건 분야가 약하므로 전체 기질과 평이한 흐름 중심으로 제한한다.",
    });
    if (rule) rules.push(rule);
  }

  return rules;
}
