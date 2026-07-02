import { Lunar, Solar } from "lunar-javascript";
import type {
  BirthInfo,
  FiveElementBalance,
  LuckCycles,
  SajuChart,
  SajuPillar,
  StrengthAssessment,
  TimeCorrection,
  YongshinCandidates,
} from "../types";

import { BIRTH_PLACES } from "../data/birthPlaces";

// 한국 서머타임 시행 기간 (시계가 1시간 빨랐던 기간 → 사주 계산 시 -60분)
// 주의: 경계일 출생자는 출생 시각 기준 재확인이 필요할 수 있다
const DST_PERIODS: Array<[string, string]> = [
  ["1948-06-01", "1948-09-13"],
  ["1949-04-03", "1949-09-11"],
  ["1950-04-01", "1950-09-10"],
  ["1951-05-06", "1951-09-09"],
  ["1955-05-05", "1955-09-09"],
  ["1956-05-20", "1956-09-30"],
  ["1957-05-05", "1957-09-22"],
  ["1958-05-04", "1958-09-21"],
  ["1959-05-03", "1959-09-20"],
  ["1960-05-01", "1960-09-18"],
  ["1987-05-10", "1987-10-11"],
  ["1988-05-08", "1988-10-09"],
];

// 한국 표준시 기준 경선: 1954-03-21 ~ 1961-08-09 는 동경 127.5도(UTC+8:30)였다
function standardMeridianFor(dateStr: string): number {
  return dateStr >= "1954-03-21" && dateStr <= "1961-08-09" ? 127.5 : 135;
}

function pad2(n: number): string {
  return String(n).padStart(2, "0");
}

interface CorrectedBirth {
  year: number;
  month: number;
  day: number;
  hour: number;
  minute: number;
  correction: TimeCorrection | null;
}

/**
 * 출생 시각을 사주 계산용 시각으로 보정한다.
 * 1. 음력 입력이면 먼저 양력으로 변환
 * 2. 서머타임 기간이면 -60분 (시계가 실제보다 1시간 빨랐음)
 * 3. 출생지 경도와 당시 표준시 기준 경선의 차이만큼 보정 (진태양시 근사)
 * 시간을 모르면 보정 없이 날짜만 정규화한다.
 */
export function correctBirthTime(birthInfo: BirthInfo): CorrectedBirth {
  const { calendarType, year, month, day, hour } = birthInfo;
  const minute = birthInfo.minute ?? 0;

  // 음력 → 양력 정규화
  let sy = year;
  let sm = month;
  let sd = day;
  if (calendarType === "lunar") {
    const solar = Lunar.fromYmdHms(year, month, day, hour ?? 12, minute, 0).getSolar();
    sy = solar.getYear();
    sm = solar.getMonth();
    sd = solar.getDay();
  }

  if (hour === null) {
    return { year: sy, month: sm, day: sd, hour: 12, minute: 0, correction: null };
  }

  const dateStr = `${sy}-${pad2(sm)}-${pad2(sd)}`;
  const applied: string[] = [];
  let offsetMinutes = 0;

  if (DST_PERIODS.some(([start, end]) => dateStr >= start && dateStr <= end)) {
    offsetMinutes -= 60;
    applied.push("서머타임 -60분");
  }

  const place = birthInfo.birthPlace && birthInfo.birthPlace !== "none" ? BIRTH_PLACES[birthInfo.birthPlace] : null;
  if (place) {
    const meridian = standardMeridianFor(dateStr);
    const lonOffset = Math.round((place.longitude - meridian) * 4);
    offsetMinutes += lonOffset;
    applied.push(
      `${place.label} 경도 보정 ${lonOffset >= 0 ? "+" : ""}${lonOffset}분${meridian === 127.5 ? " (당시 표준시 UTC+8:30 기준)" : ""}`,
    );
  }

  const dt = new Date(sy, sm - 1, sd, hour, minute);
  dt.setMinutes(dt.getMinutes() + offsetMinutes);

  const corrected = {
    year: dt.getFullYear(),
    month: dt.getMonth() + 1,
    day: dt.getDate(),
    hour: dt.getHours(),
    minute: dt.getMinutes(),
  };

  // 시주 경계(홀수시 정각) 근처 ±15분이면 시주가 바뀔 수 있음을 경고
  const minutesOfDay = corrected.hour * 60 + corrected.minute;
  let boundaryWarning: string | null = null;
  for (let boundary = 1; boundary <= 23; boundary += 2) {
    const diff = Math.abs(minutesOfDay - boundary * 60);
    if (Math.min(diff, 1440 - diff) <= 15) {
      boundaryWarning = `보정 후 시각이 시주 경계(${boundary}시)와 ${Math.min(diff, 1440 - diff)}분 차이라 시주가 달라질 수 있습니다. 출생 시각을 분 단위로 확인해보세요.`;
      break;
    }
  }

  const correction: TimeCorrection | null =
    applied.length > 0 || boundaryWarning
      ? {
          applied,
          correctedDateTime: `${corrected.year}-${pad2(corrected.month)}-${pad2(corrected.day)} ${pad2(corrected.hour)}:${pad2(corrected.minute)}`,
          boundaryWarning,
        }
      : null;

  return { ...corrected, correction };
}

