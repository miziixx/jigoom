// 자기 완전분석(selfDeep) 조립 헬퍼.
//
// 원칙: 새 결정론 계산을 만들지 않는다. 이미 계산된 심리 엔진(psychLayer/capacityAxis)과
// 신뢰 신호(출생시간 정확도·교차검증·과거검증)를 "묶어서 표면화"하기만 한다.
// - deriveShadow: 강점 과잉/재료-출력 간극/방어에서 그림자·결핍 블록을 규칙 파생.
// - buildConfidenceTiers: 분야별 확실/추정/확인 필요 3분류.
// - buildSelfDeepEvidence: 위 둘을 프롬프트 근거 블록 + 활용 안내로 직렬화.
//
// 진단명(애착유형·번아웃 등) 금지, "장점이 과해지면 ~" 톤. 표면 문장에 사주 용어 금지.

import type {
  BirthTimeAccuracy,
  CrossValidationReport,
  PastValidationReport,
  ReadingContext,
  SajuChart,
} from "../types/index.js";
import { buildCapacityAxes, type GroupCapacity } from "./capacityAxis.js";
import { buildPsychLayer, type PsychLayer } from "./psychLayer.js";

// ── 그림자·결핍·방어 ──────────

export interface ShadowInsight {
  /** 무료 티저용 한 줄 */
  headline: string;
  /** 유료 완전분석용 전체 줄 (표면 노출 가능한 생활어) */
  lines: string[];
  /** 전문가 근거용 (표면 노출 금지) */
  evidence: string[];
}

/**
 * 그림자·결핍·방어 블록을 기존 신호에서 파생한다.
 * - capacityAxis: 재료는 넉넉한데(강) 출력이 약한(약) 기질 → "장점이 과해지면" 그림자.
 * - psychLayer: 눌릴 때 나오는 방어 + 반복 병목 → 결핍·방어 결.
 * 새 엔진 없음. psych/axes가 없으면 null.
 */
export function deriveShadow(psych: PsychLayer | null, axes: GroupCapacity[] | null): ShadowInsight | null {
  if (!psych && (!axes || axes.length === 0)) return null;

  const lines: string[] = [];
  const evidence: string[] = [];

  // 1) 재료 강·출력 약 = 마음은 앞서는데 실제로 못 쓰는 지점 → 결핍이 자라기 쉬운 자리.
  const stuck = (axes ?? []).filter((a) => a.material === "강" && a.output === "약");
  for (const a of stuck.slice(0, 2)) {
    lines.push(
      `${a.trait}은(는) 타고나길 넉넉한데 실제로 밀어붙일 힘이 약해, 여기서 "하고 싶은데 안 된다"는 답답함이 반복되기 쉽습니다. 그 답답함이 쌓이면 스스로를 몰아세우거나 아예 손을 놓는 쪽으로 갈 수 있습니다.`,
    );
    evidence.push(`재료 강·출력 약: ${a.evidence}`);
  }

  // 2) 지배 기질이 과해질 때의 그림자(강점의 그림자). psych.defense/repeatedPattern에서.
  if (psych) {
    lines.push(
      `평소 강점인 결이 과해지면 ${psych.defense} 이 방식이 오래가면 정작 원하는 걸 말 못 하고 속으로만 삭이는 결핍으로 남기 쉽습니다.`,
    );
    lines.push(`특히 눌릴 때 반복되는 지점은 이것입니다: ${psych.repeatedPattern}`);
    evidence.push(...psych.evidence);
  }

  if (lines.length === 0) return null;

  const headline = stuck.length > 0
    ? `${stuck[0].trait}에서 "마음은 앞서는데 힘이 안 붙는" 간극이 반복되기 쉬운 편입니다.`
    : `강점이 과해질 때 스스로를 몰아세우는 결이 있습니다.`;

  return { headline, lines, evidence };
}

// ── 확실 / 추정 / 확인 필요 ──────────

export type ConfidenceTier = "확실" | "추정" | "확인 필요";

export interface ConfidenceTierItem {
  /** 분야 라벨 (성격·기질 / 관계 / 일·돈 / 시기·선택 / 건강) */
  area: string;
  tier: ConfidenceTier;
  /** 왜 그 등급인지 한 줄 (생활어) */
  reason: string;
}

