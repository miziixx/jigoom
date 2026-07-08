import type { SajuChart } from "../types/index.js";
import { groupOf, type TenGodGroup } from "./eventEngine.js";

/**
 * 재료축/출력축 엔진 (무 API·결정론).
 *
 * 목적:
 *   "이 사람은 이렇다"가 남한테도 맞는 뻔한 말이 되면 리딩은 실패한다. 같은 기질이라도
 *   "얼마나 타고났나(재료)"와 "실제로 굴릴 힘이 되나(출력)"는 다르다. 재료는 넉넉한데
 *   출력이 약하면 "마음은 앞서는데 실행에서 멈추는" 사람이고, 재료는 적은데 출력이 좋으면
 *   "적은 걸로 결과를 내는" 사람이다. 이 대비가 있어야 '이 사람만'의 문장이 나온다.
 *
 * 두 축:
 *   - 재료축: 그 기질(십성 그룹)을 천간(드러남)·지지에 얼마나 갖췄나. 천간에 있으면 더 세게.
 *   - 출력축: 일간의 힘 세기(신강/신약)로 그 기질을 감당·발현할 수 있나 + 통근(뿌리) 보정.
 *     설기·대응하는 기질(식상·재성·관성)은 일간이 강해야 굴리고, 약하면 재료가 있어도 못 쓴다.
 *
 * 원칙(CLAUDE.md, 사용자 정교화 규칙):
 *   - 계산은 결정론, 표면은 쉬운 말, 사주 용어는 근거(evidence)에만.
 *   - 강약·용신 판정은 유파마다 갈리므로 단정하지 말고 경향('~한 편')으로.
 *   - saju.ts를 import하지 않는다(번들 방지). groupOf/TenGodGroup만 eventEngine에서 재사용.
 */

type Element = "wood" | "fire" | "earth" | "metal" | "water";

const GAN_WUXING: Record<string, Element> = {
  갑: "wood", 을: "wood", 병: "fire", 정: "fire", 무: "earth",
  기: "earth", 경: "metal", 신: "metal", 임: "water", 계: "water",
};
const GENERATES: Record<Element, Element> = {
  wood: "fire", fire: "earth", earth: "metal", metal: "water", water: "wood",
};
const OVERCOMES: Record<Element, Element> = {
  wood: "earth", earth: "water", water: "fire", fire: "metal", metal: "wood",
};
function invert(map: Record<Element, Element>): Record<Element, Element> {
  const out = {} as Record<Element, Element>;
  for (const k of Object.keys(map) as Element[]) out[map[k]] = k;
  return out;
}
const GENERATED_BY = invert(GENERATES); // GENERATED_BY[x] = x를 생하는 오행 (→ 인성)
const OVERCOME_BY = invert(OVERCOMES); // OVERCOME_BY[x] = x를 극하는 오행 (→ 관성)

/** 십성 그룹이 일간과 맺는 오행 관계 → 그 그룹의 대표 오행 */
function groupElement(dayEl: Element, group: TenGodGroup): Element {
  switch (group) {
    case "비겁": return dayEl;
    case "식상": return GENERATES[dayEl];
    case "재성": return OVERCOMES[dayEl];
    case "관성": return OVERCOME_BY[dayEl];
    case "인성": return GENERATED_BY[dayEl];
  }
}

/** 일간이 힘을 써서 감당·대응하는 기질(강해야 굴림) / 일간 세력 자체 */
const DRAINING: TenGodGroup[] = ["식상", "재성", "관성"];

/** 표면 문장에 쓸 심리 라벨 (십성 용어 금지) */
const GROUP_TRAIT: Record<TenGodGroup, string> = {
  비겁: "자기 주장과 독립심",
  식상: "표현하고 새로 벌이는 힘",
  재성: "현실 감각과 성과를 만드는 힘",
  관성: "책임감과 자기 통제력",
  인성: "배우고 받아들이는 힘",
};

export type AxisLevel = "강" | "중" | "약";

export interface GroupCapacity {
  /** 내부 근거용 (표면 노출 금지) */
  group: TenGodGroup;
  trait: string;
  material: AxisLevel;
  output: AxisLevel;
  materialScore: number;
  outputScore: number;
  /** 재료-출력 조합을 쉬운 말로 푼 '이 사람만'의 문장 */
  read: string;
  evidence: string;
}

const ALL_GROUPS: TenGodGroup[] = ["비겁", "식상", "재성", "관성", "인성"];

function materialLevel(score: number): AxisLevel {
  if (score >= 2.3) return "강";
  if (score >= 1.0) return "중";
  return "약";
}
function outputLevel(score: number): AxisLevel {
  if (score >= 2.5) return "강";
  if (score >= 1.6) return "중";
  return "약";
}

