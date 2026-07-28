import type { SajuChart } from "../types/index.js";
import { groupOf, type TenGodGroup } from "./eventEngine.js";

/**
 * "속마음 레이어" 엔진 (무 API·결정론).
 *
 * 목적:
 *   nowMind가 "지금 시점(세운·월운)이 끌어올리는 마음"을 계산한다면, 이 엔진은 타고난 원국
 *   구조가 만드는 "지속적인 속마음·반복 패턴"을 계산한다. 사주 명식을 나열하는 대신, 그 구조가
 *   현실에서 어떤 욕구·방어·인정욕구·관계·스트레스·반복 병목으로 나타나는지를 심리 패턴 언어로
 *   미리 번역해 LLM에 근거로 넘긴다. 목표는 "심리 상담처럼 보이게"가 아니라, 사주 리딩을
 *   부드럽지만 정확하고 날카롭게 만드는 것.
 *
 * 원칙(nowMind.ts·CLAUDE.md와 동일):
 *   - 계산은 결정론, 표면은 쉬운 말, 절대적 길흉·공포·단정·진단명 금지.
 *   - "이렇다"가 아니라 "이런 쪽에 가깝다 / 이렇게 나타나기 쉽다"(경향).
 *   - 심리 용어(애착유형·회피형·불안형·방어기제 등)와 사주 용어(십성·천간·지지 등)는
 *     evidence(근거)에만. 표면 문장(coreDesire/outerInner/… )에는 절대 쓰지 않는다.
 *   - saju.ts를 import하지 않는다. 십성 판정은 eventEngine의 검증된 groupOf를 재사용하고,
 *     원국에 이미 계산되어 있는 tenGods(천간=겉)/branchTenGods(지지=속)/tenGodDistribution을 읽는다.
 */

/** 강약(신강/신약)에 따라 방어·스트레스 톤을 가른다. */
type Tone = "strong" | "weak" | "neutral";

const GROUPS: TenGodGroup[] = ["비겁", "식상", "재성", "관성", "인성"];

/** 세상과 관계 맺는 핵심 욕구 (지배 그룹). */
const DESIRE_BY_GROUP: Record<TenGodGroup, string> = {
  비겁: "남에게 휘둘리지 않고 내 기준·내 힘으로 서서 인정받고 싶은 마음이 바탕에 깔려 있는 편입니다.",
  식상: "안에 담아두기보다 밖으로 표현하고 뭔가 만들어내야 속이 풀리는 쪽에 가깝습니다.",
  재성: "마음이나 명분보다 손에 잡히는 결과로 확인돼야 안심하고, 뭐가 남는지 계산이 서야 움직이는 편입니다.",
  관성: "맡은 걸 제대로 해내 자리와 역할로 인정받고 싶고, 책임을 지려는 마음이 앞서는 편입니다.",
  인성: "바로 움직이기보다 먼저 이해하고 정리해서 납득이 돼야 안심하고 나서는 쪽에 가깝습니다.",
};

/** 눌리거나 불편할 때 나오는 대응 방식 (패턴 서술, 진단명 없이). */
const DEFENSE_BY_GROUP: Record<TenGodGroup, string> = {
  비겁: "불편해지면 남에게 기대기보다 혼자 짊어지고, 선을 그어 거리를 두는 식으로 자신을 지키려 합니다.",
  식상: "처음엔 참다가 어느 순간 말이 세지거나, 농담·표현으로 진심을 슬쩍 비껴 흘리는 식으로 넘기기 쉽습니다.",
  재성: "감정으로 부딪히기보다 손익과 현실로 정리해 '별거 아니야'로 접어버리는 식으로 처리하는 편입니다.",
  관성: "불안할수록 더 통제하고 규칙·계획으로 눌러 담아, 겉으로는 멀쩡하고 반듯해 보이려 합니다.",
  인성: "감정을 바로 느끼기보다 머릿속에서 분석하고 해석해 처리하려 하고, 시작 전에 이미 실패한 그림까지 다 돌려보곤 합니다.",
};

/** 인정받고 싶은 지점 + 선택할 때 막히는 방식. */
const RECOGNITION_BY_GROUP: Record<TenGodGroup, string> = {
  비겁: "남과 비교당하거나 내 몫을 인정 못 받을 때 자존심이 크게 긁히고, 선택은 남 기준보다 '내가 납득되느냐'로 하려다 고집으로 늦어지기 쉽습니다.",
  식상: "내 방식과 색깔을 알아줄 때 인정받았다고 느끼고, 틀에 맞추라는 요구 앞에서는 하기 싫어 미루거나 튀는 선택으로 새기 쉽습니다.",
  재성: "결과와 숫자로 쓸모를 확인받고 싶어 하고, 선택은 손익을 다 재려다 타이밍을 놓치거나 반대로 조급하게 질러버리는 양극단으로 가기 쉽습니다.",
  관성: "맡은 걸 제대로 해내 인정받고 싶은 마음이 크고, 선택한 뒤 따라올 책임까지 미리 감당하려 해서 정작 시작이 늦어지는 편입니다.",
  인성: "실력과 전문성으로 인정받고 싶어 하고, 선택 전에 더 알아보고 확실히 하려다 결정을 자꾸 미루기 쉽습니다.",
};

