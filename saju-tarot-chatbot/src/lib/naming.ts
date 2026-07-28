import type { SajuChart } from "../types/index.js";
import { buildLifestyleGuide, type Element } from "./lifestyleGuide.js";

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

export type SoundElementSchool = "full-name" | "given-name";

export const SOUND_ELEMENT_SCHOOL_LABEL: Record<SoundElementSchool, string> = {
  "full-name": "전체 이름 기준",
  "given-name": "이름 중심 기준",
};

export type NamingMode = "baby" | "rename" | "stage" | "brand";

export const NAMING_MODE_LABEL: Record<NamingMode, string> = {
  baby: "아기 이름",
  rename: "개명 이름",
  stage: "예명·활동명",
  brand: "상호명·브랜드명",
};

export interface NamingPurpose {
  mode: NamingMode;
  desiredImage?: string;
  avoidSounds?: string;
  purposeNote?: string;
}

export type SoundElementRelation = "상생" | "상극" | "같음";

export interface SyllableSound {
  syllable: string;
  choseong: string;
  element: Element;
  elementLabel: string;
}

export interface NameSoundAnalysis {
  school: SoundElementSchool;
  schoolLabel: string;
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
export function analyzeNameSound(name: string, school: SoundElementSchool = "full-name"): NameSoundAnalysis {
  const allChars = [...name].filter((ch) => choseongOf(ch) !== null);
  // 일부 작명 관점은 성을 고정값으로 보고 이름 두 글자의 흐름을 더 중시한다.
  // 성이 포함된 3글자 이상 이름에서만 첫 글자를 제외하고, 2글자 이름은 전체를 본다.
  const chars = school === "given-name" && allChars.length >= 3 ? allChars.slice(1) : allChars;
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
    note = `${SOUND_ELEMENT_SCHOOL_LABEL[school]}으로 볼 때, 이름을 이루는 소리의 기운이 서로 밀어주는 흐름이라 부르고 불릴 때 자연스럽게 이어집니다.`;
  } else if (sanggeuk > sangsaeng) {
    harmony = "다소 부딪힘";
    note = `${SOUND_ELEMENT_SCHOOL_LABEL[school]}으로 볼 때, 소리의 기운이 몇 군데서 엇갈립니다. 나쁜 이름이라는 뜻은 아니고, 부드러운 애칭이나 소리 배치를 함께 고려하면 균형을 보완할 수 있습니다.`;
  } else {
    harmony = "무난함";
    note = `${SOUND_ELEMENT_SCHOOL_LABEL[school]}으로 볼 때, 소리의 기운이 크게 부딪히지 않는 무난한 배열입니다.`;
  }

