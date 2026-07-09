// 상대 완전분석(personDeep) 조립 헬퍼.
//
// 원칙(Phase 1 selfDeep과 동일): 새 결정론 계산·분류기 엔진을 만들지 않는다.
// 이미 계산된 심리 엔진을 "상대 원국(chartB)"에 적용해 나온 신호(psychLayer/capacityAxis)와
// roleChemistry(A,B)를 규칙으로 파생해 "상대 작동방식"으로 표면화하기만 한다.
// - computePersonProfile: 좋아할 때/불안할 때/거절/질투/미련·식을 때 + 끌리는 지점/부담 지점 + 말·행동 불일치.
// - buildPersonDeepEvidence: 위를 프롬프트 근거 블록 + 활용 안내로 직렬화(+타로 주입 자리).
//
// 진단명 금지, 궁합 "점수" 환원 금지, 표면 문장에 사주 용어 금지.

import type {
  BirthTimeAccuracy,
  CompatibilityRelationType,
  PartnerBehaviorCheck,
  SajuChart,
} from "../types/index.js";
import { buildCapacityAxes } from "./capacityAxis.js";
import { buildPsychLayer } from "./psychLayer.js";
import { roleChemistry } from "./saju.js";
import { buildConfidenceTiers, deriveShadow, type ConfidenceTiers } from "./selfDeep.js";

// ── 상대 작동방식 taxonomy ──────────

export interface PersonBehaviorItem {
  /** 상황 라벨: 좋아할 때 / 불안할 때 / 거절할 때 / 질투할 때 / 미련·식을 때 */
  situation: string;
  /** 이 사람만의 생활어 서술 */
  behavior: string;
}

export interface PersonProfile {
  /** 무료 티저용 한 줄 (나에게 끌리는 지점) */
  attractionHeadline: string;
  /** 좋아할 때/불안할 때/거절/질투/미련·식을 때 */
  taxonomy: PersonBehaviorItem[];
  /** 나에게 끌리는 지점 */
  attraction: string[];
  /** 부담을 느끼는 지점 */
  burden: string[];
  /** 말과 행동 불일치 해석 (겉과 속이 다를 때만, 아니면 null) */
  mismatch: string | null;
  /** 전문가 근거용 (표면 노출 금지) */
  evidence: string[];
}

/**
 * 상대 작동방식을 기존 신호에서 파생한다.
 * - buildPsychLayer(chartB): coreDesire/attachment/defense/stressPattern/recognitionDecision/
 *   repeatedPattern/outerInner → 상황별 행동.
 * - roleChemistry(chartA, chartB): 상대가 나를 어떻게 느끼는지 → 끌리는 지점/부담 지점.
 * - deriveShadow(chartB): 부담 지점 보강.
 * 새 엔진 없음. 상대 원국이 없으면 null.
 */
