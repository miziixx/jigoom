import type { FiveElementBalance, LuckCycles, SajuChart } from "../types/index.js";
import { buildLifestyleGuide, type Element } from "./lifestyleGuide.js";

/**
 * 계산된 사주(SajuChart/LuckCycles)만으로 결과 상단 "요약 대시보드"에 쓸 시각 데이터를
 * 결정론적으로 만든다. (무 API, 룰 기반)
 *
 * 원칙(CLAUDE.md):
 * - 표면은 쉬운 말로. 절대적 길흉/공포/단정 금지.
 * - 점수는 "정밀한 진단"이 아니라 "상대 경향"이다. 라벨과 한 줄 해석을 함께 준다.
 * - 기존 buildLifestyleGuide / instantSummary / PatternMap 로직과 같은 오행·강약 근거를 쓴다.
 */

const ELEMENT_ORDER: Element[] = ["wood", "fire", "earth", "metal", "water"];

const ELEMENT_KO: Record<Element, string> = {
  wood: "목",
  fire: "화",
  earth: "토",
  metal: "금",
  water: "수",
};

/** 오행별 강점 키워드 (강하게 나타날 때의 장점) */
const ELEMENT_STRENGTH: Record<Element, string> = {
  wood: "성장·시작하는 추진력",
  fire: "표현력과 활력",
  earth: "안정감과 현실 책임감",
  metal: "판단력과 정리하는 힘",
  water: "생각의 깊이와 감수성",
};

/** 오행이 비어 있을 때 의식적으로 채우면 좋은 방향 */
const ELEMENT_FILL: Record<Element, string> = {
  wood: "새로 시작하는 힘",
  fire: "드러내고 표현하는 힘",
  earth: "안정과 마무리하는 힘",
  metal: "기준을 세우고 정리하는 힘",
  water: "쉬고 생각을 고르는 힘",
};

/** 오행이 과할 때 조심할 점 */
const ELEMENT_CAUTION: Record<Element, string> = {
  wood: "일을 여러 개 벌여 방향이 흩어지기 쉬움",
  fire: "피곤할 때 말·결정이 빨라지기 쉬움",
  earth: "책임을 혼자 떠안다 지치기 쉬움",
  metal: "기준이 높아 스스로를 몰아붙이기 쉬움",
  water: "생각이 길어져 실행이 늦어지기 쉬움",
};

export type ToneLevel = "high" | "mid" | "low";

export interface SpectrumAxis {
  key: string;
  leftLabel: string;
  rightLabel: string;
  /** 0 = 완전히 왼쪽, 100 = 완전히 오른쪽 */
  position: number;
  /** 치우친 쪽을 쉬운 말로 한 줄 */
  note: string;
}

export interface LifeArea {
  key: string;
  label: string;
  /** 상대 경향 0~100 (절대 진단 아님) */
  level: number;
  tone: ToneLevel;
  toneLabel: string;
  note: string;
}

export interface ReadingDashboard {
  strengths: string[];
  cautions: string[];
  needNow: string | null;
  keywords: string[];
  spectrum: SpectrumAxis[];
  lifeAreas: LifeArea[];
}

/** 십성 이름 → 5개 카테고리 */
type TenGodGroup = "비겁" | "식상" | "재성" | "관성" | "인성";
const TEN_GOD_GROUP: Record<string, TenGodGroup> = {
  비견: "비겁", 겁재: "비겁",
  식신: "식상", 상관: "식상",
  편재: "재성", 정재: "재성",
  편관: "관성", 정관: "관성", 칠살: "관성",
  편인: "인성", 정인: "인성", 인수: "인성",
};

function countTenGods(chart: SajuChart): Record<TenGodGroup, number> {
  const counts: Record<TenGodGroup, number> = { 비겁: 0, 식상: 0, 재성: 0, 관성: 0, 인성: 0 };
  const all = [...(chart.tenGods ?? []), ...(chart.branchTenGods ?? [])];
  for (const raw of all) {
    for (const name of Object.keys(TEN_GOD_GROUP)) {
      if (raw.includes(name)) {
        counts[TEN_GOD_GROUP[name]] += 1;
        break;
      }
    }
  }
  return counts;
}