/** 가까운 관계에서의 경향 (일지=배우자 자리 우선, 없으면 지배 그룹). */
const ATTACHMENT_BY_GROUP: Record<TenGodGroup, string> = {
  비겁: "가까워져도 내 페이스와 독립을 지키고 싶어, 붙는 만큼 혼자만의 거리도 필요해지는 편입니다.",
  식상: "표현으로 관계를 확인하려 하고, 반응이 없다 느끼면 서운함이 말투로 먼저 새어 나오기 쉽습니다.",
  재성: "잘해주는 만큼 돌아오는지 은근히 재게 되고, 마음이 있어도 현실 조건이 안 맞으면 빨리 식는 편입니다.",
  관성: "관계에서도 기준과 책임을 세우려 하고, 상대가 그 틀을 안 지키면 실망이 크지만 티는 잘 안 내는 편입니다.",
  인성: "가까워질수록 오히려 부담을 느껴 한 발 물러나 혼자 정리하려 하고, 그게 상대에겐 거리를 두는 걸로 보이기 쉽습니다.",
};

/** 스트레스받을 때 나오는 모습 + 회복 조건 (강약 tone 반영). */
const STRESS_BY_GROUP: Record<TenGodGroup, Record<Tone, string>> = {
  비겁: {
    strong: "밀어붙이는 힘이 세서 혼자 다 짊어지다 어느 순간 방전되는 식으로 지치기 쉽고, 잠깐이라도 내 페이스를 되찾을 혼자만의 시간이 있어야 회복됩니다.",
    weak: "비교당하는 상황이 길어지면 위축되고 예민해지는데, 내 편이라 느끼는 한 사람만 있어도 기운이 도로 붙습니다.",
    neutral: "내 몫이 인정 안 될 때 스트레스가 쌓이고, 내 리듬대로 움직일 여유가 생기면 회복됩니다.",
  },
  식상: {
    strong: "하고 싶은 걸 못 풀면 답답함이 쌓이다 말이나 행동으로 터지는 식이라, 표현하거나 만들 출구가 있으면 금방 풀립니다.",
    weak: "표현을 참는 상황이 이어지면 의욕부터 꺼지는데, 편하게 말할 수 있는 자리에서 기운이 돌아옵니다.",
    neutral: "막힌 걸 못 풀 때 지치고, 새로 벌이거나 표현할 거리가 생기면 살아납니다.",
  },
  재성: {
    strong: "성과가 손에 안 잡히면 초조해져 더 몰아붙이다 소진되기 쉽고, 작더라도 눈에 보이는 결과가 하나 나오면 안정됩니다.",
    weak: "결과·돈 압박이 커지면 쉽게 지치는데, 감당 가능한 크기로 쪼개 하나씩 매듭지으면 회복됩니다.",
    neutral: "결과가 안 보일 때 불안해지고, 현실이 한 칸이라도 정리되면 안심합니다.",
  },
  관성: {
    strong: "해야 할 것과 눈치 볼 것을 다 떠안다 어깨가 굳는 식으로 지치기 쉽고, 책임을 잠시 내려놓아도 되는 시간이 있어야 회복됩니다.",
    weak: "압박과 평가가 몰리면 쉽게 눌리고 몸이 먼저 굳는데, 기준을 조금 느슨하게 풀어주면 숨통이 트입니다.",
    neutral: "부담이 겹칠 때 긴장으로 지치고, 해야 할 걸 덜어내면 회복됩니다.",
  },
  인성: {
    strong: "생각이 꼬리를 물어 시작도 전에 이미 지치는 식이라, 정보를 끊고 몸을 움직여 머리를 비우면 회복됩니다.",
    weak: "결정 압박이 오면 더 알아보려다 소진되는데, 충분히 쉬고 혼자 정리할 시간이 있어야 힘이 붙습니다.",
    neutral: "생각이 많아질 때 지치고, 한 발 물러나 재충전하면 회복됩니다.",
  },
};

