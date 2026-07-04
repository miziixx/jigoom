import type { SajuChart } from "../types";
import { buildLifestyleGuide, type Element } from "./lifestyleGuide";

/**
 * 이름 감정(작명) 룰 기반 엔진.
 * 원칙: 계산은 여기서 결정론적으로 끝내고(발음오행·사주 보완·수리), 해석 문장만 상위에서 붙인다.
 * "이 이름은 나쁘다/불행하다" 같은 단정은 하지 않는다. 균형·보완 관점으로만 본다.
 */

const ELEMENT_KO: Record<Element, string> = {
  wood: "목",
  fire: "화",
  earth: "토",
  metal: "금",
  water: "수",
};

// 오행 상생: 목→화→토→금→수→목 / 상극: 목→토, 토→수, 수→화, 화→금, 금→목
const GENERATES: Record<Element, Element> = { wood: "fire", fire: "earth", earth: "metal", metal: "water", water: "wood" };
const OVERCOMES: Record<Element, Element> = { wood: "earth", earth: "water", water: "fire", fire: "metal", metal: "wood" };

// 한글 초성 19개 (유니코드 순서)
const CHOSEONG = ["ㄱ", "ㄲ", "ㄴ", "ㄷ", "ㄸ", "ㄹ", "ㅁ", "ㅂ", "ㅃ", "ㅅ", "ㅆ", "ㅇ", "ㅈ", "ㅉ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ"];

// 발음오행(오음 배속): 어금닛소리 목 / 혓소리 화 / 목구멍소리 토 / 잇소리 금 / 입술소리 수
const SOUND_ELEMENT: Record<string, Element> = {
  ㄱ: "wood", ㅋ: "wood", ㄲ: "wood",
  ㄴ: "fire", ㄷ: "fire", ㄹ: "fire", ㅌ: "fire", ㄸ: "fire",
  ㅇ: "earth", ㅎ: "earth",
  ㅅ: "metal", ㅈ: "metal", ㅊ: "metal", ㅆ: "metal", ㅉ: "metal",
  ㅁ: "water", ㅂ: "water", ㅍ: "water", ㅃ: "water",
};

export type SoundElementRelation = "상생" | "상극" | "같음";

export interface SyllableSound {
  syllable: string;
  choseong: string;
  element: Element;
  elementLabel: string;
}

export interface NameSoundAnalysis {
  syllables: SyllableSound[];
  /** 인접 음절 사이 관계 */
  relations: { from: string; to: string; relation: SoundElementRelation }[];
  harmony: "순조로움" | "무난함" | "다소 부딪힘";
  note: string;
}

/** 한 한글 음절의 초성을 뽑는다. 한글 음절이 아니면 null. */
function choseongOf(syllable: string): string | null {
  const code = syllable.charCodeAt(0);
  if (code < 0xac00 || code > 0xd7a3) return null;
  const index = Math.floor((code - 0xac00) / 588);
  return CHOSEONG[index] ?? null;
}

function relationOf(a: Element, b: Element): SoundElementRelation {
  if (a === b) return "같음";
  if (GENERATES[a] === b || GENERATES[b] === a) return "상생";
  if (OVERCOMES[a] === b || OVERCOMES[b] === a) return "상극";
  // 상생도 상극도 아닌 경우는 드물지만(오행 5개에서는 항상 둘 중 하나) 안전값
  return "같음";
}