export interface ConfidenceTiers {
  /** 전체 한 줄 요약 (무료 티저용) */
  summary: string;
  items: ConfidenceTierItem[];
}

export interface ConfidenceTiersInput {
  chart?: SajuChart | null;
  hasLuck?: boolean;
  timeAccuracy?: BirthTimeAccuracy;
  crossValidation?: CrossValidationReport | null;
  pastValidation?: PastValidationReport | null;
}

const AREA_CAREER = "일·돈";
const AREA_LOVE = "관계";
const AREA_HEALTH = "건강";
const AREA_TIMING = "시기·선택";
const AREA_TEMPER = "성격·기질";

/** 교차검증 domain → 분야 라벨. (crossValidation은 문자열 domain을 쓴다) */
function crossDomainToArea(domain: string): string | null {
  if (domain.includes("career") || domain.includes("직업") || domain.includes("money") || domain.includes("재물") || domain.includes("돈")) return AREA_CAREER;
  if (domain.includes("love") || domain.includes("연애") || domain.includes("관계")) return AREA_LOVE;
  if (domain.includes("health") || domain.includes("건강")) return AREA_HEALTH;
  return null;
}

/** 과거검증 신뢰 분야(LifeDomain) → 분야 라벨. */
function pastDomainToArea(domain: string): string | null {
  if (domain === "career" || domain === "money" || domain === "startup") return AREA_CAREER;
  if (domain === "love") return AREA_LOVE;
  if (domain === "health") return AREA_HEALTH;
  return null;
}

/**
 * 분야별 확실/추정/확인 필요 3분류.
 * 새 계산 없이 기존 신뢰 신호만 취합한다:
 * - 원국·운 계산이 있으면 base "추정", 없으면 "확인 필요".
 * - 출생시간 오차: 시간에 민감한 성격·기질/시기·선택을 한 단계 낮춘다.
 * - 교차검증(사주×자미두수): 강일치 → 확실, 불일치 → 확인 필요.
 * - 과거검증: 실제 부합한 분야(reliableDomains) → 확실.
 */
export function buildConfidenceTiers(input: ConfidenceTiersInput): ConfidenceTiers | null {
  if (!input.chart) return null;

  const timeUncertain = input.timeAccuracy !== undefined && input.timeAccuracy !== "exact";
  const base: ConfidenceTier = "추정";

  const items: Record<string, ConfidenceTierItem> = {
    [AREA_TEMPER]: { area: AREA_TEMPER, tier: base, reason: "타고난 결은 원국 계산으로 뚜렷하게 나오는 편입니다." },
    [AREA_LOVE]: { area: AREA_LOVE, tier: base, reason: "관계 성향은 계산값이 있지만 실제 상대·상황에 따라 갈립니다." },
    [AREA_CAREER]: { area: AREA_CAREER, tier: base, reason: "일·돈의 결은 계산값이 있으나 선택과 환경 영향이 큽니다." },
    [AREA_TIMING]: { area: AREA_TIMING, tier: input.hasLuck ? base : "확인 필요", reason: input.hasLuck ? "운 흐름 계산이 있어 시기 판단의 방향은 잡힙니다." : "운 흐름 계산이 부족해 시기는 더 확인이 필요합니다." },
    [AREA_HEALTH]: { area: AREA_HEALTH, tier: base, reason: "건강은 진단이 아니라 생활 리듬 경향으로만 봅니다." },
  };

  // 성격·기질은 원국 계산이 뚜렷하면 확실로 올린다(강약 라벨 존재 = 계산이 섰다는 신호).
  if (input.chart.strength?.label) items[AREA_TEMPER].tier = "확실";

  // 출생시간 오차 → 시간에 민감한 축을 낮춘다.
  if (timeUncertain) {
    items[AREA_TEMPER].tier = "추정";
    items[AREA_TEMPER].reason = "출생 시간에 오차 가능성이 있어 세부 성향은 달라질 수 있습니다.";
    items[AREA_TIMING].tier = "확인 필요";
    items[AREA_TIMING].reason = "출생 시간 오차로 시기·선택 판단은 더 조심스럽게 봐야 합니다.";
  }

  // 교차검증 반영.
  for (const m of input.crossValidation?.matches ?? []) {
    const area = crossDomainToArea(m.domain) ?? crossDomainToArea(m.label);
    if (!area || !items[area]) continue;
    if (m.level === "강일치") {
      items[area].tier = "확실";
      items[area].reason = "사주와 자미두수가 같은 방향이라 더 또렷하게 볼 수 있습니다.";
    } else if (m.level === "불일치") {
      items[area].tier = "확인 필요";
      items[area].reason = "두 방식이 갈려서 이 분야는 단정하기 어렵습니다.";
    }
  }

  // 과거검증에서 실제 부합한 분야는 확실로.
  for (const domain of input.pastValidation?.reliableDomains ?? []) {
    const area = pastDomainToArea(domain);
    if (!area || !items[area]) continue;
    items[area].tier = "확실";
    items[area].reason = "실제 겪은 과거 일과 계산 흐름이 잘 맞아 더 믿고 볼 수 있습니다.";
  }

  const list = Object.values(items);
  const sure = list.filter((i) => i.tier === "확실").length;
  const check = list.filter((i) => i.tier === "확인 필요").length;
  const summary = `확실 ${sure} · 추정 ${list.length - sure - check} · 확인 필요 ${check} (분야별로 신뢰 세기를 나눠서 봅니다)`;

  return { summary, items: list };
}