/** 보정된 시각으로 Lunar 객체를 만든다 (모든 계산의 공통 진입점) */
function birthToLunar(birthInfo: BirthInfo): { lunar: Lunar; correction: TimeCorrection | null } {
  const c = correctBirthTime(birthInfo);
  return {
    lunar: Solar.fromYmdHms(c.year, c.month, c.day, c.hour, c.minute, 0).getLunar(),
    correction: c.correction,
  };
}

// 천간/지지 별 오행 매핑 (고정된 전통 배속, 라이브러리 버전에 의존하지 않음)
const GAN_WUXING: Record<string, keyof FiveElementBalance> = {
  갑: "wood",
  을: "wood",
  병: "fire",
  정: "fire",
  무: "earth",
  기: "earth",
  경: "metal",
  신: "metal",
  임: "water",
  계: "water",
};

const ZHI_WUXING: Record<string, keyof FiveElementBalance> = {
  자: "water",
  축: "earth",
  인: "wood",
  묘: "wood",
  진: "earth",
  사: "fire",
  오: "fire",
  미: "earth",
  신: "metal",
  유: "metal",
  술: "earth",
  해: "water",
};

// lunar-javascript 는 한자(甲子 등)를 반환하므로 한글 표기로 변환한다
const HANJA_TO_HANGUL: Record<string, string> = {
  甲: "갑",
  乙: "을",
  丙: "병",
  丁: "정",
  戊: "무",
  己: "기",
  庚: "경",
  辛: "신",
  壬: "임",
  癸: "계",
  子: "자",
  丑: "축",
  寅: "인",
  卯: "묘",
  辰: "진",
  巳: "사",
  午: "오",
  未: "미",
  申: "신",
  酉: "유",
  戌: "술",
  亥: "해",
};

function toHangul(hanja: string): string {
  return [...hanja].map((ch) => HANJA_TO_HANGUL[ch] ?? ch).join("");
}

// ── 음양 (천간: 갑병무경임=양 / 지지: 자인진오신술=양) ──────────
const YANG_GAN = new Set(["갑", "병", "무", "경", "임"]);
const YANG_ZHI = new Set(["자", "인", "진", "오", "신", "술"]);

// ── 지장간 (여기·중기·정기, 마지막이 정기) ──────────
const HIDDEN_STEMS: Record<string, string[]> = {
  자: ["임", "계"],
  축: ["계", "신", "기"],
  인: ["무", "병", "갑"],
  묘: ["갑", "을"],
  진: ["을", "계", "무"],
  사: ["무", "경", "병"],
  오: ["병", "기", "정"],
  미: ["정", "을", "기"],
  신: ["무", "임", "경"],
  유: ["경", "신"],
  술: ["신", "정", "무"],
  해: ["무", "갑", "임"],
};

const ELEMENT_KO: Record<keyof FiveElementBalance, string> = {
  wood: "목",
  fire: "화",
  earth: "토",
  metal: "금",
  water: "수",
};

// 오행 상생: 목→화→토→금→수→목
const GENERATES: Record<keyof FiveElementBalance, keyof FiveElementBalance> = {
  wood: "fire",
  fire: "earth",
  earth: "metal",
  metal: "water",
  water: "wood",
};

// 오행 상극: 목→토, 토→수, 수→화, 화→금, 금→목
const OVERCOMES: Record<keyof FiveElementBalance, keyof FiveElementBalance> = {
  wood: "earth",
  earth: "water",
  water: "fire",
  fire: "metal",
  metal: "wood",
};