/** 이름의 발음오행(초성 오행) 흐름을 분석한다. */
export function analyzeNameSound(name: string): NameSoundAnalysis {
  const chars = [...name].filter((ch) => choseongOf(ch) !== null);
  const syllables: SyllableSound[] = chars.map((ch) => {
    const cho = choseongOf(ch)!;
    const element = SOUND_ELEMENT[cho] ?? "earth";
    return { syllable: ch, choseong: cho, element, elementLabel: ELEMENT_KO[element] };
  });

  const relations: NameSoundAnalysis["relations"] = [];
  let sangsaeng = 0;
  let sanggeuk = 0;
  for (let i = 0; i < syllables.length - 1; i++) {
    const rel = relationOf(syllables[i].element, syllables[i + 1].element);
    if (rel === "상생") sangsaeng += 1;
    if (rel === "상극") sanggeuk += 1;
    relations.push({ from: syllables[i].syllable, to: syllables[i + 1].syllable, relation: rel });
  }

  let harmony: NameSoundAnalysis["harmony"];
  let note: string;
  if (sanggeuk === 0 && sangsaeng > 0) {
    harmony = "순조로움";
    note = "이름을 이루는 소리의 기운이 서로 밀어주는 흐름이라, 부르고 불릴 때 자연스럽게 이어집니다.";
  } else if (sanggeuk > sangsaeng) {
    harmony = "다소 부딪힘";
    note = "소리의 기운이 몇 군데서 엇갈립니다. 나쁜 이름이라는 뜻은 아니고, 부드러운 애칭이나 소리 배치를 함께 고려하면 균형을 보완할 수 있습니다.";
  } else {
    harmony = "무난함";
    note = "소리의 기운이 크게 부딪히지 않는 무난한 배열입니다.";
  }

  return { syllables, relations, harmony, note };
}

export type SajuFitLevel = "좋음" | "보통" | "주의";

export interface NameSajuFit {
  neededElement: Element;
  neededLabel: string;
  avoidElement: Element | null;
  avoidLabel: string | null;
  /** 이름 소리 기운이 보완 기운을 담고 있는가 */
  suppliesNeeded: boolean;
  /** 이름 소리 기운이 보완 기운을 상생으로 살려주는가 */
  supportsNeeded: boolean;
  /** 이름 소리 기운이 과하면 부담이 되는 기운으로 쏠리는가 */
  leansAvoid: boolean;
  level: SajuFitLevel;
  note: string;
}

/** 이름 발음오행이 이 사람 사주의 보완 기운과 얼마나 맞는지 본다. */
export function evaluateNameForChart(chart: SajuChart, sound: NameSoundAnalysis): NameSajuFit {
  const guide = buildLifestyleGuide(chart);
  const neededElement = guide.basisElement;
  const avoidElement = guide.avoidElement;
  const nameElements = sound.syllables.map((s) => s.element);

  const suppliesNeeded = nameElements.includes(neededElement);
  const supportsNeeded = nameElements.some((el) => GENERATES[el] === neededElement);
  const avoidCount = avoidElement ? nameElements.filter((el) => el === avoidElement).length : 0;
  const leansAvoid = avoidElement != null && avoidCount >= 2;

  let level: SajuFitLevel;
  if ((suppliesNeeded || supportsNeeded) && !leansAvoid) level = "좋음";
  else if (leansAvoid && !suppliesNeeded && !supportsNeeded) level = "주의";
  else level = "보통";

  const neededLabel = ELEMENT_KO[neededElement];
  const avoidLabel = avoidElement ? ELEMENT_KO[avoidElement] : null;

  let note: string;
  if (level === "좋음") {
    note = `이 사람에게 보완하면 좋은 ${neededLabel} 기운을 이름 소리가 ${suppliesNeeded ? "직접 담고 있어" : "상생으로 살려줘"} 균형에 도움이 됩니다.`;
  } else if (level === "주의") {
    note = `이름 소리가 ${avoidLabel} 기운으로 다소 쏠려 있습니다. 단정적으로 나쁘다는 뜻은 아니지만, ${neededLabel} 기운을 담은 소리를 곁들이면 균형이 더 맞습니다.`;
  } else {
    note = `보완 기운(${neededLabel})을 크게 살리지도, 부담 기운으로 쏠리지도 않는 무난한 조합입니다.`;
  }

  return { neededElement, neededLabel, avoidElement, avoidLabel, suppliesNeeded, supportsNeeded, leansAvoid, level, note };
}

// ── 수리성명학 (선택: 한자 획수를 줄 때만) ─────────────────────
// 81수 길흉: 대표적인 길수/흉수 배속. 사용자에게는 단정 대신 참고로만 노출한다.
const LUCKY_NUMBERS = new Set([
  1, 3, 5, 6, 7, 8, 11, 13, 15, 16, 17, 18, 21, 23, 24, 25, 29, 31, 32, 33, 35, 37, 39, 41, 45, 47, 48, 52, 57, 61, 63, 65, 67, 68, 81,
]);
const HALF_LUCKY_NUMBERS = new Set([27, 30, 38, 40, 51, 55, 58, 71, 73, 75]);