// ── 프롬프트 근거 직렬화 ──────────

export interface SelfDeepEvidenceInput {
  chart?: SajuChart | null;
  hasLuck?: boolean;
  context?: ReadingContext;
  crossValidation?: CrossValidationReport | null;
  pastValidation?: PastValidationReport | null;
}

/**
 * 자기 완전분석 전용 근거 블록 + 활용 안내를 만든다.
 * 여기서 새로 더하는 건 그림자·결핍 블록과 확실/추정/확인 필요 티어뿐이다
 * (psych/axes/nowMind/eventForecast/lifestyle/원국/운은 기존 배선이 이미 프롬프트에 싣는다).
 */
export function buildSelfDeepEvidence(input: SelfDeepEvidenceInput): { evidence: string; instruction: string } | null {
  if (!input.chart) return null;

  const psych = buildPsychLayer(input.chart);
  const axes = buildCapacityAxes(input.chart);
  const shadow = deriveShadow(psych, axes);
  const tiers = buildConfidenceTiers({
    chart: input.chart,
    hasLuck: input.hasLuck,
    timeAccuracy: input.context?.timeAccuracy,
    crossValidation: input.crossValidation,
    pastValidation: input.pastValidation,
  });

  const blocks: string[] = [];

  if (shadow) {
    const shadowLines = [
      "▸ 그림자·결핍·방어 (강점 과잉·재료-출력 간극에서 규칙 파생)",
      ...shadow.lines.map((l) => `- ${l}`),
      `(근거) ${shadow.evidence.join("; ")}`,
    ];
    blocks.push(shadowLines.join("\n"));
  }

  if (tiers) {
    const tierLines = [
      "▸ 분야별 신뢰도 (확실 / 추정 / 확인 필요)",
      ...tiers.items.map((i) => `- ${i.area}: ${i.tier} — ${i.reason}`),
    ];
    blocks.push(tierLines.join("\n"));
  }

  if (blocks.length === 0) return null;

  const evidence = `[자기 완전분석 — 그림자·신뢰도 — 계산됨]\n${blocks.join("\n\n")}`;
  const instruction =
    "[자기 완전분석 근거 활용 안내] 위 '그림자·결핍·방어'는 이 사람의 강점이 과해질 때 생기는 " +
    "결핍을 규칙으로 파생한 것이다. '# 그림자·결핍·방어' 섹션에서 반드시 이 근거로 쓰되, 진단명(애착유형·번아웃·회피형 등)을 " +
    "쓰지 말고 \"장점이 과해지면 ~\" 톤의 생활어로만 옮겨라. 남에게도 맞는 뻔한 말 금지 — 이 사람만의 재료-출력 간극을 콕 짚어라. " +
    "위 '분야별 신뢰도'는 '# 확실 / 추정 / 확인 필요' 섹션에서 그대로 분류해 보여주되, '확인 필요'는 공포가 아니라 " +
    "\"이 부분은 더 확인하면 좋다\"는 담담한 태도로 옮기고, 사주 용어(교차검증·자미두수 별·궁 등)는 표면에 쓰지 마라.";

  return { evidence, instruction };
}