  return { school, schoolLabel: SOUND_ELEMENT_SCHOOL_LABEL[school], syllables, relations, harmony, note };
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

// 발음오행 → 대표 초성 (이름 추천에서 어울리는 소리를 안내할 때 사용)
const ELEMENT_CHOSEONG: Record<Element, string[]> = {
  wood: ["ㄱ", "ㅋ"],
  fire: ["ㄴ", "ㄷ", "ㄹ", "ㅌ"],
  earth: ["ㅇ", "ㅎ"],
  metal: ["ㅅ", "ㅈ", "ㅊ"],
  water: ["ㅁ", "ㅂ", "ㅍ"],
};

/** 특정 오행을 상생으로 살려주는(생하는) 오행을 찾는다. 예: 화를 살리는 것은 목. */
function generatorOf(target: Element): Element {
  return (Object.keys(GENERATES) as Element[]).find((el) => GENERATES[el] === target) ?? target;
}

/**
 * 사주에서 보완하면 좋은 기운을 근거로, 이름에 어울리는 소리(발음오행)의 방향을 결정론적으로 정리한다.
 * 실제 이름 후보 생성은 상위(AI)에서 이 브리프를 근거로만 하게 한다.
 */
export interface NamingBrief {
  neededElement: Element;
  neededLabel: string;
  avoidElement: Element | null;
  avoidLabel: string | null;
  /** 보완 기운을 직접 담는 초성 */
  recommendedChoseong: string[];
  /** 보완 기운을 상생으로 살려주는 기운과 초성 */
  supportingElement: Element;
  supportingLabel: string;
  supportingChoseong: string[];
  /** 과하면 부담이 되는(피하면 좋은) 초성 */
  cautionChoseong: string[];
  note: string;
}

export function buildNamingBrief(chart: SajuChart): NamingBrief {
  const guide = buildLifestyleGuide(chart);
  const neededElement = guide.basisElement;
  const avoidElement = guide.avoidElement;
  const supportingElement = generatorOf(neededElement);

  const neededLabel = ELEMENT_KO[neededElement];
  const supportingLabel = ELEMENT_KO[supportingElement];
  const avoidLabel = avoidElement ? ELEMENT_KO[avoidElement] : null;

  // 상생 기운(supporting)이 곧 부담 기운(avoid)과 같으면 추천/주의가 모순되므로,
  // 그 경우엔 상생 초성을 추천에서 빼고 주의로만 남긴다. 보완 기운 자체가 부담과 같은
  // 비정상 케이스에서는 주의를 비운다.
  const supportConflict = avoidElement != null && supportingElement === avoidElement;
  const recommendedChoseong = ELEMENT_CHOSEONG[neededElement];
  const supportingChoseong = supportConflict ? [] : ELEMENT_CHOSEONG[supportingElement];
  const cautionChoseong =
    avoidElement && avoidElement !== neededElement
      ? ELEMENT_CHOSEONG[avoidElement].filter((c) => !recommendedChoseong.includes(c))
      : [];

  const parts: string[] = [
    `이 사주에는 ${neededLabel} 기운을 보완하면 균형에 도움이 됩니다.`,
  ];
  if (supportingChoseong.length > 0) {
    parts.push(
      `그래서 이름 소리에 ${neededLabel} 기운(${recommendedChoseong.join("·")}) 또는 그 기운을 살려주는 ${supportingLabel} 기운(${supportingChoseong.join("·")})의 초성을 넣으면 잘 어울립니다.`,
    );
  } else {
    parts.push(`그래서 이름 소리에 ${neededLabel} 기운(${recommendedChoseong.join("·")})의 초성을 넣으면 잘 어울립니다.`);
  }
  if (cautionChoseong.length > 0) {
    parts.push(`반대로 ${avoidLabel} 기운(${cautionChoseong.join("·")})으로만 몰리는 소리는 피하는 편이 좋습니다.`);
  }
  const note = parts.join(" ");

  return {
    neededElement,
    neededLabel,
    avoidElement,
    avoidLabel,
    recommendedChoseong,
    supportingElement,
    supportingLabel,
    supportingChoseong,
    cautionChoseong,
    note,
  };
}

export interface NamingRecommendOptions {
  purpose: NamingPurpose;
  school: SoundElementSchool;
  /** 성(姓). 아기·개명이면 보통 필수, 예명·브랜드는 생략 가능 */
  surname?: string;
  /** 성별 선호: 남아/여아/중성 등 자유 입력 */
  gender?: string;
  /** 이름 글자 수 (성 제외), 미지정이면 2 */
  syllableCount?: number;
  /** 원하는 이름 후보 개수 */
  count?: number;
}

export type NameOverall = "좋음" | "보통" | "주의";

export interface NameEvaluation {
  name: string;
  purpose?: NamingPurpose;
  school: SoundElementSchool;
  schoolLabel: string;
  sound: NameSoundAnalysis;
  fit: NameSajuFit;
  suri: SuriResult | null;
  /** 후보 이름 비교용 내부 점수. 길흉 단정이 아니라 정렬 기준이다. */
  score: number;
  overall: NameOverall;
  headline: string;
}

/** 이름 종합 감정: 발음오행 흐름 + 사주 보완 적합도 (+ 있으면 수리). */
export function evaluateName(
  chart: SajuChart,
  name: string,
  strokes?: number[],
  school: SoundElementSchool = "full-name",
  purpose?: NamingPurpose,
): NameEvaluation {
  const sound = analyzeNameSound(name, school);
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

  return { name, purpose, school, schoolLabel: SOUND_ELEMENT_SCHOOL_LABEL[school], sound, fit, suri, score, overall, headline };
}

export interface NameCandidateInput {
  name: string;
  strokes?: number[];
}

export interface NameComparison {
  candidates: NameEvaluation[];
  recommended: NameEvaluation;
  summary: string;
}

// ── 이름 추천 결과 구조화 (AI가 후보만 뽑고, 점수는 여기서 결정론적으로 매긴다) ──

/** AI가 JSON으로 돌려주는 이름 후보 1건 (점수는 담지 않는다). */
export interface RawRecommendedName {
  /** 성을 제외한 이름 부분 */
  name: string;
  hanja?: string;
  hanjaMeaning?: string;
  /** 소리(발음오행) 근거 한 줄 */
  sound?: string;
  /** 부르는 느낌·인상 한 줄 */
  image?: string;
}

export interface RecommendedNamesPayload {
  direction?: string;
  candidates: RawRecommendedName[];
}

/** 점수까지 매겨진 추천 이름 (표·카드 렌더용). */
export interface ScoredRecommendedName {
  rank: number;
  givenName: string;
  fullName: string;
  hanja?: string;
  hanjaMeaning?: string;
  sound?: string;
  image?: string;
  evaluation: NameEvaluation;
  /** 100점 환산 표시 점수. 길흉 단정이 아니라 정렬·비교용 지표다. */
  displayScore: number;
}

/**
 * 이름 감정 결과를 100점 환산 표시 점수로 바꾼다.
 * 사주 보완 적합도(비중 큼)와 발음 조화를 결정론적으로 합산한다. AI가 지어낸 점수가 아니다.
 */
export function namingDisplayScore(ev: NameEvaluation): number {
  let s = 55;

  // 사주 보완 적합도 (비중 큼)
  if (ev.fit.suppliesNeeded) s += 16;
  else if (ev.fit.supportsNeeded) s += 9;
  s += ev.fit.level === "좋음" ? 8 : ev.fit.level === "보통" ? 3 : 0;
  if (ev.fit.leansAvoid) s -= 12;

  // 소리 흐름: 상생/상극 관계 개수로 세밀하게 (이름마다 음절 조합이 달라 점수가 벌어진다)
  const rels = ev.sound.relations;
  const sangsaeng = rels.filter((r) => r.relation === "상생").length;
  const sanggeuk = rels.filter((r) => r.relation === "상극").length;
  s += sangsaeng * 5 - sanggeuk * 6;

  // 보완 기운을 담은 음절 수 (한 번 담으면 충분, 과하게 몰리면 가점 줄임)
  const needCount = ev.sound.syllables.filter((sy) => sy.element === ev.fit.neededElement).length;
  s += needCount === 1 ? 7 : needCount >= 2 ? 4 : 0;

  // 부담 기운 음절이 섞일수록 감점
  if (ev.fit.avoidElement) {
    const avoidCount = ev.sound.syllables.filter((sy) => sy.element === ev.fit.avoidElement).length;
    s -= avoidCount * 4;
  }

  // 획수 수리(입력 시)
  if (ev.suri) {
    const lucky = ev.suri.levels.filter((l) => l.level === "길").length;
    s += lucky >= 3 ? 3 : lucky === 0 ? -3 : 0;
  }

  return Math.max(40, Math.min(99, s));
}

function coerceCandidate(c: unknown): RawRecommendedName | null {
  if (!c || typeof c !== "object") return null;
  const r = c as Record<string, unknown>;
  if (typeof r.name !== "string" || !r.name.trim()) return null;
  const str = (v: unknown) => (typeof v === "string" && v.trim() ? v.trim() : undefined);
  return {
    name: r.name.trim(),
    hanja: str(r.hanja),
    hanjaMeaning: str(r.hanjaMeaning),
    sound: str(r.sound),
    image: str(r.image),
  };
}

/**
 * AI 응답 문자열에서 이름 후보 JSON을 뽑아낸다.
 * 응답이 max_tokens로 잘려 JSON이 미완성이어도, 완성된 후보 객체만이라도 복구한다.
 * (잘린 raw JSON을 화면에 그대로 노출하지 않기 위한 방어선)
 */
export function parseRecommendedNames(raw: string): RecommendedNamesPayload | null {
  let direction: string | undefined;
  let rawCandidates: unknown[] = [];

  // 1) 정상 케이스: 통째로 파싱
  const start = raw.indexOf("{");
  const end = raw.lastIndexOf("}");
  if (start >= 0 && end > start) {
    try {
      const obj = JSON.parse(raw.slice(start, end + 1)) as { direction?: unknown; candidates?: unknown };
      if (obj && Array.isArray(obj.candidates)) {
        rawCandidates = obj.candidates;
        if (typeof obj.direction === "string") direction = obj.direction;
      }
    } catch {
      // 잘렸을 수 있음 → 아래 복구 로직으로
    }
  }

  // 2) 복구 케이스: 완성된 후보 객체({...})를 하나씩 회수
  if (rawCandidates.length === 0) {
    const dm = raw.match(/"direction"\s*:\s*"((?:[^"\\]|\\.)*)"/);
    if (dm) {
      try {
        direction = JSON.parse(`"${dm[1]}"`) as string;
      } catch {
        direction = dm[1];
      }
    }
    // "name"을 포함한 평평한 객체만 매칭(중괄호 미포함). 잘린 마지막 객체는 자동 제외됨.
    const objRe = /\{[^{}]*?"name"\s*:[^{}]*?\}/g;
    let m: RegExpExecArray | null;
    while ((m = objRe.exec(raw)) !== null) {
      try {
        rawCandidates.push(JSON.parse(m[0]));
      } catch {
        /* 개별 객체 파싱 실패는 건너뜀 */
      }
    }
  }

  const candidates = rawCandidates.map(coerceCandidate).filter((c): c is RawRecommendedName => c !== null);
  if (candidates.length === 0) return null;
  return {
    direction: direction && direction.trim() ? direction.trim() : undefined,
    candidates,
  };
}