export function computePersonProfile(
  chartB?: SajuChart | null,
  chartA?: SajuChart | null,
  _relationType?: CompatibilityRelationType,
): PersonProfile | null {
  if (!chartB) return null;

  const psych = buildPsychLayer(chartB);
  const axes = buildCapacityAxes(chartB);
  if (!psych) return null;

  const taxonomy: PersonBehaviorItem[] = [
    {
      situation: "좋아할 때",
      behavior: `이 사람이 마음을 여는 방식은 이렇습니다. ${psych.coreDesire} 가까워졌다고 느끼면, ${psych.attachment}`,
    },
    {
      situation: "불안할 때",
      behavior: `눌리거나 불안해지면 이렇게 반응합니다. ${psych.defense} 그 상태가 길어지면, ${psych.stressPattern}`,
    },
    {
      situation: "거절할 때",
      behavior: `거절하거나 선을 그을 때도 정면으로 부딪히기보다 이런 결로 드러나기 쉽습니다. ${psych.defense}`,
    },
    {
      situation: "질투할 때",
      behavior: `인정받고 싶은 지점이 흔들린다고 느끼면 예민해지고, 그게 질투나 확인 욕구로 새어 나오기 쉽습니다. (인정 지점: ${psych.recognitionDecision})`,
    },
    {
      situation: "미련·식을 때",
      behavior: `관계에서 이 사람이 반복해서 막히는 지점이 미련을 두거나 반대로 식는 방식으로도 나타납니다. ${psych.repeatedPattern}`,
    },
  ];

  // 나에게 끌리는 지점 / 부담 지점: roleChemistry(상대가 느끼는 나) + 상대 출력축.
  const attraction: string[] = [];
  const burden: string[] = [];
  const evidence: string[] = [...psych.evidence];

  if (chartA) {
    const chem = roleChemistry(chartA, chartB) ?? [];
    // chem[1] = "상대가 느끼는 나"
    const bSeesA = chem[1];
    if (bSeesA?.body) {
      attraction.push(`상대 입장에서 당신은 이렇게 다가옵니다: ${bSeesA.body} 여기서 끌리는 지점이 생깁니다.`);
      if (bSeesA.evidence) evidence.push(bSeesA.evidence);
    }
  }

  // 상대가 넉넉히 내주는 출력(강) = 끌리는 매력, 재료 강·출력 약 간극 = 부담이 자라는 자리.
  for (const a of axes ?? []) {
    if (a.output === "강" && attraction.length < 2) {
      attraction.push(`${a.trait}을(를) 자연스럽게 밖으로 내주는 편이라, 이 점이 상대의 매력으로 느껴지기 쉽습니다.`);
      evidence.push(`출력 강: ${a.evidence}`);
    }
    if (a.material === "강" && a.output === "약" && burden.length < 2) {
      burden.push(`${a.trait}은(는) 마음은 큰데 실제로 꺼내 쓰는 힘이 약해, "말은 하는데 움직이지 않는다"는 답답함이 관계에서 부담으로 쌓이기 쉽습니다.`);
      evidence.push(`재료 강·출력 약: ${a.evidence}`);
    }
  }

  // 부담 지점 보강: 강점 과잉의 그림자.
  const shadow = deriveShadow(psych, axes);
  if (shadow && burden.length < 2) {
    burden.push(shadow.headline);
    evidence.push(...shadow.evidence);
  }

  // 말과 행동 불일치: 겉(천간)과 속(지지)이 다를 때만.
  const mismatch = psych.outerInner
    ? `겉으로 보이는 모습과 속마음이 다를 수 있습니다: ${psych.outerInner} 그래서 말과 행동이 어긋나 보이는 순간이 생기니, 말보다 반복되는 행동을 기준으로 보는 편이 정확합니다.`
    : null;

  const attractionHeadline = attraction[0] ?? `상대는 ${psych.coreDesire} 쪽에서 마음이 움직이는 편입니다.`;

  return { attractionHeadline, taxonomy, attraction, burden, mismatch, evidence };
}

// ── 프롬프트 근거 직렬화 ──────────

export interface PersonDeepEvidenceInput {
  chartB?: SajuChart | null;
  chartA?: SajuChart | null;
  relationType?: CompatibilityRelationType;
  hasLuck?: boolean;
  timeAccuracy?: BirthTimeAccuracy;
  partnerCheck?: PartnerBehaviorCheck;
  /** (v1 스캐폴딩) 상대 현재 심리용 타로 뽑기 결과. 아직 UI 미노출, 있으면 근거로 실음. */
  tarotNote?: string | null;
}

const PARTNER_CHECK_LABELS: Array<[keyof PartnerBehaviorCheck, string]> = [
  ["whoContacts", "연락 먼저"],
  ["onlineOfflineGap", "만남vs카톡 태도차"],
  ["makesPlans", "약속 먼저 잡음"],
  ["wordsMatchActions", "말·행동 일치"],
  ["publicness", "관계 공개"],
  ["knownDuration", "알게 된 기간"],
  ["recentMood", "최근 분위기"],
];

function formatPartnerCheck(check?: PartnerBehaviorCheck): string | null {
  if (!check) return null;
  const lines = PARTNER_CHECK_LABELS.filter(([k]) => check[k]?.trim()).map(([k, label]) => `- ${label}: ${check[k]!.trim()}`);
  return lines.length > 0 ? `[상대 행동 체크 — 사용자 입력]\n${lines.join("\n")}` : null;
}