/** 반복되는 병목 ("어디서 자주 막히는가") — 지배 그룹 기준. */
const BOTTLENECK_BY_GROUP: Record<TenGodGroup, string> = {
  비겁: "능력이 없어서가 아니라, 남에게 맡기거나 기대는 걸 어려워해 혼자 짊어지다 지치는 데서 자주 막히는 편입니다.",
  식상: "재능이 없어서가 아니라, 하고 싶은 걸 참다가 한 번에 터뜨려 관계나 판을 흔드는 데서 자주 막히는 편입니다.",
  재성: "돈을 못 버는 구조라기보다, 기회가 올 때 책임·부담도 같이 커지는 탓에 오래 못 버티고 손을 놓는 데서 자주 새기 쉽습니다.",
  관성: "책임감이 없어서가 아니라, 다 맞춰주다 속으로 반발이 쌓여 어느 순간 한꺼번에 놓아버리는 데서 자주 막히는 편입니다.",
  인성: "실력이 없어서가 아니라, 시작 전에 생각으로 실패를 다 돌려보다 정작 첫발이 늦어지는 데서 자주 막히는 편입니다.",
};

/** 겉으로 드러나는 태도 (천간 지배 그룹). */
const OUTER_FACE: Record<TenGodGroup, string> = {
  비겁: "주관 뚜렷하고 단단해",
  식상: "밝고 표현 잘하며 재치있어",
  재성: "현실적이고 야무지게 잘 챙겨",
  관성: "책임감 있고 반듯해",
  인성: "차분하고 신중해",
};

/** 속에서 실제로 원하는 것 (지지 지배 그룹). */
const INNER_WANT: Record<TenGodGroup, string> = {
  비겁: "누구에게도 휘둘리지 않고 내 힘으로 서고 싶은",
  식상: "틀에 갇히지 않고 하고 싶은 대로 풀어내고 싶은",
  재성: "손에 잡히는 결과로 확실히 남기고 싶은",
  관성: "제대로 인정받고 내 자리를 지키고 싶은",
  인성: "충분히 이해하고 안전하다 느낀 다음 움직이고 싶은",
};

export interface PsychLayer {
  /** 세상과 관계 맺는 핵심 욕구 한 줄 */
  coreDesire: string;
  /** 겉(천간)과 속(지지)이 다를 때의 대비. 같으면 null */
  outerInner: string | null;
  /** 눌릴 때 나오는 대응(방어) 방식 */
  defense: string;
  /** 인정받고 싶은 지점 + 선택이 막히는 방식 */
  recognitionDecision: string;
  /** 가까운 관계에서의 경향 */
  attachment: string;
  /** 스트레스받을 때 모습 + 회복 조건 */
  stressPattern: string;
  /** 반복되는 병목 한 줄 */
  repeatedPattern: string;
  /** 계산이 뚜렷하면 확실, 애매하면 추정 */
  confidence: "확실" | "추정";
  /** 전문가 근거용 (십성 분포·겉속·강약). 표면 노출 금지 */
  evidence: string[];
}

/** 원국에 이미 계산된 십성 문자열 목록에서 그룹별 개수를 센다. */
function countGroups(rawList: string[] | undefined): Record<TenGodGroup, number> {
  const counts: Record<TenGodGroup, number> = { 비겁: 0, 식상: 0, 재성: 0, 관성: 0, 인성: 0 };
  for (const raw of rawList ?? []) {
    const g = groupOf(raw);
    if (g) counts[g] += 1;
  }
  return counts;
}

/** tenGodDistribution(가중 분포)를 그룹 가중치로 합산한다. */
function distributionWeights(dist: Record<string, number> | undefined): Record<TenGodGroup, number> {
  const w: Record<TenGodGroup, number> = { 비겁: 0, 식상: 0, 재성: 0, 관성: 0, 인성: 0 };
  if (!dist) return w;
  for (const [name, value] of Object.entries(dist)) {
    const g = groupOf(name);
    if (g && Number.isFinite(value)) w[g] += value;
  }
  return w;
}

/** 최댓값 그룹과, 2등과의 격차가 뚜렷한지(확실/추정)를 함께 뽑는다. */
function dominantOf(weights: Record<TenGodGroup, number>): { group: TenGodGroup | null; clear: boolean } {
  const sorted = GROUPS.map((g) => ({ g, v: weights[g] })).sort((a, b) => b.v - a.v);
  const top = sorted[0];
  const second = sorted[1];
  if (!top || top.v <= 0) return { group: null, clear: false };
  // 2등보다 눈에 띄게 앞서면 "확실"(가중 분포는 1.5배, 개수는 최소 1 이상 격차 기준으로 호출부에서 판단).
  const clear = top.v >= second.v * 1.5 || top.v - second.v >= 2;
  return { group: top.g, clear };
}