/** AI 후보를 사주 차트로 채점·정렬한다. 중복 이름은 제거한다. */
export function scoreRecommendedNames(
  chart: SajuChart,
  payload: RecommendedNamesPayload,
  options: { surname?: string; school?: SoundElementSchool; purpose?: NamingPurpose },
): ScoredRecommendedName[] {
  const surname = options.surname?.trim() ?? "";
  const seen = new Set<string>();
  const scored = payload.candidates
    .filter((c) => {
      if (seen.has(c.name)) return false;
      seen.add(c.name);
      return true;
    })
    .map((c) => {
      const fullName = surname ? `${surname}${c.name}` : c.name;
      const evaluation = evaluateName(chart, fullName, undefined, options.school ?? "full-name", options.purpose);
      return {
        givenName: c.name,
        fullName,
        hanja: c.hanja,
        hanjaMeaning: c.hanjaMeaning,
        sound: c.sound,
        image: c.image,
        evaluation,
        displayScore: namingDisplayScore(evaluation),
      };
    });
  scored.sort((a, b) => {
    if (b.displayScore !== a.displayScore) return b.displayScore - a.displayScore;
    return a.fullName.localeCompare(b.fullName, "ko");
  });
  return scored.map((s, index) => ({ ...s, rank: index + 1 }));
}