/** 상대 완전분석 신뢰도 티어: 상대 원국 기준 + 행동체크 데이터 유무로 관계 분야 보정. */
function buildPartnerConfidenceTiers(input: PersonDeepEvidenceInput): ConfidenceTiers | null {
  const tiers = buildConfidenceTiers({
    chart: input.chartB,
    hasLuck: input.hasLuck,
    timeAccuracy: input.timeAccuracy,
  });
  if (!tiers) return null;
  const hasBehavior = PARTNER_CHECK_LABELS.some(([k]) => input.partnerCheck?.[k]?.trim());
  if (hasBehavior) {
    const rel = tiers.items.find((i) => i.area === "관계");
    if (rel && rel.tier === "추정") {
      rel.tier = "확실";
      rel.reason = "실제 행동 체크가 있어 관계에서 나타나는 모습은 더 또렷하게 볼 수 있습니다.";
    }
  }
  return tiers;
}

/**
 * 상대 완전분석 전용 근거 블록 + 활용 안내를 만든다(클라이언트 조립, P2).
 * CompatibilityPage가 A·B를 모두 가지므로 여기서 조립해 context.counterpart로 넘긴다.
 */
export function buildPersonDeepEvidence(input: PersonDeepEvidenceInput): { evidence: string; instruction: string } | null {
  if (!input.chartB) return null;

  const profile = computePersonProfile(input.chartB, input.chartA, input.relationType);
  if (!profile) return null;

  const tiers = buildPartnerConfidenceTiers(input);
  const partnerCheck = formatPartnerCheck(input.partnerCheck);

  const blocks: string[] = [];

  const taxonomyLines = [
    "▸ 상대 작동방식 (상대 원국 심리 신호에서 규칙 파생)",
    ...profile.taxonomy.map((t) => `- ${t.situation}: ${t.behavior}`),
  ];
  blocks.push(taxonomyLines.join("\n"));

  if (profile.attraction.length > 0 || profile.burden.length > 0) {
    const pull = [
      "▸ 끌리는 지점 / 부담 지점",
      ...profile.attraction.map((l) => `- (끌림) ${l}`),
      ...profile.burden.map((l) => `- (부담) ${l}`),
    ];
    blocks.push(pull.join("\n"));
  }

  if (profile.mismatch) {
    blocks.push(`▸ 말과 행동 불일치\n- ${profile.mismatch}`);
  }

  if (tiers) {
    const tierLines = [
      "▸ 분야별 신뢰도 (확실 / 추정 / 확인 필요)",
      ...tiers.items.map((i) => `- ${i.area}: ${i.tier} — ${i.reason}`),
    ];
    blocks.push(tierLines.join("\n"));
  }

  if (partnerCheck) blocks.push(partnerCheck);
  if (input.tarotNote?.trim()) blocks.push(`[상대 현재 심리 — 타로]\n${input.tarotNote.trim()}`);

  blocks.push(`(근거) ${[...new Set(profile.evidence)].join("; ")}`);

  const evidence = `[상대 완전분석 — 작동방식·신뢰도 — 계산됨]\n${blocks.join("\n\n")}`;
  const instruction =
    "[상대 완전분석 근거 활용 안내] 위 '상대 작동방식'은 상대 원국의 심리 신호를 규칙으로 파생한 것이다. " +
    "16항목 각 섹션에서 이 근거로 쓰되, 진단명(애착유형·나르시시스트 등)과 사주 용어를 표면에 쓰지 말고 " +
    "\"~한 편입니다\" 톤의 생활어로만 옮겨라. 궁합 '점수'로 환원하지 말고, 위 [상대 행동 체크] 입력이 있으면 " +
    "반드시 그 실제 행동과 대조해 '말과 행동이 맞는지'를 짚어라. 남에게도 맞는 뻔한 말 금지 — 이 사람만의 " +
    "작동방식을 콕 짚어라. '분야별 신뢰도'의 '확인 필요'는 공포가 아니라 담담한 태도로 옮겨라.";

  return { evidence, instruction };
}