/** 오행 분포를 0~1 비율로 (합이 0이면 균등) */
function elementFractions(five: FiveElementBalance): Record<Element, number> {
  const total = ELEMENT_ORDER.reduce((sum, k) => sum + Math.max(0, five[k]), 0);
  const out = {} as Record<Element, number>;
  for (const k of ELEMENT_ORDER) out[k] = total > 0 ? Math.max(0, five[k]) / total : 0.2;
  return out;
}

function clamp(n: number, min = 0, max = 100): number {
  return Math.max(min, Math.min(max, Math.round(n)));
}

function toneOf(level: number): { tone: ToneLevel; toneLabel: string } {
  if (level >= 66) return { tone: "high", toneLabel: "강함" };
  if (level >= 40) return { tone: "mid", toneLabel: "보통" };
  return { tone: "low", toneLabel: "은은함" };
}

/** 강약을 -1(신약)~0(중화)~1(신강)로 */
function strengthBias(chart: SajuChart): number {
  const label = chart.strength?.label;
  if (label === "신강") return 1;
  if (label === "신약") return -1;
  return 0;
}

function sortedElements(five: FiveElementBalance): Element[] {
  return [...ELEMENT_ORDER].sort((a, b) => five[b] - five[a]);
}

/** 4축 기질 스펙트럼 (0=왼쪽 라벨, 100=오른쪽 라벨) */
function buildSpectrum(chart: SajuChart): SpectrumAxis[] {
  const f = elementFractions(chart.fiveElements);
  const g = countTenGods(chart);
  const totalGods = Math.max(1, g.비겁 + g.식상 + g.재성 + g.관성 + g.인성);
  const bias = strengthBias(chart);

  // 각 축: 0.5 기준에서 신호로 이동 → 0~100
  // 1) 직관형 ↔ 분석형: 금·수 + 인성 → 분석(오른쪽), 목·화 → 직관(왼쪽)
  const analytic = f.metal + f.water + g.인성 / totalGods;
  const intuitive = f.wood + f.fire;
  const axis1 = clamp(50 + (analytic - intuitive) * 45);

  // 2) 즉흥형 ↔ 신중형: 수·금 + 신약(더 재고 조심) → 신중(오른쪽), 화·목 + 신강 → 즉흥(왼쪽)
  const careful = f.water + f.metal - bias * 0.15;
  const impulsive = f.fire + f.wood + bias * 0.15;
  const axis2 = clamp(50 + (careful - impulsive) * 45);

  // 3) 표현형 ↔ 내면형: 식상 + 화 → 표현(왼쪽), 인성 + 수 → 내면(오른쪽)
  const inward = g.인성 / totalGods + f.water;
  const outward = g.식상 / totalGods + f.fire;
  const axis3 = clamp(50 + (inward - outward) * 45);

  // 4) 관계형 ↔ 독립형: 비겁 + 신강 → 독립(오른쪽), 재성·관성 + 신약 → 관계(왼쪽)
  const independent = g.비겁 / totalGods + Math.max(0, bias) * 0.2;
  const relational = (g.재성 + g.관성) / totalGods + Math.max(0, -bias) * 0.2;
  const axis4 = clamp(50 + (independent - relational) * 45);

  const sideNote = (pos: number, left: string, right: string, leftDesc: string, rightDesc: string): string => {
    if (pos >= 60) return `${right} 쪽 — ${rightDesc}`;
    if (pos <= 40) return `${left} 쪽 — ${leftDesc}`;
    return `${left}과 ${right} 사이의 균형`;
  };

  return [
    {
      key: "intuition",
      leftLabel: "직관형",
      rightLabel: "분석형",
      position: axis1,
      note: sideNote(axis1, "직관형", "분석형", "느낌과 감으로 먼저 움직이는 편", "따져보고 근거를 챙긴 뒤 움직이는 편"),
    },
    {
      key: "tempo",
      leftLabel: "즉흥형",
      rightLabel: "신중형",
      position: axis2,
      note: sideNote(axis2, "즉흥형", "신중형", "떠오르면 바로 실행하는 편", "충분히 재보고 결정하는 편"),
    },
    {
      key: "expression",
      leftLabel: "표현형",
      rightLabel: "내면형",
      position: axis3,
      note: sideNote(axis3, "표현형", "내면형", "밖으로 드러내며 풀어내는 편", "안에서 정리한 뒤 조용히 내보이는 편"),
    },
    {
      key: "relation",
      leftLabel: "관계형",
      rightLabel: "독립형",
      position: axis4,
      note: sideNote(axis4, "관계형", "독립형", "사람·환경과 어울리며 힘을 얻는 편", "혼자 방향을 잡고 밀고 가는 편"),
    },
  ];
}