export function compareNames(
  chart: SajuChart,
  candidates: NameCandidateInput[],
  school: SoundElementSchool = "full-name",
  purpose?: NamingPurpose,
): NameComparison {
  const evaluations = candidates
    .map((candidate) => ({ ...candidate, name: candidate.name.trim() }))
    .filter((candidate) => candidate.name.length > 0)
    .map((candidate) => evaluateName(chart, candidate.name, candidate.strokes, school, purpose));

  if (evaluations.length === 0) {
    throw new Error("비교할 이름이 필요합니다.");
  }

  const sorted = [...evaluations].sort((a, b) => {
    if (b.score !== a.score) return b.score - a.score;
    const levelRank: Record<NameOverall, number> = { 좋음: 3, 보통: 2, 주의: 1 };
    if (levelRank[b.overall] !== levelRank[a.overall]) return levelRank[b.overall] - levelRank[a.overall];
    return a.name.localeCompare(b.name, "ko");
  });
  const recommended = sorted[0];
  const topTies = sorted.filter((candidate) => candidate.score === recommended.score);
  const summary =
    topTies.length > 1
      ? `${topTies.map((candidate) => candidate.name).join(", ")} 후보가 비슷하게 앞서 있습니다. 이름의 느낌과 실제로 부르기 편한지도 함께 보세요.`
      : `${recommended.name} 후보가 계산상 가장 균형 있게 나왔습니다. 단, 이름 선택은 소리·뜻·가족의 선호까지 함께 보는 편이 좋습니다.`;

  return { candidates: sorted, recommended, summary };
}