/**
 * 일간과 대상 천간의 관계로 십성을 판정한다 (전통 규칙).
 * 오행 관계(비겁/인성/식상/재성/관성) × 음양 동이(편/정)로 결정된다.
 */
export function tenGodOf(dayGan: string, targetGan: string): string {
  const dayEl = GAN_WUXING[dayGan];
  const targetEl = GAN_WUXING[targetGan];
  if (!dayEl || !targetEl) return "?";
  const samePolarity = YANG_GAN.has(dayGan) === YANG_GAN.has(targetGan);

  if (targetEl === dayEl) return samePolarity ? "비견" : "겁재";
  if (GENERATES[targetEl] === dayEl) return samePolarity ? "편인" : "정인";
  if (GENERATES[dayEl] === targetEl) return samePolarity ? "식신" : "상관";
  if (OVERCOMES[dayEl] === targetEl) return samePolarity ? "편재" : "정재";
  return samePolarity ? "편관" : "정관";
}

// ── 12운성 (일간 기준: 양간 순행, 음간 역행) ──────────
const TWELVE_STAGES = ["장생", "목욕", "관대", "건록", "제왕", "쇠", "병", "사", "묘", "절", "태", "양"];
const BRANCH_ORDER = ["자", "축", "인", "묘", "진", "사", "오", "미", "신", "유", "술", "해"];
const GAN_ORDER = ["갑", "을", "병", "정", "무", "기", "경", "신", "임", "계"];
// 각 일간의 장생 지지
const CHANGSHENG: Record<string, string> = {
  갑: "해",
  병: "인",
  무: "인",
  경: "사",
  임: "신",
  을: "오",
  정: "유",
  기: "유",
  신: "자",
  계: "묘",
};

export function twelveStageOf(dayGan: string, zhi: string): string {
  const start = BRANCH_ORDER.indexOf(CHANGSHENG[dayGan] ?? "");
  const target = BRANCH_ORDER.indexOf(zhi);
  if (start < 0 || target < 0) return "?";
  const steps = YANG_GAN.has(dayGan) ? (target - start + 12) % 12 : (start - target + 12) % 12;
  return TWELVE_STAGES[steps];
}

/** 일주의 순중공망 지지 2개 (60갑자 순 기준) */
export function gongmangOf(dayGan: string, dayZhi: string): string {
  const g = GAN_ORDER.indexOf(dayGan);
  const z = BRANCH_ORDER.indexOf(dayZhi);
  if (g < 0 || z < 0) return "?";
  let i = g;
  while (i % 12 !== z) i += 10; // 60갑자에서 일주의 인덱스 찾기
  const decadeStart = Math.floor(i / 10) * 10;
  return BRANCH_ORDER[(decadeStart + 10) % 12] + BRANCH_ORDER[(decadeStart + 11) % 12];
}

/** 조후(계절 조화) 관점의 간단 노트 — 월지 계절 기준 */
function seasonNoteOf(monthZhi: string, dayGan: string): string {
  const dayEl = ELEMENT_KO[GAN_WUXING[dayGan]];
  if (["해", "자", "축"].includes(monthZhi))
    return `겨울(${monthZhi}월) 출생 — 한랭한 계절이라 조후상 화(따뜻함)의 역할이 중요. 일간 ${dayGan}(${dayEl}) 기준.`;
  if (["사", "오", "미"].includes(monthZhi))
    return `여름(${monthZhi}월) 출생 — 더운 계절이라 조후상 수(식힘)의 역할이 중요. 일간 ${dayGan}(${dayEl}) 기준.`;
  if (["인", "묘", "진"].includes(monthZhi))
    return `봄(${monthZhi}월) 출생 — 목 기운이 왕성한 계절. 일간 ${dayGan}(${dayEl}) 기준으로 계절 기운과의 관계를 본다.`;
  return `가을(${monthZhi}월) 출생 — 금 기운이 왕성한 계절. 일간 ${dayGan}(${dayEl}) 기준으로 계절 기운과의 관계를 본다.`;
}

