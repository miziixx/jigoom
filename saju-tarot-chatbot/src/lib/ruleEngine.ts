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

  // ── 4대 고전 심화 판단 (엔진 업그레이드 S-2, docs/engine-upgrade-2026-07.md) ──────────
  // 사건(event) 규칙이 아니라 구조·기질·조후 판단이므로, 위의 GENERAL_MIXED_FLOW 판정
  // ("사건 분야가 조용한가")에는 관여하지 않도록 그 뒤에 덧붙인다.
  rules.push(...deepClassicRules(compactEvidence, evidence));

  return rules;
}

/** 파격 요인 이름 → 주로 흔들리는 현실 도메인 (자평진전 통설 기준, 없으면 personality) */
const FAILURE_DOMAIN: Array<{ match: string; domain: TriggeredRule["domain"] }> = [
  { match: "재다신약", domain: "money" },
  { match: "효신탈식", domain: "money" },
  { match: "상관견관", domain: "career" },
  { match: "정관봉상관", domain: "career" },
  { match: "탐재괴인", domain: "career" },
];

function structureFailureDomain(failures: string[]): TriggeredRule["domain"] {
  for (const failure of failures) {
    const hit = FAILURE_DOMAIN.find((f) => failure.includes(f.match));
    if (hit) return hit.domain;
  }
  return "personality";
}

function deepClassicRules(compactEvidence: CompactEvidence, evidence: EvidenceRef[]): TriggeredRule[] {
  const rules: TriggeredRule[] = [];
  const base = chartLuckEvidence(evidence);

  // 격국 심화 (자평진전): 상신이 갖춰진 성격 → 강점 지지 / 파격 요인 → 보완 조건
  const structure = compactEvidence.structure;
  const structureRefs = findEvidence(evidence, "chart.gyeokguk.classic");
  if (structure && structureRefs.length > 0) {
    // 상신 판정(assessGyeokgukClassic)은 "필요 그룹 중 있는 것"을 고르는 방식이라 est=성격이 매우 흔하다.
    // 변별력을 위해: 이름 있는 성격 패턴·종격·간이 성패(월지 투출)의 성격 경향 중 하나가 더 있고,
    // 간이 성패가 "파격 경향"(월지 충)으로 어긋나지 않을 때만 지지 판단을 낸다.
    const solidExtra = Boolean(structure.pattern || structure.jonggyeok || structure.status === "성격 경향");
    if (structure.established === "성격" && structure.status !== "파격 경향" && solidExtra) {
      const highlight = structure.pattern ?? structure.jonggyeok ?? structure.name;
      const rule = buildRule({
        id: "rule.structure.solid",
        domain: "personality",
        code: "structure.solid",
        evidence: [...structureRefs, ...base].slice(0, 5),
        weight: 0.7,
        result: "support",
        summary: `타고난 구조(${highlight})가 비교적 뚜렷하게 성립하는 편이라, 그 강점 패턴을 살리는 방향이 유리하다.`,
      });
      if (rule) rules.push(rule);
    } else if (structure.established === "파격" || structure.failures.length > 0) {
      const rule = buildRule({
        id: "rule.structure.broken",
        domain: structureFailureDomain(structure.failures),
        code: "structure.broken",
        evidence: [...structureRefs, ...base].slice(0, 5),
        weight: 0.7,
        result: "constraint",
        summary: `타고난 구조에 흔들리는 요인(${structure.failures.join("·") || "상신 미비"})이 있어, 강점을 쓰기 전에 보완 조건을 먼저 본다.`,
      });
      if (rule) rules.push(rule);
    }
  }

  // 조후 심화 (궁통보감): 1순위 조후가 원국에 없으면 컨디션·환경 보완 조건
  const climate = compactEvidence.climateClassic;
  const climateRefs = findEvidence(evidence, "chart.climate.classic");
  if (climate && !climate.satisfied && climateRefs.length > 0) {
    const rule = buildRule({
      id: "rule.climate.unmet",
      domain: "health",
      code: "climate.unmet",
      evidence: [...climateRefs, ...base].slice(0, 5),
      weight: 0.55,
      result: "constraint",
      summary: `궁통보감 기준 1순위 조후 기운(${climate.primaryElement})이 원국에 뚜렷하지 않아, 계절·환경·생활 리듬 보완을 조건으로 본다.`,
    });
    if (rule) rules.push(rule);
  }

  // 십성 편중 (연해자평 지장간 가중 분포): 한 축 점유 50%+ 또는 두 그룹 이상 공백 → 기질 판단
  const profile = compactEvidence.tenGodProfile;
  const profileRefs = findEvidence(evidence, "chart.tengods.profile");
  if (profile && profileRefs.length > 0) {
    const values = Object.values(profile.groups);
    const total = values.reduce((sum, v) => sum + v, 0);
    const maxShare = total > 0 ? Math.max(...values) / total : 0;
    if (total > 0 && (profile.missing.length >= 2 || maxShare >= 0.5)) {
      const skewText =
        maxShare >= 0.5
          ? `${profile.dominant.join("·")} 축에 기운의 절반 이상이 몰려 있고`
          : `${profile.dominant.join("·")} 축이 강하고`;
      const rule = buildRule({
        id: "rule.tengod.skew",
        domain: "personality",
        code: "tengod.skew",
        evidence: [...profileRefs, ...base].slice(0, 5),
        weight: 0.6,
        result: "support",
        summary: `십성 분포가 뚜렷하게 치우침 — ${skewText}, ${profile.missing.join("·") || "없음"} 축이 비어 있다. 강한 축은 살리고 빈 축은 작게 보완하는 전략이 맞다.`,
      });
      if (rule) rules.push(rule);
    }
  }

  return rules;
}