/** 인생영역 6개 상대 경향 막대 */
function buildLifeAreas(chart: SajuChart, luckCycles?: LuckCycles): LifeArea[] {
  const f = elementFractions(chart.fiveElements);
  const g = countTenGods(chart);
  const totalGods = Math.max(1, g.비겁 + g.식상 + g.재성 + g.관성 + g.인성);
  const bias = strengthBias(chart);

  // 성향(자기 색이 얼마나 뚜렷한지): 가장 강한 오행 비중이 높을수록 뚜렷
  const topFrac = Math.max(...ELEMENT_ORDER.map((k) => f[k]));
  const selfClarity = clamp(40 + (topFrac - 0.2) * 180);

  // 일/직업 추진력: 관성+식상 + 목·화 + 신강
  const workDrive = clamp(45 + ((g.관성 + g.식상) / totalGods) * 45 + (f.wood + f.fire - 0.4) * 40 + bias * 8);

  // 재물 감각: 재성 + 토·금
  const moneySense = clamp(45 + (g.재성 / totalGods) * 55 + (f.earth + f.metal - 0.4) * 40);

  // 관계 민감도: 재성·관성 + 수(감정) + 신약(주변 영향 큼)
  const relationSense = clamp(45 + ((g.재성 + g.관성) / totalGods) * 40 + (f.water - 0.2) * 60 - bias * 8);

  // 정서 안정성: 중화일수록 높고, 한쪽 쏠림/신살 많을수록 낮음. 토가 받쳐주면 +
  const spread = Math.max(...ELEMENT_ORDER.map((k) => f[k])) - Math.min(...ELEMENT_ORDER.map((k) => f[k]));
  const sinsalCount = chart.sinsal?.length ?? 0;
  const emotionStable = clamp(70 - spread * 60 + (f.earth - 0.2) * 40 - Math.min(sinsalCount, 4) * 3 - Math.abs(bias) * 5);

  // 흐름 활용도: 올해 세운 상호작용이 있으면 변화를 쓸 기회 ↑ (너무 많으면 소폭 감점)
  const yearCount = luckCycles?.luckInteractions?.length ?? 0;
  const flowUse = clamp(50 + (yearCount >= 1 ? 18 : -5) + (yearCount >= 3 ? -10 : 0) + (bias >= 0 ? 6 : 0));

  const areas: Array<Omit<LifeArea, "tone" | "toneLabel">> = [
    { key: "self", label: "성향 이해도", level: selfClarity, note: "타고난 색이 얼마나 뚜렷한지" },
    { key: "work", label: "일 추진력", level: workDrive, note: "일을 밀고 나가는 힘의 경향" },
    { key: "money", label: "재물 감각", level: moneySense, note: "현실 감각·결과를 만드는 힘의 경향" },
    { key: "relation", label: "관계 민감도", level: relationSense, note: "사람·감정 흐름을 읽는 예민함" },
    { key: "emotion", label: "정서 안정성", level: emotionStable, note: "마음이 흔들려도 돌아오는 힘" },
    { key: "flow", label: "흐름 활용도", level: flowUse, note: "올해 흐름을 쓸 여지" },
  ];

  return areas.map((a) => ({ ...a, ...toneOf(a.level) }));
}