// ── 합충형파해 짝 테이블 ──────────
const GAN_HE: Record<string, string> = { 갑기: "토", 을경: "금", 병신: "수", 정임: "목", 무계: "화" };
const ZHI_LIUHE: Record<string, string> = { 자축: "토", 인해: "목", 묘술: "화", 진유: "금", 사신: "수", 오미: "화" };
const ZHI_CHONG = new Set(["자오", "축미", "인신", "묘유", "진술", "사해"]);
const ZHI_XING = new Set(["인사", "사신", "인신", "축술", "술미", "축미", "자묘"]);
const ZHI_SELF_XING = new Set(["진", "오", "유", "해"]);
const ZHI_PO = new Set(["자유", "축진", "인해", "묘오", "사신", "술미"]);
const ZHI_HAI = new Set(["자미", "축오", "인사", "묘진", "신해", "유술"]);
// 삼합 [왕지 포함 3글자, 결과 오행]
const SANHE: Array<{ group: string[]; wangZhi: string; element: string }> = [
  { group: ["인", "오", "술"], wangZhi: "오", element: "화" },
  { group: ["사", "유", "축"], wangZhi: "유", element: "금" },
  { group: ["신", "자", "진"], wangZhi: "자", element: "수" },
  { group: ["해", "묘", "미"], wangZhi: "묘", element: "목" },
];
const FANGHE: Array<{ group: string[]; element: string }> = [
  { group: ["인", "묘", "진"], element: "목" },
  { group: ["사", "오", "미"], element: "화" },
  { group: ["신", "유", "술"], element: "금" },
  { group: ["해", "자", "축"], element: "수" },
];

function pairKey(a: string, b: string): string {
  // 테이블이 한 방향으로만 정의되어 있어 양방향 모두 확인한다
  return a + b;
}

interface PositionedChar {
  label: string;
  char: string;
}

/** 4주(또는 3주)의 천간합·지지 합충형파해를 모두 찾아 사람이 읽을 수 있는 목록으로 반환 */
function computeInteractions(gans: PositionedChar[], zhis: PositionedChar[]): string[] {
  const found: string[] = [];

  for (let i = 0; i < gans.length; i++) {
    for (let j = i + 1; j < gans.length; j++) {
      const a = gans[i];
      const b = gans[j];
      const he = GAN_HE[pairKey(a.char, b.char)] ?? GAN_HE[pairKey(b.char, a.char)];
      if (he) found.push(`${a.label}-${b.label} ${a.char}${b.char}합(${he})`);
    }
  }

  // 테이블에 정의된 정식 명칭 순서(예: 자오충)로 표기하기 위해 매칭된 키를 그대로 쓴다
  const matchKey = (set: Set<string>, keys: string[]) => keys.find((k) => set.has(k));

  for (let i = 0; i < zhis.length; i++) {
    for (let j = i + 1; j < zhis.length; j++) {
      const a = zhis[i];
      const b = zhis[j];
      const keys = [pairKey(a.char, b.char), pairKey(b.char, a.char)];
      const liuheKey = keys.find((k) => ZHI_LIUHE[k] !== undefined);
      if (liuheKey) found.push(`${a.label}-${b.label} ${liuheKey}합(${ZHI_LIUHE[liuheKey]})`);
      const chong = matchKey(ZHI_CHONG, keys);
      if (chong) found.push(`${a.label}-${b.label} ${chong}충`);
      const xing = matchKey(ZHI_XING, keys);
      if (xing) found.push(`${a.label}-${b.label} ${xing}형`);
      if (a.char === b.char && ZHI_SELF_XING.has(a.char))
        found.push(`${a.label}-${b.label} ${a.char}${a.char} 자형`);
      const po = matchKey(ZHI_PO, keys);
      if (po) found.push(`${a.label}-${b.label} ${po}파`);
      const hai = matchKey(ZHI_HAI, keys);
      if (hai) found.push(`${a.label}-${b.label} ${hai}해`);
    }
  }

  const present = new Set(zhis.map((z) => z.char));
  for (const { group, wangZhi, element } of SANHE) {
    const hits = group.filter((g) => present.has(g));
    if (hits.length === 3) {
      found.push(`지지 ${group.join("")} 삼합(${element})`);
    } else if (hits.length === 2 && hits.includes(wangZhi)) {
      found.push(`지지 ${hits.join("")} 반합(${element})`);
    }
  }
  for (const { group, element } of FANGHE) {
    if (group.every((g) => present.has(g))) found.push(`지지 ${group.join("")} 방합(${element})`);
  }

  return found;
}

// 간이 억부법: 위치별 가중치 (월지가 가장 큼 = 계절의 힘)
const STRENGTH_WEIGHTS = { 연간: 1, 연지: 1.2, 월간: 1.2, 월지: 2.5, 일지: 1.5, 시간: 1, 시지: 1.2 };