/** 일지(배우자·가장 가까운 관계 자리)의 십성 그룹. 없으면 null. */
function dayBranchGroup(chart: SajuChart): TenGodGroup | null {
  for (const raw of chart.branchTenGods ?? []) {
    if (raw.startsWith("일지")) return groupOf(raw);
  }
  return null;
}

function toneOf(chart: SajuChart): Tone {
  const label = chart.strength?.label;
  if (label === "신강") return "strong";
  if (label === "신약") return "weak";
  return "neutral";
}

export function buildPsychLayer(chart?: SajuChart): PsychLayer | null {
  if (!chart || !chart.dayMasterGan) return null;

  // 지배 그룹: 가중 분포(tenGodDistribution) 우선, 없으면 천간+지지 개수로.
  const distW = distributionWeights(chart.tenGodDistribution);
  const hasDist = GROUPS.some((g) => distW[g] > 0);
  const countW = (() => {
    const c = countGroups(chart.tenGods);
    const b = countGroups(chart.branchTenGods);
    const merged: Record<TenGodGroup, number> = { 비겁: 0, 식상: 0, 재성: 0, 관성: 0, 인성: 0 };
    for (const g of GROUPS) merged[g] = c[g] + b[g];
    return merged;
  })();
  const overall = dominantOf(hasDist ? distW : countW);
  if (!overall.group) return null;
  const dominant = overall.group;

  // 겉(천간) vs 속(지지) 지배 그룹.
  const outer = dominantOf(countGroups(chart.tenGods)).group;
  const inner = dominantOf(countGroups(chart.branchTenGods)).group;
  const outerInner =
    outer && inner && outer !== inner
      ? `겉으로는 ${OUTER_FACE[outer]} 보이지만, 속으로는 ${INNER_WANT[inner]} 마음이 더 강한 편입니다. 그래서 남들이 보는 모습과 실제로 편한 방식 사이에 간극이 생기기 쉽습니다.`
      : null;

  const tone = toneOf(chart);
  const attachGroup = dayBranchGroup(chart) ?? dominant;

  // 반복 병목: 지배 그룹 기준 + 형/충 상호작용이 있으면 한 마디 덧붙인다.
  const interactions = chart.interactions ?? [];
  const hasHyeong = interactions.some((s) => s.includes("형"));
  const hasChung = interactions.some((s) => s.includes("충"));
  let repeatedPattern = BOTTLENECK_BY_GROUP[dominant];
  if (hasHyeong) repeatedPattern += " 특히 겉은 괜찮아 보여도 속으로 압박이 쌓이는 결이 있어, 이 패턴이 더 도드라질 수 있습니다.";
  else if (hasChung) repeatedPattern += " 특히 익숙한 자리가 한 번씩 크게 흔들리는 구조라, 변화의 길목마다 이 패턴이 반복되기 쉽습니다.";

  const evidence = [
    `지배 십성 그룹: ${dominant} (${hasDist ? "가중 분포" : "천간+지지 개수"} 기준)`,
    outer && inner ? `겉(천간) 주도: ${outer} / 속(지지) 주도: ${inner}` : "",
    chart.strength ? `강약 ${chart.strength.label}: ${chart.strength.detail}` : "",
    attachGroup ? `가까운 관계 축(일지 우선): ${attachGroup}` : "",
    interactions.length > 0 ? `원국 상호작용: ${interactions.slice(0, 4).join(", ")}` : "",
  ].filter(Boolean);

  return {
    coreDesire: DESIRE_BY_GROUP[dominant],
    outerInner,
    defense: DEFENSE_BY_GROUP[dominant],
    recognitionDecision: RECOGNITION_BY_GROUP[dominant],
    attachment: ATTACHMENT_BY_GROUP[attachGroup],
    stressPattern: STRESS_BY_GROUP[dominant][tone],
    repeatedPattern,
    // 겉·속이 갈리거나 분포가 뚜렷하지 않으면 "추정"으로 낮춘다.
    confidence: overall.clear ? "확실" : "추정",
    evidence,
  };
}

/** 프롬프트 근거 블록으로 직렬화한다. */
export function formatPsychLayer(p: PsychLayer): string {
  const lines = [
    `핵심 욕구: ${p.coreDesire}`,
    ...(p.outerInner ? [`겉과 속: ${p.outerInner}`] : []),
    `눌릴 때 나오는 방식: ${p.defense}`,
    `인정·선택: ${p.recognitionDecision}`,
    `가까운 관계: ${p.attachment}`,
    `스트레스·회복: ${p.stressPattern}`,
    `반복 병목: ${p.repeatedPattern}`,
    `확신도: ${p.confidence}`,
  ];
  if (p.evidence.length > 0) lines.push(`(근거) ${p.evidence.join("; ")}`);
  return lines.join("\n");
}