function buildStrengthsCautions(chart: SajuChart): { strengths: string[]; cautions: string[] } {
  const sorted = sortedElements(chart.fiveElements);
  const strong = sorted.slice(0, 2);
  const g = countTenGods(chart);

  const strengths: string[] = [];
  for (const el of strong) {
    if (chart.fiveElements[el] > 0) strengths.push(ELEMENT_STRENGTH[el]);
  }
  // 십성 최다 그룹의 강점 한 줄 보강
  const godGroups: Array<[TenGodGroup, string]> = [
    ["식상", "아이디어를 밖으로 풀어내는 힘"],
    ["재성", "현실 감각과 결과를 만드는 힘"],
    ["관성", "책임을 맡아 구조를 세우는 힘"],
    ["인성", "배우고 받아들여 정리하는 힘"],
    ["비겁", "스스로 방향을 세우는 독립심"],
  ];
  const topGod = godGroups.sort((a, b) => g[b[0]] - g[a[0]])[0];
  if (topGod && g[topGod[0]] > 0 && strengths.length < 3) strengths.push(topGod[1]);

  const cautions: string[] = [];
  // 과한 오행(가장 강한) + 강도 라벨 기반
  if (chart.fiveElements[sorted[0]] > 0) cautions.push(ELEMENT_CAUTION[sorted[0]]);
  if (chart.strength?.label === "신강") cautions.push("혼자 끌어안다 도움 요청이 늦어지기 쉬움");
  else if (chart.strength?.label === "신약") cautions.push("무리한 독주보다 환경·협력이 필요함");
  // 비어 있는 오행 보완
  const weakest = sorted[sorted.length - 1];
  if (chart.fiveElements[weakest] === 0 && cautions.length < 3) {
    cautions.push(`${ELEMENT_FILL[weakest]}(${ELEMENT_KO[weakest]})을 의식적으로 챙기면 균형에 도움`);
  }

  return {
    strengths: strengths.slice(0, 3),
    cautions: cautions.slice(0, 3),
  };
}

/** 오행 강할 때의 짧은 성향 칩 라벨 */
const ELEMENT_CHIP: Record<Element, string> = {
  wood: "성장형",
  fire: "활력형",
  earth: "안정형",
  metal: "정리형",
  water: "사색형",
};

function buildKeywords(chart: SajuChart, spectrum: SpectrumAxis[]): string[] {
  const chips: string[] = [];
  const sorted = sortedElements(chart.fiveElements);
  if (chart.fiveElements[sorted[0]] > 0) chips.push(ELEMENT_CHIP[sorted[0]]);
  // 뚜렷하게 치우친 스펙트럼 축의 라벨을 칩으로
  for (const axis of spectrum) {
    if (axis.position >= 62) chips.push(axis.rightLabel);
    else if (axis.position <= 38) chips.push(axis.leftLabel);
    if (chips.length >= 4) break;
  }
  if (chart.strength?.label && chips.length < 5) chips.push(chart.strength.label);
  // 중복 제거
  return [...new Set(chips)].slice(0, 5);
}

export function buildReadingDashboard(chart?: SajuChart, luckCycles?: LuckCycles): ReadingDashboard | null {
  if (!chart) return null;
  const { strengths, cautions } = buildStrengthsCautions(chart);
  const guide = buildLifestyleGuide(chart, { todayGanZhi: luckCycles?.dayGanZhi });
  const needNow = guide.todayActions[0] ?? guide.playfulActions[0] ?? null;
  const spectrum = buildSpectrum(chart);

  return {
    strengths,
    cautions,
    needNow,
    keywords: buildKeywords(chart, spectrum),
    spectrum,
    lifeAreas: buildLifeAreas(chart, luckCycles),
  };
}