function assessStrength(
  dayGan: string,
  gans: PositionedChar[],
  zhis: PositionedChar[],
): StrengthAssessment {
  const dayEl = GAN_WUXING[dayGan];
  const helpsDay = (el: keyof FiveElementBalance | undefined) =>
    el !== undefined && (el === dayEl || GENERATES[el] === dayEl);

  let supportScore = 0;
  let totalScore = 0;
  const supporters: string[] = [];

  for (const { label, char } of gans) {
    if (label === "일간") continue;
    const w = STRENGTH_WEIGHTS[label as keyof typeof STRENGTH_WEIGHTS] ?? 1;
    totalScore += w;
    if (helpsDay(GAN_WUXING[char])) {
      supportScore += w;
      supporters.push(`${label} ${char}`);
    }
  }
  for (const { label, char } of zhis) {
    const w = STRENGTH_WEIGHTS[label as keyof typeof STRENGTH_WEIGHTS] ?? 1;
    totalScore += w;
    if (helpsDay(ZHI_WUXING[char])) {
      supportScore += w;
      supporters.push(`${label} ${char}`);
    }
  }

  const ratio = supportScore / totalScore;
  const label: StrengthAssessment["label"] = ratio >= 0.5 ? "신강" : ratio <= 0.35 ? "신약" : "중화";

  const monthZhi = zhis.find((z) => z.label === "월지");
  const deLing = monthZhi ? helpsDay(ZHI_WUXING[monthZhi.char]) : false;
  const detail = [
    `일간을 돕는 세력(비겁·인성): ${supporters.length > 0 ? supporters.join(", ") : "없음"}`,
    `월지 ${monthZhi?.char ?? "?"}은(는) 일간을 ${deLing ? "돕는 오행 (득령)" : "돕지 않는 오행 (실령)"}`,
    `점수 ${supportScore.toFixed(1)}/${totalScore.toFixed(1)} (위치 가중치 기반 간이 판정)`,
  ].join(" · ");

  return { supportScore, totalScore, label, detail };
}

function suggestYongshin(dayGan: string, strength: StrengthAssessment, fiveElements: FiveElementBalance): YongshinCandidates {
  const dayEl = GAN_WUXING[dayGan];
  const inseong = (Object.keys(GENERATES) as Array<keyof FiveElementBalance>).find((el) => GENERATES[el] === dayEl)!;
  const sikSang = GENERATES[dayEl];
  const jaeSeong = OVERCOMES[dayEl];
  const gwanSeong = (Object.keys(OVERCOMES) as Array<keyof FiveElementBalance>).find((el) => OVERCOMES[el] === dayEl)!;

  const note =
    "간이 억부법 기준 후보이며, 조후(계절 조화) 등 다른 관법으로는 달라질 수 있는 참고용입니다.";

  if (strength.label === "신약") {
    return {
      supportive: [ELEMENT_KO[inseong], ELEMENT_KO[dayEl]],
      unfavorable: [ELEMENT_KO[gwanSeong], ELEMENT_KO[jaeSeong], ELEMENT_KO[sikSang]],
      note: `신약 → 일간을 돕는 인성(${ELEMENT_KO[inseong]})·비겁(${ELEMENT_KO[dayEl]})이 용신 후보. ${note}`,
    };
  }
  if (strength.label === "신강") {
    return {
      supportive: [ELEMENT_KO[sikSang], ELEMENT_KO[jaeSeong], ELEMENT_KO[gwanSeong]],
      unfavorable: [ELEMENT_KO[dayEl], ELEMENT_KO[inseong]],
      note: `신강 → 힘을 덜어내는 식상(${ELEMENT_KO[sikSang]})·재성(${ELEMENT_KO[jaeSeong]})·관성(${ELEMENT_KO[gwanSeong]})이 용신 후보. ${note}`,
    };
  }

  const entries = Object.entries(fiveElements) as Array<[keyof FiveElementBalance, number]>;
  const min = Math.min(...entries.map(([, v]) => v));
  const lacking = entries.filter(([, v]) => v === min).map(([el]) => ELEMENT_KO[el]);
  return {
    supportive: lacking,
    unfavorable: [],
    note: `중화에 가까움 → 특정 용신보다 부족한 오행(${lacking.join("·")}) 보완이 우선. ${note}`,
  };
}