/** 재료-출력 조합별 '이 사람만'의 해석 문장 */
function readOf(trait: string, material: AxisLevel, output: AxisLevel): string {
  const key = `${material}/${output}`;
  switch (key) {
    case "강/약":
      return `${trait}은 타고나길 넉넉한데 실제로 밀어붙일 힘은 약한 편이라, 마음은 앞서는데 실행에서 자주 멈춥니다.`;
    case "강/중":
      return `${trait}이 이 사람의 뚜렷한 재료이고, 상황이 받쳐줄 때 잘 살지만 무리하면 힘에 부칩니다.`;
    case "강/강":
      return `${trait}은 재료도 넉넉하고 굴릴 힘도 받쳐줘, 이 사람의 확실한 무기입니다.`;
    case "중/약":
      return `${trait}은 어느 정도 있지만 지금 힘이 약해, 여기에 승부를 걸기보다 아껴 쓰는 편이 낫습니다.`;
    case "중/중":
      return `${trait}은 무난한 편이라, 상황에 따라 살리기도 아끼기도 하며 균형으로 다룹니다.`;
    case "중/강":
      return `${trait}은 양이 아주 많진 않아도 잘 써먹는 편이라, 필요할 때 효율적으로 씁니다.`;
    case "약/약":
      return `${trait}은 두드러지지 않아, 여기서 자신을 증명하려 애쓰기보다 다른 강점을 앞세우는 편이 낫습니다.`;
    case "약/중":
      return `${trait}은 적은 편이지만 감당은 되어, 꼭 필요한 만큼만 쓰면 무리가 없습니다.`;
    case "약/강":
      return `${trait}은 타고난 양은 적어도 가진 걸 알뜰히 써서, 적은 재료로도 결과를 냅니다.`;
    default:
      return `${trait}은 재료와 실제 쓰는 힘이 엇갈려, 상황에 따라 다르게 나타납니다.`;
  }
}

function countMaterial(chart: SajuChart): Record<TenGodGroup, number> {
  const raw: Record<TenGodGroup, number> = { 비겁: 0, 식상: 0, 재성: 0, 관성: 0, 인성: 0 };
  // 천간 십성 = 밖으로 드러난(투출) 기질 → 더 세게 가중
  for (const s of chart.tenGods ?? []) {
    const g = groupOf(s);
    if (g) raw[g] += 1.3;
  }
  // 지지 십성 = 속에 깔린 기질
  for (const s of chart.branchTenGods ?? []) {
    const g = groupOf(s);
    if (g) raw[g] += 1.0;
  }
  return raw;
}

/** 그 기질의 대표 오행이 지지에 뿌리를 두는지로 출력 보정 */
function rootBonus(chart: SajuChart, el: Element): number {
  const hits = (chart.rootedness ?? []).filter((r) => GAN_WUXING[r.gan] === el);
  if (hits.length === 0) return 0; // 그 오행의 천간이 원국에 없음 → 중립
  const strongRoot = hits.some((r) => r.rooted && r.roots.some((root) => root.strength === "정기"));
  if (strongRoot) return 0.7;
  const anyRoot = hits.some((r) => r.rooted);
  if (anyRoot) return 0.35;
  return -0.35; // 천간은 있는데 무근(떠 있음) → 출력 감점
}

export function buildCapacityAxes(chart?: SajuChart): GroupCapacity[] | null {
  if (!chart || !chart.dayMasterGan) return null;
  const dayEl = GAN_WUXING[chart.dayMasterGan];
  if (!dayEl) return null;

  const material = countMaterial(chart);
  const label = chart.strength?.label;
  const strong = label?.includes("신강");
  const weak = label?.includes("신약");

  const items: GroupCapacity[] = ALL_GROUPS.map((group) => {
    const draining = DRAINING.includes(group);
    // 억부 base: 설기·대응 기질은 일간이 강해야 굴린다. 세력 기질은 강약을 그대로 반영.
    let base: number;
    if (strong) base = draining ? 2.6 : 2.4;
    else if (weak) base = draining ? 1.1 : 1.4;
    else base = 2.0; // 중화
    const el = groupElement(dayEl, group);
    const outputScore = base + rootBonus(chart, el);
    const materialScore = material[group];
    const mLevel = materialLevel(materialScore);
    const oLevel = outputLevel(outputScore);
    return {
      group,
      trait: GROUP_TRAIT[group],
      material: mLevel,
      output: oLevel,
      materialScore: Math.round(materialScore * 10) / 10,
      outputScore: Math.round(outputScore * 10) / 10,
      read: readOf(GROUP_TRAIT[group], mLevel, oLevel),
      evidence: `${GROUP_TRAIT[group]}(${group}): 재료 ${mLevel}(천간·지지 십성 ${materialScore.toFixed(1)}) / 출력 ${oLevel}(강약 ${label ?? "미정"}, 뿌리 보정 반영)`,
    };
  });

  // 재료 많은 순으로. 같으면 재료-출력 격차(개인차가 큰 것)를 앞으로.
  const gap = (i: GroupCapacity) => Math.abs(i.materialScore - i.outputScore);
  items.sort((a, b) => b.materialScore - a.materialScore || gap(b) - gap(a));
  return items;
}

/** 프롬프트 근거 블록으로 직렬화한다. */
export function formatCapacityAxes(items: GroupCapacity[]): string {
  const lines = [
    "아래는 이 사람이 어떤 기질을 '얼마나 타고났나(재료)'와 '실제로 굴릴 힘이 되나(출력)'를 나눠 계산한 것이다. 재료와 출력이 엇갈리는 기질이 이 사람의 개인차다.",
  ];
  for (const it of items) lines.push(`- ${it.read}`);
  lines.push(`(근거) ${items.map((it) => it.evidence).join("; ")}`);
  return lines.join("\n");
}