export type SuriLevel = "길" | "평" | "흉";

export interface SuriResult {
  /** 사격: 원격·형격·이격·정격 */
  won: number;
  hyeong: number;
  i: number;
  jeong: number;
  levels: { name: string; total: number; level: SuriLevel }[];
  summary: string;
}

function suriLevelOf(n: number): SuriLevel {
  const mod = ((n - 1) % 81) + 1;
  if (LUCKY_NUMBERS.has(mod)) return "길";
  if (HALF_LUCKY_NUMBERS.has(mod)) return "평";
  return "흉";
}

/**
 * 한자 획수로 사격 수리를 계산한다.
 * strokes: 성(姓) 포함 각 글자의 획수 배열. 예: [8, 9, 6] (김 8 · 민 9 · 준 6 형태의 획수)
 * 성이 한 글자, 이름이 두 글자인 전통 3자 이름 기준.
 */
export function evaluateSuri(strokes: number[]): SuriResult | null {
  if (strokes.length < 2) return null;
  const [surname, first, second] = strokes;
  const s = surname ?? 0;
  const f = first ?? 0;
  const t = second ?? 0;

  // 3자 이름 기준 사격 (2자 이름이면 second=0으로 근사)
  const won = f + t; // 원격: 이름 두 글자
  const hyeong = s + f; // 형격: 성 + 이름 첫 글자
  const i = s + t; // 이격: 성 + 이름 끝 글자
  const jeong = s + f + t; // 정격: 전체

  const levels = [
    { name: "원격(초년)", total: won, level: suriLevelOf(won) },
    { name: "형격(중년)", total: hyeong, level: suriLevelOf(hyeong) },
    { name: "이격(장년)", total: i, level: suriLevelOf(i) },
    { name: "정격(말년·총운)", total: jeong, level: suriLevelOf(jeong) },
  ];

  const luckyCount = levels.filter((l) => l.level === "길").length;
  const summary =
    luckyCount >= 3
      ? "획수 수리가 대체로 안정적인 배열입니다."
      : luckyCount === 0
        ? "획수 수리에 참고할 만한 흉수가 섞여 있습니다. 다만 수리는 여러 작명 학파 중 하나의 관점일 뿐, 이것만으로 이름을 단정하지 마세요."
        : "획수 수리에 길수와 그렇지 않은 수가 섞여 있습니다.";

  return { won, hyeong, i, jeong, levels, summary };
}

export type NameOverall = "좋음" | "보통" | "주의";

export interface NameEvaluation {
  name: string;
  sound: NameSoundAnalysis;
  fit: NameSajuFit;
  suri: SuriResult | null;
  overall: NameOverall;
  headline: string;
}

/** 이름 종합 감정: 발음오행 흐름 + 사주 보완 적합도 (+ 있으면 수리). */
export function evaluateName(chart: SajuChart, name: string, strokes?: number[]): NameEvaluation {
  const sound = analyzeNameSound(name);
  const fit = evaluateNameForChart(chart, sound);
  const suri = strokes && strokes.length >= 2 ? evaluateSuri(strokes) : null;

  // 종합: 사주 적합도를 중심으로, 발음 조화와 수리를 가감.
  let score = 0;
  score += fit.level === "좋음" ? 2 : fit.level === "보통" ? 1 : 0;
  score += sound.harmony === "순조로움" ? 1 : sound.harmony === "다소 부딪힘" ? -1 : 0;
  if (suri) {
    const lucky = suri.levels.filter((l) => l.level === "길").length;
    score += lucky >= 3 ? 1 : lucky === 0 ? -1 : 0;
  }

  const overall: NameOverall = score >= 3 ? "좋음" : score <= 0 ? "주의" : "보통";
  const headline =
    overall === "좋음"
      ? `이름 소리의 기운이 ${fit.neededLabel} 흐름을 잘 받쳐주는 편입니다.`
      : overall === "주의"
        ? `균형 면에서 보완하면 좋은 지점이 보이는 이름입니다.`
        : `크게 부딪히지 않는 무난한 이름입니다.`;

  return { name, sound, fit, suri, overall, headline };
}