function toPillar(ganZhiHanja: string): SajuPillar {
  const ganZhi = toHangul(ganZhiHanja);
  return {
    gan: ganZhi[0] ?? "",
    zhi: ganZhi[1] ?? "",
    ganZhi,
  };
}

function addElement(balance: FiveElementBalance, char: string, table: Record<string, keyof FiveElementBalance>) {
  const key = table[char];
  if (key) balance[key] += 1;
}

/**
 * 생년월일시를 받아 연주/월주/일주/시주와 오행 분포, 십성을 계산한다.
 * 출생 시간을 모르면(hour === null) 시주는 계산하지 않는다.
 * (연/월/일주는 시각과 무관하므로 정오를 임시값으로 넣어 계산해도 정확하다)
 */
export function computeSajuChart(birthInfo: BirthInfo): SajuChart {
  const { hour } = birthInfo;
  const { lunar, correction } = birthToLunar(birthInfo);

  const ec = lunar.getEightChar();

  const yearPillar = toPillar(ec.getYear());
  const monthPillar = toPillar(ec.getMonth());
  const dayPillar = toPillar(ec.getDay());
  const timePillar = hour === null ? null : toPillar(ec.getTime());

  const fiveElements: FiveElementBalance = { wood: 0, fire: 0, earth: 0, metal: 0, water: 0 };
  for (const pillar of [yearPillar, monthPillar, dayPillar, timePillar]) {
    if (!pillar) continue;
    addElement(fiveElements, pillar.gan, GAN_WUXING);
    addElement(fiveElements, pillar.zhi, ZHI_WUXING);
  }

  const dayGan = dayPillar.gan;

  // 위치가 붙은 천간/지지 목록 (시주는 모르면 제외)
  const gans: PositionedChar[] = [
    { label: "연간", char: yearPillar.gan },
    { label: "월간", char: monthPillar.gan },
    { label: "일간", char: dayGan },
    ...(timePillar ? [{ label: "시간", char: timePillar.gan }] : []),
  ];
  const zhis: PositionedChar[] = [
    { label: "연지", char: yearPillar.zhi },
    { label: "월지", char: monthPillar.zhi },
    { label: "일지", char: dayPillar.zhi },
    ...(timePillar ? [{ label: "시지", char: timePillar.zhi }] : []),
  ];

  // 천간 십성 (일간 기준, 전통 규칙으로 직접 계산)
  const tenGods = gans
    .filter((g) => g.label !== "일간")
    .map((g) => `${g.label} ${g.char}: ${tenGodOf(dayGan, g.char)}`);
  if (!timePillar) tenGods.push("시간: 출생시간 모름");

  // 음양 분포
  let yang = 0;
  for (const g of gans) if (YANG_GAN.has(g.char)) yang += 1;
  for (const z of zhis) if (YANG_ZHI.has(z.char)) yang += 1;
  const totalChars = gans.length + zhis.length;

  // 지장간 + 지지 십성(정기 기준)
  const hiddenStems = zhis.map((z) => `${z.label} ${z.char}: ${(HIDDEN_STEMS[z.char] ?? []).join("·")}`);
  const branchTenGods = zhis.map((z) => {
    const stems = HIDDEN_STEMS[z.char] ?? [];
    const main = stems[stems.length - 1] ?? "";
    return `${z.label} ${z.char}(정기 ${main}): ${tenGodOf(dayGan, main)}`;
  });

  const interactions = computeInteractions(gans, zhis);
  const strength = assessStrength(dayGan, gans, zhis);
  const yongshin = suggestYongshin(dayGan, strength, fiveElements);

  const twelveStages = zhis.map((z) => `${z.label} ${z.char}: ${twelveStageOf(dayGan, z.char)}`);
  const gongmangZhis = gongmangOf(dayGan, dayPillar.zhi);
  const gongmangHits = zhis.filter((z) => gongmangZhis.includes(z.char)).map((z) => `${z.label} ${z.char}`);
  const gongmang = `${gongmangZhis} 공망${gongmangHits.length > 0 ? ` (원국 내 해당: ${gongmangHits.join(", ")})` : " (원국 내 해당 지지 없음)"}`;

  return {
    year: yearPillar,
    month: monthPillar,
    day: dayPillar,
    hour: timePillar,
    fiveElements,
    tenGods,
    dayMasterGan: dayGan,
    yinYang: { yang, yin: totalChars - yang },
    hiddenStems,
    branchTenGods,
    interactions,
    strength,
    yongshin,
    twelveStages,
    gongmang,
    seasonNote: seasonNoteOf(monthPillar.zhi, dayGan),
    timeCorrection: correction ?? undefined,
  };
}

/**
 * 대운/세운/월운을 계산한다.
 * - 대운: 만세력 기준 10년 단위 흐름 (성별에 따라 순행/역행이 달라져 gender 필요)
 * - 세운: 올해의 간지 (입춘 기준)
 * - 월운: 이번 달의 간지 (절기 기준 월주)
 */
/** 운(대운/세운 등)의 간지 하나가 원국과 새로 맺는 합충형파해를 찾는다 */
function luckVsNatal(
  label: string,
  ganZhi: string,
  natalGans: PositionedChar[],
  natalZhis: PositionedChar[],
): string[] {
  if (ganZhi.length < 2) return [];
  const base = new Set(computeInteractions(natalGans, natalZhis));
  const combined = computeInteractions(
    [{ label, char: ganZhi[0] }, ...natalGans],
    [{ label, char: ganZhi[1] }, ...natalZhis],
  );
  // 운 글자가 개입해서 "새로 생긴" 관계만 남긴다 (삼합 완성 포함)
  return combined.filter((s) => !base.has(s)).map((s) => (s.includes(label) ? s : `${label} ${ganZhi} 개입 → ${s}`));
}

export function computeLuckCycles(birthInfo: BirthInfo, now: Date = new Date()): LuckCycles {
  const { lunar } = birthToLunar(birthInfo);
  const ec = lunar.getEightChar();

  const yun = ec.getYun(birthInfo.gender === "male" ? 1 : 0);
  const nowYear = now.getFullYear();

  // 첫 항목은 대운 시작 전 구간이라 간지가 비어 있을 수 있음 → 제외
  const daYun = yun
    .getDaYun()
    .filter((dy) => dy.getGanZhi() !== "")
    .slice(0, 8)
    .map((dy) => ({
      startAge: dy.getStartAge(),
      endAge: dy.getEndAge(),
      startYear: dy.getStartYear(),
      endYear: dy.getEndYear(),
      ganZhi: toHangul(dy.getGanZhi()),
      current: dy.getStartYear() <= nowYear && nowYear <= dy.getEndYear(),
    }));

  const nowLunar = Solar.fromDate(now).getLunar();
  const currentDaYun = daYun.find((dy) => dy.current)?.ganZhi ?? null;
  const yearGanZhi = toHangul(nowLunar.getYearInGanZhiByLiChun());
  const monthGanZhi = toHangul(nowLunar.getMonthInGanZhi());
  const dayGanZhi = toHangul(nowLunar.getDayInGanZhi());

  // 원국 기둥 (운과의 상호작용 계산용)
  const yearP = toPillar(ec.getYear());
  const monthP = toPillar(ec.getMonth());
  const dayP = toPillar(ec.getDay());
  const timeP = birthInfo.hour === null ? null : toPillar(ec.getTime());
  const natalGans: PositionedChar[] = [
    { label: "연간", char: yearP.gan },
    { label: "월간", char: monthP.gan },
    { label: "일간", char: dayP.gan },
    ...(timeP ? [{ label: "시간", char: timeP.gan }] : []),
  ];
  const natalZhis: PositionedChar[] = [
    { label: "연지", char: yearP.zhi },
    { label: "월지", char: monthP.zhi },
    { label: "일지", char: dayP.zhi },
    ...(timeP ? [{ label: "시지", char: timeP.zhi }] : []),
  ];

  const luckInteractions = [
    ...(currentDaYun ? luckVsNatal(`대운 ${currentDaYun}`, currentDaYun, natalGans, natalZhis) : []),
    ...luckVsNatal(`세운 ${yearGanZhi}`, yearGanZhi, natalGans, natalZhis),
    ...luckVsNatal(`월운 ${monthGanZhi}`, monthGanZhi, natalGans, natalZhis),
    ...luckVsNatal(`일진 ${dayGanZhi}`, dayGanZhi, natalGans, natalZhis),
  ];

  return {
    daYun,
    currentDaYun,
    yearGanZhi,
    monthGanZhi,
    dayGanZhi,
    year: nowYear,
    month: now.getMonth() + 1,
    luckInteractions,
  };
}
