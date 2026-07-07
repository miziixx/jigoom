import { Lunar, Solar } from "lunar-javascript";
import type {
  BirthInfo,
  CompatibilityResult,
  CompatibilityRelationType,
  FiveElementBalance,
  GyeokgukInfo,
  LuckCycles,
  LuckOverlap,
  MonthCommand,
  MonthFlowInfo,
  PastEvent,
  PastEventCalibrationInput,
  RootednessHit,
  SajuChart,
  SajuPillar,
  SinsalHit,
  StrengthAssessment,
  TimeCorrection,
  TransparencyInfo,
  YearFlowInfo,
  YongshinCandidates,
} from "../types/index.js";

import { BIRTH_PLACES } from "../data/birthPlaces.js";
import { iljuTraitOf } from "../data/iljuTraits.js";

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

  // 음력 → 양력 정규화 (윤달이면 lunar-javascript 규약대로 월을 음수로 전달)
  let sy = year;
  let sm = month;
  let sd = day;
  if (calendarType === "lunar") {
    const lunarMonth = birthInfo.isLeapMonth ? -Math.abs(month) : month;
    const solar = Lunar.fromYmdHms(year, lunarMonth, day, hour ?? 12, minute, 0).getSolar();
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

function calculationBasisOf(birthInfo: BirthInfo) {
  const minute = birthInfo.minute ?? 0;
  return {
    lateNightZi: birthInfo.hour === 23 ? birthInfo.lateNightZi ?? "late" : undefined,
    isLateNightZiHour: birthInfo.hour === 23,
    inputTimeLabel: birthInfo.hour === null ? null : `${pad2(birthInfo.hour)}:${pad2(minute)}`,
  };
}

/**
 * 원국 사주(EightChar)를 만든다. 23~24시 출생 시 자시 처리 방식을 반영한다.
 * - 기본(야자시, lateNightZi !== "early"): 당일 일주 유지 (lunar-javascript 기본 sect 2)
 * - 조자시(lateNightZi === "early"): 자시부터 다음날 일주 (sect 1)
 */
function eightCharOf(lunar: Lunar, birthInfo: BirthInfo) {
  const ec = lunar.getEightChar();
  // setSect: 23~24시 자시 처리 유파. 타입 정의에 없어 캐스팅 (런타임 지원 확인됨)
  if (birthInfo.lateNightZi === "early") (ec as unknown as { setSect(n: number): void }).setSect(1);
  return ec;
}

// 천간/지지 별 오행 매핑 (고정된 전통 배속, 라이브러리 버전에 의존하지 않음)
export const GAN_WUXING: Record<string, keyof FiveElementBalance> = {
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

export const ZHI_WUXING: Record<string, keyof FiveElementBalance> = {
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

export function toHangul(hanja: string): string {
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

// ── 월률분야(月律分野)·사령(司令) ──────────
// 절입(節入)부터 며칠 지났는지에 따라 월지 지장간 중 어느 기운이 그 시점을 "주관(사령)"하는지 정한다.
// 일수는 HIDDEN_STEMS 배열 순서(여기→중기→정기)와 index가 맞다. (전통 월률분야 통용 일수)
//  · 生地(인신사해): 여기7·중기7·정기16   · 旺地(자묘유): 여기10·정기20   · 오(旺,3기): 병10·기9·정11   · 墓地(진술축미): 여기9·중기3·정기18
const MONTH_COMMAND_DAYS: Record<string, number[]> = {
  자: [10, 20],
  축: [9, 3, 18],
  인: [7, 7, 16],
  묘: [10, 20],
  진: [9, 3, 18],
  사: [7, 7, 16],
  오: [10, 9, 11],
  미: [9, 3, 18],
  신: [7, 7, 16],
  유: [10, 20],
  술: [9, 3, 18],
  해: [7, 7, 16],
};

/**
 * 사령(司令) 판정: 절입 경과일수로 월지 지장간 중 그 시점을 주관하는 기운을 고른다.
 * daysSinceTerm은 절입 당일=0 기준의 경과 일수(소수 가능).
 */
function commandStemOf(monthZhi: string, daysSinceTerm: number): { stem: string; phase: "정기" | "중기" | "여기"; index: number } | null {
  const stems = HIDDEN_STEMS[monthZhi];
  const spans = MONTH_COMMAND_DAYS[monthZhi];
  if (!stems || !spans) return null;
  const d = Math.max(0, daysSinceTerm);
  let acc = 0;
  for (let i = 0; i < stems.length; i++) {
    acc += spans[i];
    if (d < acc || i === stems.length - 1) {
      return { stem: stems[i], phase: hiddenStemStrength(stems, i), index: i };
    }
  }
  return null;
}

export const ELEMENT_KO: Record<keyof FiveElementBalance, string> = {
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

// ── 신살(神煞) 테이블 ──────────
// 지지가 속한 삼합국의 대표 오행 (십이신살·월덕 판정용)
const SANHE_ELEMENT: Record<string, "water" | "fire" | "metal" | "wood"> = {
  신: "water", 자: "water", 진: "water",
  인: "fire", 오: "fire", 술: "fire",
  사: "metal", 유: "metal", 축: "metal",
  해: "wood", 묘: "wood", 미: "wood",
};

// 십이신살: 기준 지지(일지)가 속한 삼합국별로 12지지 각각에 배정된다.
// (년살=도화, 역마살, 화개살, 지살 등 12개를 모두 포함)
const SIBI_SINSAL: Record<"water" | "fire" | "metal" | "wood", Record<string, string>> = {
  water: { 사: "겁살", 오: "재살", 미: "천살", 신: "지살", 유: "년살", 술: "월살", 해: "망신살", 자: "장성살", 축: "반안살", 인: "역마살", 묘: "육해살", 진: "화개살" },
  fire: { 해: "겁살", 자: "재살", 축: "천살", 인: "지살", 묘: "년살", 진: "월살", 사: "망신살", 오: "장성살", 미: "반안살", 신: "역마살", 유: "육해살", 술: "화개살" },
  metal: { 인: "겁살", 묘: "재살", 진: "천살", 사: "지살", 오: "년살", 미: "월살", 신: "망신살", 유: "장성살", 술: "반안살", 해: "역마살", 자: "육해살", 축: "화개살" },
  wood: { 신: "겁살", 유: "재살", 술: "천살", 해: "지살", 자: "년살", 축: "월살", 인: "망신살", 묘: "장성살", 진: "반안살", 사: "역마살", 오: "육해살", 미: "화개살" },
};

// 천을귀인: 일간 기준 귀인 지지
const CHEONEUL: Record<string, string[]> = {
  갑: ["축", "미"], 무: ["축", "미"], 경: ["축", "미"],
  을: ["자", "신"], 기: ["자", "신"],
  병: ["해", "유"], 정: ["해", "유"],
  임: ["묘", "사"], 계: ["묘", "사"],
  신: ["오", "인"],
};

// 양인: 일간(양간) 기준 겁재의 왕지
const YANGIN: Record<string, string> = { 갑: "묘", 병: "오", 무: "오", 경: "유", 임: "자" };

// 문창귀인: 일간 기준 식신이 록을 얻는 지지
const MUNCHANG: Record<string, string> = {
  갑: "사", 을: "오", 병: "신", 정: "유", 무: "신", 기: "유", 경: "해", 신: "자", 임: "인", 계: "묘",
};

// 학당귀인(일간 장생지) / 금여 / 암록 / 홍염살 — 모두 일간 기준 지지
const HAKDANG: Record<string, string> = { 갑: "해", 을: "오", 병: "인", 정: "유", 무: "인", 기: "유", 경: "사", 신: "자", 임: "신", 계: "묘" };
const GEUMYEO: Record<string, string> = { 갑: "진", 을: "사", 병: "미", 정: "신", 무: "미", 기: "신", 경: "술", 신: "해", 임: "축", 계: "인" };
const AMROK: Record<string, string> = { 갑: "해", 을: "술", 병: "신", 정: "미", 무: "신", 기: "미", 경: "사", 신: "진", 임: "인", 계: "축" };
const HONGYEOM: Record<string, string> = { 갑: "오", 을: "오", 병: "인", 정: "미", 무: "진", 기: "진", 경: "술", 신: "유", 임: "자", 계: "신" };

// 천덕귀인: 월지 기준. 값이 천간(gan)일 수도, 지지(zhi)일 수도 있어 구분해 둔다.
const CHEONDEOK: Record<string, { gan?: string; zhi?: string }> = {
  자: { zhi: "사" }, 축: { gan: "경" }, 인: { gan: "정" }, 묘: { zhi: "신" }, 진: { gan: "임" }, 사: { gan: "신" },
  오: { zhi: "해" }, 미: { gan: "갑" }, 신: { gan: "계" }, 유: { zhi: "인" }, 술: { gan: "병" }, 해: { gan: "을" },
};
// 월덕귀인: 월지 삼합국 오행 기준 천간
const WOLDEOK: Record<"water" | "fire" | "metal" | "wood", string> = { water: "임", fire: "병", metal: "경", wood: "갑" };

// 지지쌍 신살 (원국 안에 두 지지가 함께 있으면 성립)
const WONJIN_PAIRS: Array<[string, string]> = [["자", "미"], ["축", "오"], ["인", "유"], ["묘", "신"], ["진", "해"], ["사", "술"]];
const GWIMUN_PAIRS: Array<[string, string]> = [["자", "유"], ["축", "오"], ["인", "미"], ["묘", "신"], ["진", "해"], ["사", "술"]];

// 고신살/과숙살: 년지 방합 그룹 기준 지지
const YEAR_BANGHAP: Array<{ group: string[]; goshin: string; gwasuk: string }> = [
  { group: ["해", "자", "축"], goshin: "인", gwasuk: "술" },
  { group: ["인", "묘", "진"], goshin: "사", gwasuk: "축" },
  { group: ["사", "오", "미"], goshin: "신", gwasuk: "진" },
  { group: ["신", "유", "술"], goshin: "해", gwasuk: "미" },
];

// 백호대살 / 괴강 (기둥 간지 단위)
const BAEKHO = new Set(["갑진", "을미", "병술", "정축", "무진", "임술", "계축"]);
const GOEGANG = new Set(["경진", "경술", "무술", "임진", "임술"]);

const SINSAL_GLOSS: Record<string, string> = {
  겁살: "예기치 못한 손실·강제·빼앗김의 기운. 큰 변동을 조심",
  재살: "관재·구속·시비(수옥)의 기운. 법적 문제·다툼 주의",
  천살: "불가항력의 변수·자만을 경계하게 하는 기운",
  지살: "이동·변동·타향·활동의 기운",
  년살: "매력·인기·이성운의 기운 (도화)",
  월살: "메마름·정체·소모가 생기기 쉬운 기운 (고초)",
  망신살: "실수·구설·체면 손상이 드러나기 쉬운 기운",
  장성살: "권위·리더십·중심에 서는 기운",
  반안살: "안정·승진·후원으로 자리 잡는 길한 기운",
  역마살: "이동·변화·해외·활동의 기운",
  육해살: "은근한 방해·소모·건강 주의의 기운",
  화개살: "고독·몰입·예술·종교·연구의 기운",
  천을귀인: "귀인의 도움을 받기 쉬운 최고의 길신",
  천덕귀인: "하늘의 덕으로 위기에 도움을 받는 길신",
  월덕귀인: "달의 덕으로 인덕·보호를 받는 길신",
  양인: "강한 추진력·기세. 과하면 다툼·사고 주의",
  문창귀인: "총명·학문·시험·글재주의 길신",
  학당귀인: "학문·가르침·총명함의 길신",
  금여: "온화한 성품·배우자복·안락함의 길성",
  암록: "드러나지 않게 돕는 복록·위기 때의 귀인",
  홍염살: "매력·끼·이성에게 인기가 많은 기운 (도화 계열)",
  백호대살: "기세가 강해 성취가 크나 급변·건강 관리 필요",
  괴강: "카리스마·결단력이 강한 리더 기질",
  원진살: "이유 없이 껄끄럽고 미워지기 쉬운 감정의 기운",
  귀문관살: "예민·직관·집착·신경과민이 강해지는 기운",
  고신살: "배우자·인연이 외로워지기 쉬운 기운 (홀로)",
  과숙살: "배우자·인연이 외로워지기 쉬운 기운 (홀로)",
};

/**
 * 원국 4기둥의 신살을 폭넓게 계산한다.
 * - 십이신살(겁살·재살·천살·지살·년살·월살·망신·장성·반안·역마·육해·화개): 일지 삼합국 기준
 * - 일간 기준 지지: 천을귀인·양인·문창·학당·금여·암록·홍염
 * - 월지 기준: 천덕귀인·월덕귀인
 * - 지지쌍: 원진·귀문관
 * - 년지 기준: 고신·과숙
 * - 기둥 간지: 백호·괴강
 * 기준(관법)에 따라 신살 판정은 달라질 수 있어 참고용으로 제공한다.
 */
function computeSinsal(
  dayGan: string,
  dayZhi: string,
  monthZhi: string,
  yearZhi: string,
  gans: PositionedChar[],
  zhis: PositionedChar[],
): SinsalHit[] {
  const hits: SinsalHit[] = [];
  const glossOf = (name: string) => SINSAL_GLOSS[name] ?? "";
  const pushZhi = (name: string, char: string) => {
    for (const z of zhis) if (z.char === char) hits.push({ name, position: `${z.label} ${z.char}`, gloss: glossOf(name) });
  };
  const pushGan = (name: string, char: string) => {
    for (const g of gans) if (g.char === char) hits.push({ name, position: `${g.label} ${g.char}`, gloss: glossOf(name) });
  };

  // 십이신살 (일지 삼합국 기준)
  const dayEl = SANHE_ELEMENT[dayZhi];
  if (dayEl) {
    const map = SIBI_SINSAL[dayEl];
    for (const z of zhis) {
      const name = map[z.char];
      if (name) hits.push({ name, position: `${z.label} ${z.char}`, gloss: glossOf(name) });
    }
  }

  // 일간 기준 길신/흉살 (지지)
  for (const char of CHEONEUL[dayGan] ?? []) pushZhi("천을귀인", char);
  if (YANGIN[dayGan]) pushZhi("양인", YANGIN[dayGan]);
  if (MUNCHANG[dayGan]) pushZhi("문창귀인", MUNCHANG[dayGan]);
  if (HAKDANG[dayGan]) pushZhi("학당귀인", HAKDANG[dayGan]);
  if (GEUMYEO[dayGan]) pushZhi("금여", GEUMYEO[dayGan]);
  if (AMROK[dayGan]) pushZhi("암록", AMROK[dayGan]);
  if (HONGYEOM[dayGan]) pushZhi("홍염살", HONGYEOM[dayGan]);

  // 월지 기준 천덕/월덕귀인
  const cd = CHEONDEOK[monthZhi];
  if (cd?.zhi) pushZhi("천덕귀인", cd.zhi);
  if (cd?.gan) pushGan("천덕귀인", cd.gan);
  const monthEl = SANHE_ELEMENT[monthZhi];
  if (monthEl) pushGan("월덕귀인", WOLDEOK[monthEl]);

  // 지지쌍 (원진·귀문) — 원국 내 두 지지가 함께 있으면
  const branchSet = new Set(zhis.map((z) => z.char));
  const pairHits = (pairs: Array<[string, string]>, name: string) => {
    for (const [a, b] of pairs) {
      if (branchSet.has(a) && branchSet.has(b)) {
        const posA = zhis.find((z) => z.char === a)!;
        const posB = zhis.find((z) => z.char === b)!;
        hits.push({ name, position: `${posA.label} ${a}–${posB.label} ${b}`, gloss: glossOf(name) });
      }
    }
  };
  pairHits(WONJIN_PAIRS, "원진살");
  pairHits(GWIMUN_PAIRS, "귀문관살");

  // 년지 기준 고신/과숙
  const banghap = YEAR_BANGHAP.find((g) => g.group.includes(yearZhi));
  if (banghap) {
    pushZhi("고신살", banghap.goshin);
    pushZhi("과숙살", banghap.gwasuk);
  }

  // 백호 / 괴강 (기둥 간지)
  for (let i = 0; i < zhis.length; i++) {
    const label = zhis[i].label.replace("지", "주");
    const gz = (gans[i]?.char ?? "") + zhis[i].char;
    if (BAEKHO.has(gz)) hits.push({ name: "백호대살", position: `${label} ${gz}`, gloss: glossOf("백호대살") });
    if (GOEGANG.has(gz)) hits.push({ name: "괴강", position: `${label} ${gz}`, gloss: glossOf("괴강") });
  }

  return hits;
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
    // 신약 → 인성이 1차 용신, 비겁이 희신(용신을 돕고 일간을 직접 강화)
    const yongshin = [ELEMENT_KO[inseong]];
    const heesin = [ELEMENT_KO[dayEl]];
    return {
      supportive: [...yongshin, ...heesin],
      yongshin,
      heesin,
      unfavorable: [ELEMENT_KO[gwanSeong], ELEMENT_KO[jaeSeong], ELEMENT_KO[sikSang]],
      note: `신약 → 일간을 돕는 인성(${ELEMENT_KO[inseong]})이 1차 용신, 비겁(${ELEMENT_KO[dayEl]})이 희신 후보. ${note}`,
    };
  }
  if (strength.label === "신강") {
    // 신강 → 힘을 빼는 관성/식상이 용신, 재성이 희신(관성을 생하고 식상 흐름을 받음)
    const yongshin = [ELEMENT_KO[gwanSeong], ELEMENT_KO[sikSang]];
    const heesin = [ELEMENT_KO[jaeSeong]];
    return {
      supportive: [...yongshin, ...heesin],
      yongshin,
      heesin,
      unfavorable: [ELEMENT_KO[dayEl], ELEMENT_KO[inseong]],
      note: `신강 → 힘을 덜어내는 관성(${ELEMENT_KO[gwanSeong]})·식상(${ELEMENT_KO[sikSang]})이 용신, 재성(${ELEMENT_KO[jaeSeong]})이 희신 후보. ${note}`,
    };
  }

  const entries = Object.entries(fiveElements) as Array<[keyof FiveElementBalance, number]>;
  const min = Math.min(...entries.map(([, v]) => v));
  const lacking = entries.filter(([, v]) => v === min).map(([el]) => ELEMENT_KO[el]);
  return {
    supportive: lacking,
    yongshin: lacking,
    heesin: [],
    unfavorable: [],
    note: `중화에 가까움 → 특정 용신보다 부족한 오행(${lacking.join("·")}) 보완이 우선. ${note}`,
  };
}

// ── 격국(格局) 판정 ──────────
const GYEOKGUK_BY_TENGOD: Record<string, { name: string; gloss: string }> = {
  비견: { name: "건록격", gloss: "자립심과 주체성이 강한 구조. 스스로 개척하는 힘이 중심이에요." },
  겁재: { name: "양인격", gloss: "기세와 추진력이 강한 구조. 큰 힘을 잘 쓰면 성취가 크고, 과하면 마찰을 조심해요." },
  식신: { name: "식신격", gloss: "표현·생산·먹을 복의 구조. 꾸준히 만들어내는 힘이 재물로 이어져요." },
  상관: { name: "상관격", gloss: "재능·표현·창의의 구조. 틀을 깨는 감각이 강하지만 말·규칙 관리가 중요해요." },
  편재: { name: "편재격", gloss: "큰 재물·사업 수완의 구조. 활동 범위가 넓고 기회 포착이 빨라요." },
  정재: { name: "정재격", gloss: "성실·안정적 재물의 구조. 꾸준히 모으고 관리하는 힘이 강해요." },
  편관: { name: "편관격(칠살격)", gloss: "책임·압박·도전의 구조. 강한 추진력이 있지만 부담을 잘 다스려야 해요." },
  정관: { name: "정관격", gloss: "명예·규범·조직의 구조. 반듯하고 신뢰받는 자리에 잘 맞아요." },
  편인: { name: "편인격", gloss: "직관·전문성·독특한 학문의 구조. 몰입력이 강해요." },
  정인: { name: "정인격", gloss: "학문·명예·보호의 구조. 배우고 정리하는 힘이 강점이에요." },
};

/** 절입 경과일수로 월률분야(사령)를 조립한다. */
function buildMonthCommand(monthZhi: string, dayGan: string, daysSinceTerm: number, termName?: string): MonthCommand | null {
  const cmd = commandStemOf(monthZhi, daysSinceTerm);
  if (!cmd) return null;
  const tenGod = tenGodOf(dayGan, cmd.stem);
  const note = `${termName ? `${termName} 절입 ` : "절입 "}${daysSinceTerm.toFixed(1)}일차 — 이 시점 월지 ${monthZhi}는 ${cmd.phase} ${cmd.stem}이(가) 사령(주관)하며, 일간 ${dayGan} 기준 ${tenGod}입니다. 사령 기운은 그 사람 기질의 바탕색이 됩니다.`;
  return { monthZhi, stem: cmd.stem, phase: cmd.phase, tenGod, daysSinceTerm, termName, note };
}

/**
 * 격국(格局): 월지 지장간 중 어느 기운으로 격을 잡을지 정한다.
 * 전통 순서 — ① 월지 정기가 천간에 투출하면 정기로, ② 정기가 불투하고 중기/여기가 투출하면 그 투출자로,
 * ③ 아무것도 투출하지 않으면 그 시점을 주관하는 사령(司令)으로 (잠복격) 잡는다.
 * 사령은 절입 경과일 기준 월률분야로 판정된다(command 인자).
 */
function computeGyeokguk(
  dayGan: string,
  monthZhi: string,
  strength: StrengthAssessment,
  transparency: TransparencyInfo,
  command: MonthCommand | null,
): GyeokgukInfo {
  const stems = HIDDEN_STEMS[monthZhi] ?? [];
  const mainStem = stems[stems.length - 1] ?? "";
  const revealedStems = transparency.revealed.map((r) => r.stem);

  let basisStem = mainStem;
  let basisKind: GyeokgukInfo["basisKind"] = "사령(잠복)";
  if (revealedStems.includes(mainStem)) {
    basisStem = mainStem;
    basisKind = "정기 투출";
  } else if (revealedStems.length > 0) {
    // 정기 불투 — 투출한 지장간 중 가장 강한 위치(중기 > 여기)를 택한다
    const phaseRank = (stem: string) => {
      const p = hiddenStemStrength(stems, stems.indexOf(stem));
      return p === "정기" ? 3 : p === "중기" ? 2 : 1;
    };
    basisStem = [...revealedStems].sort((a, b) => phaseRank(b) - phaseRank(a))[0];
    basisKind = "지장간 투출";
  } else if (command) {
    // 투출 전무 — 그 시점을 주관하는 사령으로 격을 잡는다(잠복격)
    basisStem = command.stem;
    basisKind = "사령(잠복)";
  }

  const tenGod = tenGodOf(dayGan, basisStem);
  const base = GYEOKGUK_BY_TENGOD[tenGod] ?? { name: "일반격", gloss: "뚜렷한 격이 잡히지 않는 균형형 구조예요." };
  const kindNote =
    basisKind === "정기 투출" ? `월지 ${monthZhi}의 정기(${basisStem})가 천간에 투출`
    : basisKind === "지장간 투출" ? `월지 ${monthZhi}의 정기는 불투하고 지장간 ${basisStem}이(가) 천간에 투출`
    : `월지 ${monthZhi}에 투출한 지장간이 없어 사령(${basisStem}${command ? `, 절입 ${command.daysSinceTerm.toFixed(0)}일차` : ""}) 기준`;

  const ratio = strength.supportScore / strength.totalScore;
  // 극도로 치우치면 종격 후보로 표시 (참고용)
  if (ratio <= 0.2) {
    return {
      name: `${base.name} · 종격(從格) 후보`,
      basis: `${kindNote} → ${tenGod} + 일간이 매우 약함(지지세력 ${(ratio * 100).toFixed(0)}%)`,
      gloss: `${base.gloss} 다만 일간이 매우 약해, 강한 세력을 따라가는 종격으로 볼 여지도 있어요(관법에 따라 달라지는 참고용).`,
      basisStem,
      basisKind,
    };
  }
  if (ratio >= 0.8) {
    return {
      name: `${base.name} · 종왕/종강격 후보`,
      basis: `${kindNote} → ${tenGod} + 일간이 매우 강함(지지세력 ${(ratio * 100).toFixed(0)}%)`,
      gloss: `${base.gloss} 다만 일간이 매우 강해, 그 힘을 그대로 쓰는 종왕/종강격으로 볼 여지도 있어요(참고용).`,
      basisStem,
      basisKind,
    };
  }
  return {
    name: base.name,
    basis: `${kindNote} → 일간과의 관계 = ${tenGod}`,
    gloss: base.gloss,
    basisStem,
    basisKind,
  };
}

// ── 통근(通根)·투출(投出) ──────────

/** 지장간 배열에서 idx 위치의 강도 (마지막=정기, 3개 중 가운데=중기, 그 외=여기) */
function hiddenStemStrength(stems: string[], idx: number): "정기" | "중기" | "여기" {
  if (idx === stems.length - 1) return "정기";
  if (stems.length === 3 && idx === 1) return "중기";
  return "여기";
}

/**
 * 통근(通根): 각 천간이 지지의 지장간에 같은 오행으로 뿌리를 두는지 판정한다.
 * 정기에 통근하면 강하고, 여기에만 걸치면 약하다. 특히 일간의 통근은 뿌리의 힘을 뜻한다.
 */
function computeRootedness(gans: PositionedChar[], zhis: PositionedChar[]): RootednessHit[] {
  return gans.map(({ label, char }) => {
    const ganEl = GAN_WUXING[char];
    const roots: RootednessHit["roots"] = [];
    for (const z of zhis) {
      const stems = HIDDEN_STEMS[z.char] ?? [];
      stems.forEach((stem, idx) => {
        if (GAN_WUXING[stem] === ganEl) {
          roots.push({ zhi: z.char, zhiPosition: z.label, via: stem, strength: hiddenStemStrength(stems, idx) });
        }
      });
    }
    const rooted = roots.length > 0;
    const isDay = label === "일간";
    const strongRoot = roots.some((r) => r.strength === "정기");
    const note = rooted
      ? `${label} ${char}은(는) ${roots.map((r) => `${r.zhiPosition} ${r.zhi}`).join(", ")}에 뿌리를 둡니다(${strongRoot ? "정기 통근으로 뿌리가 단단함" : "여기·중기 통근으로 뿌리가 약간 있음"}).${isDay ? " 일간이 뿌리를 가져 쉽게 흔들리지 않는 힘이 있습니다." : ""}`
      : `${label} ${char}은(는) 지지에 뿌리가 없어 떠 있는 기운입니다.${isDay ? " 일간이 뿌리가 약해 환경·주변 흐름의 영향을 크게 받습니다." : ""}`;
    return { gan: char, position: label, roots, rooted, note };
  });
}

/**
 * 투출(投出): 월지의 지장간이 천간에 드러났는지 판정한다.
 * 월지 지장간이 천간에 투출하면 그 십성이 격국으로 뚜렷하게 작동한다.
 */
function computeTransparency(dayGan: string, monthZhi: string, gans: PositionedChar[]): TransparencyInfo {
  const hidden = HIDDEN_STEMS[monthZhi] ?? [];
  const revealed: TransparencyInfo["revealed"] = [];
  for (const stem of hidden) {
    const hit = gans.find((g) => g.char === stem);
    if (hit) revealed.push({ stem, atPosition: hit.label, tenGod: tenGodOf(dayGan, stem) });
  }
  const note =
    revealed.length > 0
      ? `월지(${monthZhi})의 기운이 ${revealed.map((r) => `${r.atPosition} ${r.stem}(${r.tenGod})`).join(", ")}으로 드러나(투출), 그 성향이 겉으로 뚜렷하게 나타납니다.`
      : `월지(${monthZhi})의 기운이 천간으로 드러나지 않아(투출 없음), 속에 잠재된 형태로 작동합니다.`;
  return { monthZhi, hidden, revealed, note };
}

/** 격국 성패(간이): 월지 정기가 투출하면 뚜렷(성격 경향), 월지가 충 맞으면 흔들림(파격 경향) */
function assessGyeokgukStatus(
  monthZhi: string,
  transparency: TransparencyInfo,
  interactions: string[],
): { status: GyeokgukInfo["status"]; statusReason: string } {
  const mainStem = (HIDDEN_STEMS[monthZhi] ?? []).slice(-1)[0] ?? "";
  const mainRevealed = transparency.revealed.some((r) => r.stem === mainStem);
  const monthClashed = interactions.some((s) => s.includes("월지") && s.includes("충"));
  if (mainRevealed && !monthClashed) {
    return {
      status: "성격 경향",
      statusReason: `월지 정기(${mainStem})가 천간에 투출하고 월지를 크게 흔드는 충이 없어, 격이 뚜렷하게 작동하는 편입니다.`,
    };
  }
  if (monthClashed) {
    return {
      status: "파격 경향",
      statusReason: `월지(${monthZhi})가 충을 맞아 격의 뿌리가 흔들립니다. 격이 한 번 깨졌다 다시 잡히는 굴곡이 있을 수 있습니다(관법에 따라 다름).`,
    };
  }
  return {
    status: "불명확",
    statusReason: `월지 정기(${mainStem})가 천간에 드러나지 않아 격의 뚜렷함이 약합니다. 여러 기운이 섞인 혼합형으로 볼 수 있습니다.`,
  };
}

// ── 조후·통관 용신 ──────────
// 한난(寒暖) 지수: 월지 계절 온도 + 일간 자체 온도를 더해 조후 방향을 정한다.
// 겨울/여름뿐 아니라 봄·가을도, 일간의 차고 더움까지 반영해 판정한다.
// (일간×월지 60조합 궁통보감 정밀표는 후속 과제 — 여기서는 계절·일간 한난 기반 간이 조후)
const MONTH_TEMP: Record<string, number> = {
  인: -1, 묘: 0, 진: 1, // 봄: 초봄(인)은 아직 냉 → 늦봄(진)은 온
  사: 2, 오: 3, 미: 2, // 여름: 뜨거움
  신: 0, 유: -1, 술: -1, // 가을: 서늘 → 냉·건조
  해: -2, 자: -3, 축: -2, // 겨울: 한랭
};
const GAN_TEMP: Record<string, number> = {
  병: 2, 정: 1, 무: 1, 갑: 0, 을: 0, 기: 0, 경: -1, 신: -1, 임: -1, 계: -1,
};
const SEASON_KO: Record<string, string> = {
  인: "초봄", 묘: "봄", 진: "늦봄", 사: "초여름", 오: "한여름", 미: "늦여름",
  신: "초가을", 유: "가을", 술: "늦가을", 해: "초겨울", 자: "한겨울", 축: "늦겨울",
};

/**
 * 조후용신(간이): 사주의 한난(寒暖)을 보고, 차면 따뜻한 화, 더우면 시원한 수를 조후로 제시한다.
 * 월지 계절 온도와 일간 자체 온도를 더해 판정하므로 봄·가을생·일간별 차이도 반영된다.
 */
function climaticYongshin(monthZhi: string, dayGan: string): { element: string; note: string } | null {
  const monthT = MONTH_TEMP[monthZhi];
  if (monthT === undefined) return null;
  const temp = monthT + (GAN_TEMP[dayGan] ?? 0);
  const dayEl = ELEMENT_KO[GAN_WUXING[dayGan]];
  const season = SEASON_KO[monthZhi] ?? `${monthZhi}월`;
  if (temp <= -2) {
    return {
      element: "화",
      note: `${season}(${monthZhi}월) 태생에 일간 ${dayGan}(${dayEl})까지 더하면 사주가 차가운 편이라, 언 기운을 녹이는 따뜻한 화 기운이 조후로 도움이 됩니다.`,
    };
  }
  if (temp >= 2) {
    return {
      element: "수",
      note: `${season}(${monthZhi}월) 태생에 일간 ${dayGan}(${dayEl})까지 더하면 사주가 더운 편이라, 열기를 식히는 시원한 수 기운이 조후로 도움이 됩니다.`,
    };
  }
  return null; // 한난이 크게 치우치지 않으면 조후 부담이 적어 억부 위주로 본다
}

/** 통관용신(간이): 가장 강한 두 오행이 상극이면 그 사이를 잇는 오행을 통관으로 본다. */
function mediatingYongshin(five: FiveElementBalance): { element: string; note: string } | null {
  const entries = (Object.keys(five) as Array<keyof FiveElementBalance>)
    .map((k) => [k, five[k]] as const)
    .sort((a, b) => b[1] - a[1]);
  const [topEl, topN] = entries[0];
  const [secEl, secN] = entries[1];
  // 둘 다 충분히 강하고(각 2 이상) 서로 상극일 때만 통관 제시
  if (topN < 2 || secN < 2) return null;
  const clashing = OVERCOMES[topEl] === secEl || OVERCOMES[secEl] === topEl;
  if (!clashing) return null;
  // topEl과 secEl 사이를 잇는(둘 다 상생 관계) 오행: 극하는 쪽이 생하는 오행
  const attacker = OVERCOMES[topEl] === secEl ? topEl : secEl;
  const victim = attacker === topEl ? secEl : topEl;
  const bridge = GENERATES[attacker]; // attacker가 생하고, 그게 victim을 생하면 통관
  if (GENERATES[bridge] !== victim) return null;
  return {
    element: ELEMENT_KO[bridge],
    note: `${ELEMENT_KO[topEl]}과 ${ELEMENT_KO[secEl]} 기운이 둘 다 강해 부딪히기 쉬운데, 그 사이를 이어주는 ${ELEMENT_KO[bridge]} 기운이 있으면 충돌이 순환으로 풀립니다(통관).`,
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

  const ec = eightCharOf(lunar, birthInfo);

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
  // 용신 체계 확장: 억부(기존) + 조후(계절) + 통관(대립 오행 잇기)
  const climatic = climaticYongshin(monthPillar.zhi, dayGan);
  const mediating = mediatingYongshin(fiveElements);
  if (climatic) yongshin.climatic = climatic;
  if (mediating) yongshin.mediating = mediating;
  yongshin.method = `억부 중심${climatic ? " + 조후 보정" : ""}${mediating ? " + 통관 참고" : ""}`;

  // 통근·투출
  const rootedness = computeRootedness(gans, zhis);
  const transparency = computeTransparency(dayGan, monthPillar.zhi, gans);

  const twelveStages = zhis.map((z) => `${z.label} ${z.char}: ${twelveStageOf(dayGan, z.char)}`);
  const gongmangZhis = gongmangOf(dayGan, dayPillar.zhi);
  const gongmangHits = zhis.filter((z) => gongmangZhis.includes(z.char)).map((z) => `${z.label} ${z.char}`);
  const gongmang = `${gongmangZhis} 공망${gongmangHits.length > 0 ? ` (원국 내 해당: ${gongmangHits.join(", ")})` : " (원국 내 해당 지지 없음)"}`;

  // 월률분야(사령): 절입 경과일 기준 월지 지장간 중 주관하는 기운
  let monthCommand: MonthCommand | null = null;
  try {
    const jie = lunar.getPrevJie();
    const daysSinceTerm = lunar.getSolar().getJulianDay() - jie.getSolar().getJulianDay();
    monthCommand = buildMonthCommand(monthPillar.zhi, dayGan, daysSinceTerm, jie.getName());
  } catch {
    monthCommand = null;
  }

  const sinsal = computeSinsal(dayGan, dayPillar.zhi, monthPillar.zhi, yearPillar.zhi, gans, zhis);
  const gyeokguk = computeGyeokguk(dayGan, monthPillar.zhi, strength, transparency, monthCommand);
  // 격국 성패(투출·충 기준) 보정
  const gyeokgukStatus = assessGyeokgukStatus(monthPillar.zhi, transparency, interactions);
  gyeokguk.status = gyeokgukStatus.status;
  gyeokguk.statusReason = gyeokgukStatus.statusReason;
  const iljuTrait = iljuTraitOf(dayPillar.ganZhi);

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
    rootedness,
    transparency,
    monthCommand: monthCommand ?? undefined,
    twelveStages,
    gongmang,
    seasonNote: seasonNoteOf(monthPillar.zhi, dayGan),
    sinsal,
    iljuTrait,
    gyeokguk,
    timeCorrection: correction ?? undefined,
    calculationBasis: calculationBasisOf(birthInfo),
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

export interface LuckCycleOptions {
  /** 올해 1~12월 월운 흐름까지 계산 (월간/연간 흐름 리딩용) */
  includeMonthlyFlow?: boolean;
  /** 대운·세운 중첩 판정에 쓸 용신(보완) 오행 (한글, 예: ["화","목"]) */
  yongElements?: string[];
  /** 대운·세운 중첩 판정에 쓸 기신(부담) 오행 (한글) */
  avoidElements?: string[];
}

/** 간지(2글자)가 용신/기신 방향인지 판정 (천간·지지 오행 중 어느 쪽에 기우는지) */
function luckFavorOf(ganZhi: string, yong: Set<string>, avoid: Set<string>): "boost" | "drain" | "neutral" {
  if (ganZhi.length < 2) return "neutral";
  const els = [GAN_WUXING[ganZhi[0]], ZHI_WUXING[ganZhi[1]]].filter(Boolean) as Array<keyof FiveElementBalance>;
  let good = 0;
  let bad = 0;
  for (const el of els) {
    const ko = ELEMENT_KO[el];
    if (yong.has(ko)) good += 1;
    if (avoid.has(ko)) bad += 1;
  }
  if (good > bad) return "boost";
  if (bad > good) return "drain";
  return "neutral";
}

/**
 * 대운·세운 중첩 판정: 큰 흐름(대운)과 올해 흐름(세운)이 서로 어떻게 겹치는지 계산한다.
 * - 두 간지 사이의 직접 합충형파해
 * - 각각이 용신/기신 방향인지 → 좋은 흐름 겹침 / 부담 겹침 / 엇갈림 판정
 */
function computeLuckOverlap(
  daYunGanZhi: string,
  yearGanZhi: string,
  yongElements: string[] = [],
  avoidElements: string[] = [],
): LuckOverlap {
  const yong = new Set(yongElements);
  const avoid = new Set(avoidElements);

  // 대운-세운 두 기둥 사이의 상호작용만 (원국 없이)
  const gans: PositionedChar[] = [
    { label: "대운", char: daYunGanZhi[0] },
    { label: "세운", char: yearGanZhi[0] },
  ];
  const zhis: PositionedChar[] = [
    { label: "대운", char: daYunGanZhi[1] },
    { label: "세운", char: yearGanZhi[1] },
  ];
  const interactions = computeInteractions(gans, zhis);

  const daYunFavor = luckFavorOf(daYunGanZhi, yong, avoid);
  const yearFavor = luckFavorOf(yearGanZhi, yong, avoid);

  let combo: LuckOverlap["combo"];
  if (daYunFavor === "boost" && yearFavor === "boost") combo = "amplify-good";
  else if (daYunFavor === "drain" && yearFavor === "drain") combo = "amplify-bad";
  else if (daYunFavor === "neutral" && yearFavor === "neutral") combo = "quiet";
  else combo = "mixed";

  const hasClash = interactions.some((s) => s.includes("충"));
  const hasHe = interactions.some((s) => s.includes("합"));

  let headline: string;
  switch (combo) {
    case "amplify-good":
      headline = "큰 흐름과 올해 흐름이 같은 방향으로 실려, 좋은 기운이 겹쳐 나타나기 쉬운 시기입니다.";
      break;
    case "amplify-bad":
      headline = "큰 흐름과 올해 흐름이 함께 부담 쪽으로 기울어, 무리하면 지치기 쉬운 시기입니다. 속도 조절이 중요합니다.";
      break;
    case "mixed":
      headline = "큰 흐름과 올해 흐름이 서로 엇갈려, 방향을 하나로 정하기 애매한 시기입니다. 급하게 밀지 말고 신호를 보며 움직이세요.";
      break;
    default:
      headline = "큰 흐름과 올해 흐름이 크게 부딪히지 않아, 비교적 담담하게 흘러가는 시기입니다.";
  }
  if (hasClash) headline += " 특히 두 흐름이 부딪히는 지점이 있어 자리·환경이 한 번 흔들릴 수 있습니다.";
  else if (hasHe) headline += " 두 흐름이 묶이며 새로운 인연·기회가 만들어지기도 합니다.";

  const favorWord = (f: LuckFavorLocal) => (f === "boost" ? "보완 방향" : f === "drain" ? "부담 방향" : "중립");
  const evidence = [
    `대운 ${daYunGanZhi}(${favorWord(daYunFavor)}) · 세운 ${yearGanZhi}(${favorWord(yearFavor)}) → ${combo}`,
    ...(interactions.length > 0 ? [`대운-세운 상호작용: ${interactions.join(", ")}`] : ["대운-세운 직접 상호작용 없음"]),
  ];

  return { daYunGanZhi, yearGanZhi, interactions, daYunFavor, yearFavor, combo, headline, evidence };
}

type LuckFavorLocal = "boost" | "drain" | "neutral";

/**
 * 과거 검증용: 사용자가 입력한 과거 사건들 각각에 대해, 그 해의 세운 간지와
 * 그 시기 대운 간지, 그리고 그 운이 원국과 맺는 상호작용을 계산해 순수 데이터로 반환한다.
 * (부합도 판정·문구 생성은 saju.ts를 import하지 않는 pastValidation.ts에서 한다.
 *  계산은 브라우저에서 실행되고, API로는 결과 값만 전달된다 — 프로젝트 계산/보안 원칙.)
 */
export function computePastEventCalibrationInputs(
  birthInfo: BirthInfo,
  pastEvents: PastEvent[],
): PastEventCalibrationInput[] {
  if (pastEvents.length === 0) return [];
  const { lunar } = birthToLunar(birthInfo);
  const ec = eightCharOf(lunar, birthInfo);

  // 원국 기둥 (운과의 상호작용 계산용) — computeLuckCycles와 동일 구성
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

  // 대운 목록 (연도로 조회)
  const yun = ec.getYun(birthInfo.gender === "male" ? 1 : 0);
  const daYunList = yun
    .getDaYun()
    .filter((dy) => dy.getGanZhi() !== "")
    .map((dy) => ({ startYear: dy.getStartYear(), endYear: dy.getEndYear(), ganZhi: toHangul(dy.getGanZhi()) }));

  return pastEvents.map((ev) => {
    // 그 해 세운 (입춘 기준, 연중 6/15로 절기 경계 회피)
    const yLunar = Solar.fromYmdHms(ev.year, 6, 15, 12, 0, 0).getLunar();
    const yearGanZhi = toHangul(yLunar.getYearInGanZhiByLiChun());
    const daYun = daYunList.find((d) => d.startYear <= ev.year && ev.year <= d.endYear) ?? null;
    const daYunGanZhi = daYun?.ganZhi ?? null;

    const interactions = [
      ...(daYunGanZhi ? luckVsNatal(`대운 ${daYunGanZhi}`, daYunGanZhi, natalGans, natalZhis) : []),
      ...luckVsNatal(`세운 ${yearGanZhi}`, yearGanZhi, natalGans, natalZhis),
    ];

    return {
      year: ev.year,
      domain: ev.domain,
      note: ev.note,
      yearGanZhi,
      daYunGanZhi,
      interactions,
    };
  });
}

export function computeLuckCycles(
  birthInfo: BirthInfo,
  now: Date = new Date(),
  options: LuckCycleOptions = {},
): LuckCycles {
  const { lunar } = birthToLunar(birthInfo);
  const ec = eightCharOf(lunar, birthInfo);
  const birthSolarYear = lunar.getSolar().getYear();

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

  // 대운·세운 중첩 판정 (큰 흐름과 올해 흐름이 서로 겹치는 방식)
  const daYunYearOverlap =
    currentDaYun && yearGanZhi.length >= 2
      ? computeLuckOverlap(currentDaYun, yearGanZhi, options.yongElements, options.avoidElements)
      : undefined;

  let monthlyFlow: MonthFlowInfo[] | undefined;
  if (options.includeMonthlyFlow) {
    monthlyFlow = [];
    for (let m = 1; m <= 12; m++) {
      // 절기 경계(매달 4~8일경)를 피해 15일 정오 기준으로 그 달의 월주를 뽑는다
      const midLunar = Solar.fromYmdHms(nowYear, m, 15, 12, 0, 0).getLunar();
      const ganZhi = toHangul(midLunar.getMonthInGanZhi());
      monthlyFlow.push({
        month: m,
        ganZhi,
        interactions: luckVsNatal(`${m}월 월운 ${ganZhi}`, ganZhi, natalGans, natalZhis),
      });
    }
  }

  // 올해부터 10년치 세운 흐름 (입춘 기준, 연중 6/15로 경계 회피)
  const yearlyFlow: YearFlowInfo[] = [];
  for (let i = 0; i < 10; i++) {
    const y = nowYear + i;
    const yLunar = Solar.fromYmdHms(y, 6, 15, 12, 0, 0).getLunar();
    const ganZhi = toHangul(yLunar.getYearInGanZhiByLiChun());
    yearlyFlow.push({
      year: y,
      age: y - birthSolarYear,
      ganZhi,
      interactions: luckVsNatal(`${y}년 세운 ${ganZhi}`, ganZhi, natalGans, natalZhis),
      current: y === nowYear,
    });
  }

  return {
    monthlyFlow,
    yearlyFlow,
    daYun,
    currentDaYun,
    yearGanZhi,
    monthGanZhi,
    dayGanZhi,
    year: nowYear,
    month: now.getMonth() + 1,
    luckInteractions,
    daYunYearOverlap,
  };
}

// ── 궁합 (두 사주 비교) ──────────

/** 두 사람 기질 사이 관계를 판정한다 (표면은 사주 용어 없이 쉬운 말) */
function dayMasterRelation(ganA: string, ganB: string): { text: string; score: number } {
  const he = GAN_HE[pairKey(ganA, ganB)] ?? GAN_HE[pairKey(ganB, ganA)];
  if (he) return { text: "두 사람은 기질이 자석처럼 서로 끌리고, 부족한 부분을 채워주는 궁합이에요.", score: 22 };
  const elA = GAN_WUXING[ganA];
  const elB = GAN_WUXING[ganB];
  if (elA === elB) return { text: "기본 성향이 비슷해 말이 잘 통해요. 편한 대신 은근한 경쟁이 될 수도 있어요.", score: 10 };
  if (GENERATES[elA] === elB) return { text: "한 사람이 다른 사람을 북돋아 주고 챙겨주는, 힘이 되는 궁합이에요.", score: 16 };
  if (GENERATES[elB] === elA) return { text: "서로 힘이 되어주며 기대고 기댈 수 있는 궁합이에요.", score: 16 };
  return { text: "서로 자극을 주고받는 궁합이에요. 부딪히기도 하지만 다름을 인정하면 함께 성장해요.", score: 4 };
}

/** 두 사람 지지 사이의 인연(합충)을 세되, 표시는 사주 용어 없이 쉬운 말로 묶는다 */
function crossBranchRelations(
  zhisA: string[],
  zhisB: string[],
): { good: string[]; bad: string[]; goodCount: number; badCount: number } {
  const goodSet = new Set<string>();
  const badSet = new Set<string>();
  let goodCount = 0;
  let badCount = 0;
  for (const a of zhisA) {
    for (const b of zhisB) {
      const keys = [a + b, b + a];
      if (keys.some((k) => ZHI_LIUHE[k] !== undefined)) { goodCount += 1; goodSet.add("서로 잘 맞아 붙는 부분이 있어요"); }
      if (keys.some((k) => ZHI_CHONG.has(k))) { badCount += 1; badSet.add("가끔 세게 부딪히기 쉬운 부분이 있어요"); }
      if (keys.some((k) => ZHI_XING.has(k))) { badCount += 1; badSet.add("서로 조율이 필요한 부분이 있어요"); }
      if (keys.some((k) => ZHI_PO.has(k))) { badCount += 1; badSet.add("계획이 엇갈리기 쉬운 부분이 있어요"); }
      if (keys.some((k) => ZHI_HAI.has(k))) { badCount += 1; badSet.add("은근히 신경 쓰이는 부분이 있어요"); }
    }
  }
  // 여러 면에서 잘 맞물리는 조합(삼합/반합)
  const present = new Set([...zhisA, ...zhisB]);
  for (const { group, wangZhi } of SANHE) {
    const inA = group.some((g) => zhisA.includes(g));
    const inB = group.some((g) => zhisB.includes(g));
    const hits = group.filter((g) => present.has(g));
    if (inA && inB && hits.length >= 2 && hits.includes(wangZhi)) { goodCount += 1; goodSet.add("여러 면에서 손발이 잘 맞아요"); }
  }
  return { good: [...goodSet], bad: [...badSet], goodCount, badCount };
}

/** 두 사람이 서로 부족한 부분을 채워주는 정도 (표면은 사주 용어 없이) */
function elementComplement(a: FiveElementBalance, b: FiveElementBalance): { text: string; score: number } {
  const keys = Object.keys(a) as Array<keyof FiveElementBalance>;
  let complement = 0;
  for (const k of keys) {
    // 한쪽이 부족(0~1)한데 다른 쪽이 넉넉(2+)하면 보완
    if (a[k] <= 1 && b[k] >= 2) complement += 1;
    if (b[k] <= 1 && a[k] >= 2) complement += 1;
  }
  const score = Math.min(20, complement * 5);
  const text =
    complement > 0
      ? `서로 부족한 부분을 ${complement}가지 방향에서 채워줘요. 함께 있으면 균형이 잘 맞아요.`
      : "기본 성향이 비슷해 크게 보완되진 않지만, 결이 맞아 편안한 편이에요.";
  return { text, score };
}

const ELEMENT_PLAIN: Record<keyof FiveElementBalance, string> = {
  wood: "시작하고 배우는 힘",
  fire: "표현하고 가까워지는 힘",
  earth: "생활을 안정시키는 힘",
  metal: "기준을 세우고 정리하는 힘",
  water: "감정과 생각을 깊게 살피는 힘",
};

const TEN_GOD_PLAIN: Record<string, string> = {
  비견: "나와 비슷해서 편하지만, 고집이 부딪힐 수 있는 사람",
  겁재: "강하게 끌리지만 경쟁심이나 주도권 문제가 생기기 쉬운 사람",
  식신: "편하게 표현하고 웃을 수 있게 해주는 사람",
  상관: "답답함을 풀어주지만 말이 날카로워질 수 있는 사람",
  편재: "현실 감각과 즐거움을 깨워주는 사람",
  정재: "생활을 안정시키고 신뢰를 쌓기 좋은 사람",
  편관: "긴장과 자극을 주며 책임감을 끌어내는 사람",
  정관: "관계의 기준과 약속을 중요하게 만들 사람",
  편인: "생각을 깊게 만들지만 속마음을 알기 어렵게 느껴질 수 있는 사람",
  정인: "받아주고 이해해주는 느낌을 주는 사람",
};

const RELATION_CONTEXT: Record<
  CompatibilityRelationType,
  {
    label: string;
    scoreTitle: [string, string, string];
    coreTitle: string;
    palaceLabel: string;
    roleTitle: string;
    purposeLabels: [string, string, string, string];
    caution: string;
    action: string;
    improvement: string[];
  }
> = {
  romantic: {
    label: "연인·썸·배우자",
    scoreTitle: ["끌림과 보완이 강한 관계", "맞는 부분과 조율할 부분이 함께 있는 관계", "속도와 기준을 맞춰야 하는 관계"],
    coreTitle: "관계 핵심 카드",
    palaceLabel: "연애·생활 자리",
    roleTitle: "서로에게 어떤 사람으로 느껴지는지",
    purposeLabels: ["연애", "결혼·동거", "일·사업", "친구·동료"],
    caution: "잘 맞는다고 느낄수록 상대가 알아서 이해해줄 거라 넘기지 않는 것이 좋습니다.",
    action: "둘 다 편한 방식만 고집하기보다 연락 빈도, 돈 쓰는 방식, 쉬는 방식의 최소 기준을 정해두세요.",
    improvement: ["연락 빈도와 서운함을 말하는 방식을 정해두기", "돈·시간·가족 문제는 감정이 커지기 전에 기준 합의하기", "좋았던 점을 당연하게 넘기지 않고 말로 확인하기"],
  },
  parentChild: {
    label: "부모와 자식",
    scoreTitle: ["돌봄과 독립을 함께 만들 수 있는 관계", "기대와 자율성 조율이 필요한 관계", "통제와 반발을 줄이는 기준이 필요한 관계"],
    coreTitle: "양육·독립 핵심 카드",
    palaceLabel: "생활·정서 자리",
    roleTitle: "서로에게 어떤 가족으로 느껴지는지",
    purposeLabels: ["정서적 안정", "생활 규칙", "진로·학업 대화", "독립성"],
    caution: "좋은 뜻으로 한 말도 통제나 평가처럼 들릴 수 있으니, 지시보다 선택지를 주는 방식이 좋습니다.",
    action: "기대하는 행동을 추상적으로 말하지 말고, 시간·범위·선택권을 함께 정해 주세요.",
    improvement: ["혼내기 전에 원하는 행동을 한 문장으로 말하기", "진로·학업·돈 문제는 선택지 2~3개로 대화하기", "각자의 방·시간·휴식 경계를 존중하기"],
  },
  siblings: {
    label: "형제·자매·남매",
    scoreTitle: ["비슷함을 협력으로 쓰기 좋은 관계", "비교와 역할 고정만 조심하면 좋은 관계", "경쟁심과 거리 조절이 필요한 관계"],
    coreTitle: "형제 관계 핵심 카드",
    palaceLabel: "가족 내 생활 자리",
    roleTitle: "서로에게 어떤 형제자매로 느껴지는지",
    purposeLabels: ["정서적 친밀감", "현실 협력", "가족 문제 대응", "거리 조절"],
    caution: "가족 안에서 맡아온 역할이 굳어지면 작은 말도 비교나 서운함으로 들리기 쉽습니다.",
    action: "부탁할 일과 거절할 일을 분리하고, 부모님·돈·돌봄 문제는 역할을 문서처럼 나누는 편이 좋습니다.",
    improvement: ["비교하는 말 줄이기", "가족 행사·돌봄·돈 문제는 역할표로 나누기", "친해도 사생활 경계는 따로 인정하기"],
  },
  family: {
    label: "가족 관계",
    scoreTitle: ["서로를 받쳐줄 수 있는 가족 흐름", "정과 부담이 함께 있는 가족 흐름", "역할과 거리 기준이 필요한 가족 흐름"],
    coreTitle: "가족 관계 핵심 카드",
    palaceLabel: "가정 내 생활 자리",
    roleTitle: "서로에게 어떤 가족으로 느껴지는지",
    purposeLabels: ["정서적 지지", "생활 협력", "갈등 회복", "거리 조절"],
    caution: "가족이라는 이유로 모든 감정과 책임을 당연하게 넘기면 피로가 쌓일 수 있습니다.",
    action: "도와줄 수 있는 범위와 어려운 범위를 미리 말해두면 관계가 더 오래 안정됩니다.",
    improvement: ["책임 범위를 말로 정하기", "감정이 큰 날에는 결론보다 휴식 먼저 두기", "고마움과 불편함을 따로 표현하기"],
  },
  bossEmployee: {
    label: "사장·직원",
    scoreTitle: ["역할을 나누면 성과가 나는 업무 관계", "기준과 보고 방식 조율이 필요한 업무 관계", "권한·책임선을 분명히 해야 하는 업무 관계"],
    coreTitle: "업무 관계 핵심 카드",
    palaceLabel: "업무·책임 자리",
    roleTitle: "서로에게 어떤 업무 파트너로 느껴지는지",
    purposeLabels: ["지시·보고", "성과 창출", "책임 분담", "갈등 관리"],
    caution: "말하지 않아도 알겠지라는 기대가 커지면 지시와 결과물의 기준이 어긋나기 쉽습니다.",
    action: "업무 요청은 마감, 결과물 형태, 우선순위를 함께 적어두는 편이 안정적입니다.",
    improvement: ["업무 지시는 결과물 예시까지 남기기", "보고 주기와 결정권자를 정하기", "피드백은 성격이 아니라 행동 기준으로 말하기"],
  },
  coworker: {
    label: "동료·동업자",
    scoreTitle: ["역할 분담이 잘 맞는 협업 관계", "방식 차이를 조율하면 좋은 협업 관계", "책임과 이익 기준을 먼저 정해야 하는 관계"],
    coreTitle: "협업 핵심 카드",
    palaceLabel: "협업·역할 자리",
    roleTitle: "서로에게 어떤 협업자로 느껴지는지",
    purposeLabels: ["협업 속도", "역할 분담", "돈·성과 기준", "갈등 복구"],
    caution: "친하거나 잘 맞아도 돈, 일정, 책임 범위가 흐려지면 관계가 쉽게 피곤해질 수 있습니다.",
    action: "시작 전에 역할, 마감, 비용, 최종 결정권을 짧게라도 기록해두세요.",
    improvement: ["일정과 돈 기준을 먼저 적기", "각자 잘하는 일을 맡고 검수 기준을 공유하기", "불만은 회의록처럼 사실 중심으로 남기기"],
  },
  friend: {
    label: "친구",
    scoreTitle: ["편하게 오래 갈 수 있는 친구 관계", "좋지만 거리 조절이 필요한 친구 관계", "기대치 차이를 줄여야 하는 친구 관계"],
    coreTitle: "친구 관계 핵심 카드",
    palaceLabel: "친밀감·거리 자리",
    roleTitle: "서로에게 어떤 친구로 느껴지는지",
    purposeLabels: ["정서적 편안함", "놀이·취미", "현실 도움", "거리 조절"],
    caution: "친하다는 이유로 연락, 돈, 부탁의 기준이 흐려지면 서운함이 쌓일 수 있습니다.",
    action: "부탁과 거절을 가볍게 말할 수 있는 관계인지 확인하고, 돈 문제는 작아도 분명히 하는 편이 좋습니다.",
    improvement: ["연락 텀을 개인 성향으로 인정하기", "돈 빌리기·부탁은 기준을 분명히 하기", "서운함은 쌓기보다 작은 말로 빨리 풀기"],
  },
  rival: {
    label: "앙숙·불편한 사람",
    scoreTitle: ["자극을 성장으로 바꿀 수 있는 관계", "거리와 규칙이 필요한 불편한 관계", "최소 충돌 운영이 중요한 관계"],
    coreTitle: "불편한 관계 핵심 카드",
    palaceLabel: "충돌·거리 자리",
    roleTitle: "서로에게 어떤 자극으로 느껴지는지",
    purposeLabels: ["충돌 가능성", "거리 조절", "업무상 공존", "감정 소모 관리"],
    caution: "상대를 바꾸려는 방향으로 가면 감정 소모가 커질 수 있으니, 접점과 규칙을 줄이는 편이 현실적입니다.",
    action: "필요한 대화는 짧게, 기록이 남는 방식으로, 결정 기준을 사실 중심으로 두세요.",
    improvement: ["감정 대화보다 사실·기한·역할만 남기기", "불필요한 사적 접점 줄이기", "반응하기 전 하루 뒤 다시 판단하기"],
  },
};

function isWorkRelation(context: (typeof RELATION_CONTEXT)[CompatibilityRelationType]) {
  return context.label.includes("사장") || context.label.includes("업무") || context.label.includes("동료") || context.label.includes("동업");
}

function relationKind(context: (typeof RELATION_CONTEXT)[CompatibilityRelationType]): "love" | "family" | "work" | "friend" | "rival" {
  if (isWorkRelation(context)) return "work";
  if (context.label.includes("가족") || context.label.includes("부모") || context.label.includes("형제")) return "family";
  if (context.label.includes("친구")) return "friend";
  if (context.label.includes("불편")) return "rival";
  return "love";
}

function relationCopy(context: (typeof RELATION_CONTEXT)[CompatibilityRelationType]) {
  const kind = relationKind(context);
  const base = {
    love: {
      area: "연락, 표현, 만나는 주기, 돈 쓰는 방식",
      goodSignal: "편해진 뒤에도 표현과 배려가 줄지 않는지",
      frictionSignal: "연락 빈도, 표현 방식, 만나는 주기에서 서운함이 반복되는지",
      action: "서운함은 감정이 커지기 전에 '어떤 행동이 언제' 단위로 말하세요.",
      script: "“나를 좋아하는지 몰아붙이려는 게 아니라, 우리가 서로 편해지는 방식을 맞춰보고 싶어.”",
      avoid: "상대의 마음을 한 번의 답장 속도나 말투로 단정하기",
    },
    family: {
      area: "책임 범위, 돌봄, 돈, 가족 행사, 각자의 생활 경계",
      goodSignal: "가족이라는 이유로 당연하게 떠넘기지 않고 서로의 범위를 확인하는지",
      frictionSignal: "돈, 돌봄, 가족 행사, 부모님 문제에서 한쪽만 떠안는 느낌이 생기는지",
      action: "가족이라도 도와줄 수 있는 범위와 어려운 범위를 숫자나 일정으로 말하세요.",
      script: "“가족이라서 도와주고 싶지만, 내가 할 수 있는 범위는 여기까지야.”",
      avoid: "가족이니까 알아서 이해해야 한다고 넘기기",
    },
    work: {
      area: "역할, 마감, 보고 방식, 결정권, 피드백 기준",
      goodSignal: "역할과 마감을 적었을 때 실제 오해가 줄어드는지",
      frictionSignal: "수정 요청, 보고 타이밍, 우선순위 변경에서 불편함이 커지는지",
      action: "업무 요청은 마감, 결과물 형태, 우선순위, 결정권자를 함께 적으세요.",
      script: "“우리 사이가 편해도 일 기준은 따로 정해두자. 역할과 마감만 먼저 맞추면 좋겠어.”",
      avoid: "일 문제를 친분이나 정으로 덮기",
    },
    friend: {
      area: "연락 텀, 부탁과 거절, 돈 문제, 사생활 거리",
      goodSignal: "부담스러운 부탁을 거절해도 관계가 크게 흔들리지 않는지",
      frictionSignal: "연락, 돈, 부탁, 약속 취소에서 서운함이 쌓이는지",
      action: "친해도 부탁, 돈, 약속 변경은 가볍게라도 기준을 말하세요.",
      script: "“친해서 더 편하게 말하고 싶어. 나는 이 부탁은 어렵고, 대신 여기까지는 가능해.”",
      avoid: "친하다는 이유로 돈, 부탁, 연락 기준을 흐리기",
    },
    rival: {
      area: "접점, 대화 범위, 기록, 감정 소모를 줄이는 규칙",
      goodSignal: "필요한 말만 짧게 하고도 일이 진행되는지",
      frictionSignal: "사소한 말투나 비교심 때문에 감정 소모가 커지는지",
      action: "필요한 대화는 짧게, 기록이 남는 방식으로, 사실과 기한 중심으로 정리하세요.",
      script: "“감정 이야기는 길게 하지 말고, 지금 필요한 사실과 다음 행동만 정리하자.”",
      avoid: "상대를 설득하거나 바꾸려고 오래 붙잡기",
    },
  }[kind];
  return { kind, ...base };
}

function strongestElement(balance: FiveElementBalance): keyof FiveElementBalance {
  return (Object.keys(balance) as Array<keyof FiveElementBalance>).sort((a, b) => balance[b] - balance[a])[0];
}

function weakestElement(balance: FiveElementBalance): keyof FiveElementBalance {
  return (Object.keys(balance) as Array<keyof FiveElementBalance>).sort((a, b) => balance[a] - balance[b])[0];
}

function personSummary(label: string, chart: SajuChart) {
  const strong = strongestElement(chart.fiveElements);
  const weak = weakestElement(chart.fiveElements);
  return {
    label,
    pillars: {
      year: chart.year.ganZhi,
      month: chart.month.ganZhi,
      day: chart.day.ganZhi,
      hour: chart.hour?.ganZhi ?? null,
    },
    dayMaster: chart.dayMasterGan,
    strongestElement: ELEMENT_PLAIN[strong],
    weakestElement: ELEMENT_PLAIN[weak],
  };
}

function relationToneFromDayBranches(dayA: string, dayB: string): { title: string; body: string; evidence: string; score: number } {
  const keys = [dayA + dayB, dayB + dayA];
  if (keys.some((k) => ZHI_LIUHE[k] !== undefined)) {
    return {
      title: "가까워질수록 생활 결이 붙는 관계",
      body: "처음보다 함께 보내는 시간이 쌓일수록 정이 붙고, 일상 루틴을 맞추기 좋은 흐름입니다.",
      evidence: `일지 ${dayA}·${dayB} 사이 합 작용`,
      score: 14,
    };
  }
  if (keys.some((k) => ZHI_CHONG.has(k))) {
    return {
      title: "끌림과 흔들림이 같이 오는 관계",
      body: "서로를 강하게 의식하지만, 가까워질수록 생활 방식이나 감정 반응이 크게 다르게 느껴질 수 있습니다.",
      evidence: `일지 ${dayA}·${dayB} 사이 충 작용`,
      score: -10,
    };
  }
  if (keys.some((k) => ZHI_XING.has(k) || ZHI_PO.has(k) || ZHI_HAI.has(k))) {
    return {
      title: "사소한 불편함을 쌓아두지 않는 게 중요한 관계",
      body: "대놓고 크게 싸우기보다 작은 서운함, 말투, 약속 방식에서 긴장이 쌓이기 쉬우니 초반 기준 정리가 중요합니다.",
      evidence: `일지 ${dayA}·${dayB} 사이 형·파·해 계열 작용`,
      score: -6,
    };
  }
  return {
    title: "생활 리듬을 천천히 맞춰가는 관계",
    body: "강하게 붙거나 부딪히는 신호는 약한 편이라, 서로의 습관을 확인하며 안정감을 만드는 방식이 잘 맞습니다.",
    evidence: `일지 ${dayA}·${dayB} 사이 강한 합충 신호 없음`,
    score: 4,
  };
}

function roleChemistry(chartA: SajuChart, chartB: SajuChart, roleLabels = { first: "나", second: "상대" }): CompatibilityResult["roleChemistry"] {
  const aSeesB = tenGodOf(chartA.dayMasterGan, chartB.dayMasterGan);
  const bSeesA = tenGodOf(chartB.dayMasterGan, chartA.dayMasterGan);
  return [
    {
      title: `${roleLabels.first}가 느끼는 ${roleLabels.second}`,
      body: TEN_GOD_PLAIN[aSeesB] ?? "상대가 어떤 역할로 다가오는지 계산 근거가 약합니다.",
      evidence: `${roleLabels.first} 일간 ${chartA.dayMasterGan} 기준 ${roleLabels.second} 일간 ${chartB.dayMasterGan} = ${aSeesB}`,
    },
    {
      title: `${roleLabels.second}가 느끼는 ${roleLabels.first}`,
      body: TEN_GOD_PLAIN[bSeesA] ?? "상대가 어떤 역할로 다가오는지 계산 근거가 약합니다.",
      evidence: `${roleLabels.second} 일간 ${chartB.dayMasterGan} 기준 ${roleLabels.first} 일간 ${chartA.dayMasterGan} = ${bSeesA}`,
    },
  ];
}

function purposeFits(
  score: number,
  branchScore: number,
  elementScore: number,
  palaceScore: number,
  context: (typeof RELATION_CONTEXT)[CompatibilityRelationType],
): CompatibilityResult["purposeFits"] {
  const clamp = (n: number) => Math.max(0, Math.min(100, Math.round(n)));
  const [a, b, c, d] = context.purposeLabels;
  if (isWorkRelation(context)) {
    return [
      {
        label: a,
        score: clamp(score + palaceScore * 1.4),
        comment: palaceScore >= 0 ? "요청과 보고의 리듬을 맞추면 업무 속도가 안정됩니다." : "지시 의도와 보고 방식이 어긋나기 쉬워 기준을 먼저 맞춰야 합니다.",
        detail:
          palaceScore >= 0
            ? "업무 관계에서는 마음이 맞는지보다 요청을 어떻게 주고받는지가 중요합니다. 이 조합은 기본 리듬이 맞으면 지시를 이해하고 결과물로 옮기는 흐름이 비교적 수월합니다. 다만 말로만 넘기면 서로 다르게 이해할 수 있으니 마감, 결과물 형태, 우선순위를 같이 적어두는 편이 좋습니다."
            : "업무 리듬이 다르면 한쪽은 급하다고 느끼고, 다른 쪽은 설명이 부족하다고 느끼기 쉽습니다. 사장·직원 관계라면 권한 차이 때문에 작은 오해도 평가나 압박으로 커질 수 있으니, 지시·보고 형식을 먼저 정해야 합니다.",
        signal: palaceScore >= 0 ? "짧은 지시에도 결과물 방향이 크게 어긋나지 않을 때 강점이 드러나요." : "수정 요청, 마감 변경, 우선순위 변경 때 불편함이 먼저 드러나요.",
        actions:
          palaceScore >= 0
            ? ["업무 요청은 마감·형태·우선순위를 함께 적기", "보고 주기를 정해 불필요한 확인을 줄이기", "좋았던 결과물 기준을 예시로 남기기"]
            : ["구두 지시 뒤 핵심 조건을 메모로 확인하기", "수정 요청은 한 번에 모아 전달하기", "급한 일과 중요한 일을 구분해 우선순위 표시하기"],
      },
      {
        label: b,
        score: clamp(55 + elementScore * 1.6 + branchScore * 2 + palaceScore),
        comment: "성과를 내려면 역할, 결정권, 검수 기준을 분명히 해야 합니다.",
        detail: "업무 성과는 호감보다 구조에서 나옵니다. 누가 결정하고, 누가 실행하고, 어느 수준이면 완료인지가 선명할수록 이 관계의 장점이 살아납니다. 사장·직원 관계라면 사장은 방향과 기준을, 직원은 진행 상황과 막힌 지점을 빨리 공유하는 방식이 잘 맞습니다.",
        signal: "일이 바빠질 때 지시가 늘어나는지, 아니면 우선순위가 정리되는지에서 궁합이 드러나요.",
        actions: ["완료 기준을 예시로 남기기", "결정권자와 검수자를 분리해 적기", "성과 피드백과 성격 평가는 섞지 않기"],
      },
      {
        label: c,
        score: clamp(50 + elementScore * 1.8 + Math.max(0, branchScore) * 2),
        comment: "책임 범위가 흐려지면 한쪽이 떠안는 구조가 되기 쉽습니다.",
        detail: "잘 맞는 업무 관계라도 책임선이 흐리면 금방 피로해집니다. 사장은 기대 수준을 구체적으로 말하고, 직원은 가능한 범위와 필요한 지원을 빨리 알려야 합니다. 서로의 장점은 역할로 인정하되, 빈틈은 선의가 아니라 프로세스로 메우는 쪽이 안정적입니다.",
        signal: "문제가 생겼을 때 책임 소재보다 다음 조치를 먼저 정할 수 있으면 오래 갑니다.",
        actions: ["담당자·마감·공유 범위를 한 줄로 적기", "막힌 지점은 숨기지 말고 빨리 보고하기", "추가 업무는 우선순위 재조정 후 받기"],
      },
      {
        label: d,
        score: clamp(55 + branchScore * 2.2 + Math.min(12, elementScore)),
        comment: "갈등은 감정보다 기준과 절차로 풀 때 안정됩니다.",
        detail: "업무 갈등은 대부분 성격 문제가 아니라 기준 차이에서 커집니다. 말투가 거칠게 느껴지거나 피드백이 서운하게 들릴 수 있어도, 무엇을 고치면 되는지 분리하면 관계가 덜 상합니다. 사장·직원 관계일수록 피드백은 공개 지적보다 구체적 수정 기준으로 전달하는 편이 좋습니다.",
        signal: "수정·지연·실수 상황에서 비난보다 다음 기준이 먼저 나오는지 확인하세요.",
        actions: ["피드백은 행동·결과물 기준으로 말하기", "감정이 올라오면 바로 평가하지 말고 사실 확인부터 하기", "반복 문제는 개인 탓보다 체크리스트로 막기"],
      },
    ];
  }
  return [
    {
      label: a,
      score: clamp(score + palaceScore * 1.4),
      comment: palaceScore >= 0 ? "감정이 붙는 속도와 일상 친밀감을 만들기 좋습니다." : "끌림은 있어도 감정 반응 속도를 맞추는 연습이 필요합니다.",
      detail:
        palaceScore >= 0
          ? "둘이 가까워질 때 어색함보다 익숙함이 먼저 생기기 쉬운 조합입니다. 같이 밥 먹고, 쉬고, 하루 루틴을 공유하는 장면에서 친밀감이 잘 쌓입니다. 화려한 이벤트보다 자주 겹치는 평범한 시간이 이 관계를 단단하게 만듭니다."
          : "처음 끌림은 있어도 가까워진 뒤에는 말투, 연락 속도, 사소한 생활 습관이 다르게 느껴질 수 있습니다. 감정보다 생활 방식 조율이 먼저입니다. 마음이 식은 게 아니라 리듬이 다른 것뿐이라는 전제를 서로 공유하면 불필요한 상처가 줄어듭니다.",
      signal:
        palaceScore >= 0
          ? "함께 있는 평범한 시간이 자연스럽게 편안할 때 잘 맞는다는 신호예요."
          : "연락 텀이나 표현 방식이 어긋날 때 서운함이 먼저 쌓이기 쉬워요.",
      actions:
        palaceScore >= 0
          ? ["같이 반복할 작은 루틴을 하나 정하기", "좋았던 행동을 구체적으로 말해주기", "편해졌다고 표현을 줄이지 않기"]
          : ["연락 빈도와 답장 기대치를 먼저 맞추기", "서운한 점은 그날 바로 결론내리지 않기", "싸움보다 생활 규칙부터 정리하기"],
    },
    {
      label: b,
      score: clamp(55 + elementScore * 1.6 + branchScore * 2 + palaceScore),
      comment: "생활 습관, 돈 쓰는 방식, 가족과의 거리 기준을 먼저 맞출수록 안정됩니다.",
      detail: "오래 보는 관계에서는 감정의 세기보다 생활 운영 방식이 더 중요해집니다. 돈을 쓰는 우선순위, 집안일이나 가족 행사에 대한 태도, 각자의 휴식 시간이 맞아야 안정감이 오래 갑니다. 연애 때는 넘어가던 습관 차이가 같이 살면 매일의 문제가 되므로, 감정보다 규칙을 먼저 세우는 편이 유리합니다.",
      signal: "돈·집안일·가족 행사·휴식 시간처럼 매일 반복되는 생활 운영에서 차이가 가장 크게 드러나요.",
      actions: ["돈 쓰는 기준을 월 단위로 맞춰보기", "각자 혼자 쉬는 시간을 침범하지 않기", "가족·집안일·일정 문제는 말보다 메모·공유 달력으로 남기기"],
    },
    {
      label: c,
      score: clamp(50 + elementScore * 1.8 + Math.max(0, branchScore) * 2),
      comment: "서로의 강점을 역할로 나누면 좋고, 책임 범위는 문서나 일정으로 분명히 하는 편이 좋습니다.",
      detail: "함께 무언가를 만들거나 돈과 일이 얽힐 때는 친밀감보다 역할 분담이 핵심입니다. 잘 맞는 부분은 속도를 내지만, 기준이 흐려지면 한쪽이 더 떠안는 느낌이 생길 수 있습니다. 관계가 좋을수록 '알아서 하겠지'로 넘기기 쉬운데, 그때가 오히려 책임선을 문서로 남겨둘 시점입니다.",
      signal: "성과나 비용을 나눌 때, 그리고 일이 몰리는 바쁜 시기에 역할 기준의 유무가 확 드러나요.",
      actions: ["각자 맡을 일과 마감일을 적기", "최종 결정권자와 비용 분담 기준을 미리 정하기", "고마움과 피드백을 따로 말하기"],
    },
    {
      label: d,
      score: clamp(55 + branchScore * 2.2 + Math.min(12, elementScore)),
      comment: "같이 움직일 때 편한 부분과 피로한 부분을 구분하면 오래 가기 쉽습니다.",
      detail: "이 관계는 계속 붙어 있는 것보다 어떤 상황에서 편하고 어떤 상황에서 피곤한지 구분할수록 좋아집니다. 여행, 모임, 일, 돈 문제처럼 에너지가 많이 드는 상황에서 차이가 선명하게 드러납니다. 편한 거리에서 만나면 오래 가고, 억지로 모든 걸 함께하려 하면 쉽게 지치는 유형에 가깝습니다.",
      signal: "여행·모임·금전처럼 에너지가 많이 드는 일을 함께할 때 편한 활동과 피로한 활동이 선명하게 갈려요.",
      actions: ["둘이 편한 활동과 피곤한 활동을 구분하기", "무리한 약속은 하루 전 다시 확인하기", "같이 움직인 뒤 혼자 회복할 시간 남기기"],
    },
  ];
}

function compatibilityBreakdownDetails(
  label: string,
  score: number,
  context: (typeof RELATION_CONTEXT)[CompatibilityRelationType],
): { detail: string; signal: string; actions: string[] } {
  const workRelation = isWorkRelation(context);
  if (label === "두 사람의 기질") {
    return {
      detail:
        workRelation && score >= 70
          ? `업무 기질에서 서로의 장단점을 이해하기 쉬운 편입니다. 한쪽이 방향을 잡고 다른 쪽이 실행하거나, 한쪽이 기준을 세우고 다른 쪽이 빈틈을 메우는 식으로 역할을 나누면 성과가 납니다. 다만 편하다고 해서 지시와 보고 기준을 생략하면 나중에 책임선이 흐려질 수 있습니다.`
          : workRelation && score >= 45
            ? `업무 방식이 완전히 같지는 않지만 서로 보완할 여지가 있습니다. 한 사람은 속도와 결과를 중시하고, 다른 사람은 안정감이나 절차를 더 볼 수 있어 프로젝트마다 기준을 맞추는 과정이 필요합니다. 방식 차이를 능력 차이로 보지 않는 것이 중요합니다.`
            : workRelation
              ? `업무 반응 속도와 판단 기준이 꽤 다르게 느껴질 수 있습니다. 한쪽은 바로 처리하고 싶고, 다른 쪽은 확인과 정리가 필요할 수 있어 같은 일을 두고도 답답함이 생기기 쉽습니다. 이때는 성격 문제가 아니라 업무 처리 방식 차이로 보고 규칙을 세워야 합니다.`
              : score >= 70
          ? `기본 기질에서 서로를 이해하기 쉬운 편입니다. 한쪽이 먼저 챙기거나 힘이 되어주는 흐름이 생기기 쉬워, 관계 초반에는 "말하지 않아도 통한다"는 느낌을 받을 수 있습니다. 다만 편해질수록 역할이 고정되면 한쪽이 더 많이 맞추는 구조가 될 수 있으니, 잘 맞는 만큼 고마움을 자주 말로 확인하는 편이 좋습니다.`
          : score >= 45
            ? `기질이 완전히 같지는 않지만, 서로의 방식이 낯설기만 한 조합은 아닙니다. 한 사람은 속도나 판단을 중시하고 다른 사람은 안정감이나 감정을 더 볼 수 있어, 상황마다 누가 주도권을 잡을지 정하는 것이 중요합니다. 방식이 다른 것을 우열로 보지 않으면 오히려 서로의 빈 곳을 메워줄 수 있습니다.`
            : `기본 반응 방식이 꽤 다르게 느껴질 수 있습니다. 한쪽은 바로 해결하고 싶어 하고, 다른 쪽은 시간을 두고 감정을 정리하려 할 수 있어 같은 문제를 두고도 "왜 저렇게 하지?"라는 생각이 생기기 쉽습니다. 이건 애정이나 성의의 문제가 아니라 처리 속도의 차이에 가깝습니다.`,
      signal:
        workRelation && score >= 70
          ? "급한 업무나 결정이 필요할 때 역할이 자연스럽게 나뉘면 강점이 드러나요."
          : workRelation
            ? "마감이 촉박하거나 수정이 반복될 때 반응 속도 차이가 오해로 번지기 쉬워요."
            : score >= 70
          ? "급한 결정이나 힘든 일이 생겼을 때 한쪽이 자연스럽게 리드하며 손발이 맞는 순간에 강점이 드러나요."
          : "결정을 급하게 몰아야 하거나 둘 다 지쳐 있을 때, 반응 속도 차이가 오해로 번지기 쉬워요.",
      actions: workRelation
        ? ["업무 반응을 성격 문제가 아니라 처리 방식 차이로 보기", "결정이 필요한 일은 결정권자와 마감부터 정하기", "좋았던 결과물 기준을 말과 예시로 남기기"]
        : ["상대 반응을 성격 문제로 단정하지 않기", "결정이 필요한 일은 각자 생각할 시간을 먼저 정하기", "고마운 행동은 미루지 말고 그 자리에서 말로 확인하기"],
    };
  }
  if (label === context.palaceLabel) {
    return {
      detail:
        workRelation && score >= 70
          ? `업무 자리에서는 요청·보고·피드백의 리듬이 비교적 맞는 편입니다. 방향을 주면 실행으로 옮기거나, 막힌 지점을 공유하는 흐름이 잘 만들어질 수 있습니다. 다만 잘 맞는다고 해서 구두로만 넘기면 기준이 흔들리니 업무 조건은 짧게라도 기록하는 편이 좋습니다.`
          : workRelation && score >= 45
            ? `업무 자리는 무난하지만 자동으로 맞아떨어지지는 않습니다. 지시 방식, 보고 빈도, 수정 기준을 확인해야 관계가 덜 흔들립니다. 초반에 "어디까지가 완료인지"를 정해두면 불필요한 피드백 갈등이 줄어듭니다.`
            : workRelation
              ? `함께 일할수록 작은 업무 습관 차이가 크게 느껴질 수 있습니다. 업무 속도, 확인 방식, 보고 타이밍이 다르면 한쪽은 압박으로, 다른 쪽은 무책임으로 받아들이기 쉽습니다. 감정보다 프로세스 정리가 먼저입니다.`
              : score >= 70
          ? `일상 친밀감이 쌓일수록 관계가 편해지는 편입니다. 데이트의 화려함보다 같이 쉬고, 먹고, 반복되는 하루를 공유할 때 안정감이 생기기 쉽습니다. 특별한 이벤트보다 사소한 루틴을 함께 만드는 쪽이 이 관계에는 더 잘 맞습니다.`
          : score >= 45
            ? `생활 자리는 무난하지만 자동으로 맞아떨어지는 관계는 아닙니다. 서로가 편한 휴식 방식, 연락 속도, 약속 잡는 기준을 확인해야 관계가 덜 흔들립니다. 초반에 "이건 이렇게 하자"를 몇 개만 정해두면 불필요한 서운함이 크게 줄어듭니다.`
            : `가까워질수록 사소한 습관 차이가 크게 느껴질 수 있습니다. 애정이 부족해서라기보다 생활 리듬의 결이 달라 피로가 생기는 쪽에 가깝습니다. 큰 사건이 아니라 연락 텀, 약속 잡는 방식, 쉬는 방식 같은 작은 반복에서 긴장이 쌓이기 쉽습니다.`,
      signal:
        workRelation && score >= 70
          ? "지시를 받은 뒤 결과물 방향이 크게 어긋나지 않을 때 업무 궁합이 드러나요."
          : workRelation
            ? "보고 타이밍, 수정 요청, 우선순위 변경에서 차이가 먼저 드러나요."
            : score >= 70
          ? "함께 보내는 평범한 하루(밥·휴식·이동)가 편안하게 느껴질 때 이 관계의 안정감이 확인돼요."
          : "연락 빈도, 약속 잡는 방식, 쉬는 방식처럼 작고 반복되는 습관에서 차이가 먼저 드러나요.",
      actions: workRelation
        ? ["업무 요청은 마감·결과물 형태·우선순위를 같이 적기", "보고 주기와 긴급 연락 기준을 정하기", "피드백은 감정이 아니라 수정 기준으로 말하기"]
        : ["연락 빈도와 만나는 주기를 대략이라도 맞춰두기", "쉬는 방식이 서로 다를 수 있음을 인정하기", "서운함은 감정이 아니라 '어떤 행동이 언제' 단위로 말하기"],
    };
  }
  if (label === "함께 있을 때 흐름") {
    return {
      detail:
        score >= 70
          ? `같이 움직일 때 손발이 잘 맞는 장면이 많습니다. 계획을 세우거나 일을 처리할 때 한쪽이 빈 곳을 채워주기 쉬워, 함께 할수록 효율이 올라갈 수 있습니다. 다만 잘 맞는다는 이유로 역할과 기준을 안 정해두면, 바쁠 때 한쪽에 일이 몰릴 수 있습니다.`
          : score >= 45
            ? `잘 맞는 부분과 부딪히는 부분이 함께 있습니다. 어떤 날은 호흡이 좋다가도, 피곤하거나 급한 상황에서는 말투와 속도 차이가 갈등으로 이어질 수 있습니다. 컨디션이 좋을 때의 모습만 보고 판단하지 말고, 지칠 때의 대화 방식을 미리 정해두는 편이 좋습니다.`
            : `함께 움직일 때 에너지 소모가 큰 편입니다. 같은 목표가 있어도 접근 방식이 달라 서로가 상대를 답답하게 느끼기 쉽습니다. 붙어서 다 맞추려 하기보다, 역할을 나누고 각자 방식대로 움직일 여지를 두는 편이 오히려 편합니다.`,
      signal:
        score >= 70
          ? "여행·이사·프로젝트처럼 함께 처리할 일이 생겼을 때 분업이 착착 맞는 순간에 강점이 드러나요."
          : "마감이 급하거나 둘 다 피곤한 상황에서 말투와 속도 차이가 갈등으로 번지기 쉬워요.",
      actions: ["중요한 일은 시작 전에 역할을 먼저 나누기", "감정이 올라오면 그 자리에서 결론내리지 않기", context.action],
    };
  }
  return {
    detail:
      score >= 70
        ? `서로 부족한 부분을 채워주는 힘이 분명합니다. 한 사람에게 자연스러운 것이 다른 사람에게는 도움이 되는 방식이라, 잘 쓰면 관계가 안정되고 현실적인 성과도 만들기 좋습니다. 서로의 강점을 "역할"로 인정해 두면 이 보완이 오래갑니다.`
        : score >= 45
          ? `서로 보완되는 면은 있지만 자동으로 편해지는 구조는 아닙니다. 도움을 주는 방식과 받는 방식이 다르면 좋은 의도도 간섭처럼 느껴질 수 있습니다. "무엇을, 언제, 어디까지" 도울지 구체적으로 맞추면 보완이 부담으로 바뀌지 않습니다.`
          : `서로 채워주는 힘보다 각자 부족한 부분이 동시에 드러날 수 있습니다. 관계를 좋게 만들려면 상대에게 기대기보다 각자의 생활 리듬을 먼저 안정시키는 것이 필요합니다. 둘 다 여유가 없을 때 서로에게 기대면 오히려 지치기 쉬우니, 각자의 기반을 먼저 챙기는 편이 좋습니다.`,
    signal:
      score >= 70
        ? "한 사람이 약한 영역을 다른 사람이 자연스럽게 메워줄 때(돈·계획·감정 챙김 등) 보완의 강점이 확인돼요."
        : "도움을 주는 방식과 받고 싶은 방식이 어긋날 때, 좋은 의도가 간섭처럼 느껴지기 쉬워요.",
    actions: ["상대가 잘하는 영역을 역할로 분명히 인정하기", "도움이 필요한 부분은 '무엇을 언제까지' 구체적으로 요청하기", "부족한 부분은 비난 대신 규칙·시스템으로 보완하기"],
  };
}

function compatibilityTiming(birthA: BirthInfo, birthB: BirthInfo, chartA: SajuChart, chartB: SajuChart): CompatibilityResult["timing"] {
  const now = new Date();
  const luckA = computeLuckCycles(birthA, now);
  const luckB = computeLuckCycles(birthB, now);
  const currentHits = [
    ...(luckA.luckInteractions ?? []).slice(0, 2).map((s) => `첫 번째 ${s}`),
    ...(luckB.luckInteractions ?? []).slice(0, 2).map((s) => `두 번째 ${s}`),
  ];
  const yearA = luckA.yearlyFlow?.find((y) => y.current) ?? luckA.yearlyFlow?.[0];
  const yearB = luckB.yearlyFlow?.find((y) => y.current) ?? luckB.yearlyFlow?.[0];
  const aCurrentDaYun = luckA.currentDaYun ? `첫 번째 현재 큰 흐름 ${luckA.currentDaYun}` : "첫 번째는 대운 시작 전 구간";
  const bCurrentDaYun = luckB.currentDaYun ? `두 번째 현재 큰 흐름 ${luckB.currentDaYun}` : "두 번째는 대운 시작 전 구간";

  return [
    {
      label: "지금 관계 분위기",
      body:
        currentHits.length > 0
          ? "올해와 이번 달 흐름에서 두 사람 모두 관계나 생활 리듬을 조정할 신호가 있습니다. 감정적으로 바로 결론 내리기보다 약속과 역할을 다시 맞추는 편이 좋습니다."
          : "현재 운 흐름에서 큰 흔들림 신호는 강하지 않습니다. 관계를 급하게 몰아가기보다 안정적으로 확인하는 흐름이 좋습니다.",
      evidence: currentHits.length > 0 ? currentHits.join(", ") : `${aCurrentDaYun}, ${bCurrentDaYun}`,
    },
    {
      label: `${luckA.year}년 관계 체크포인트`,
      body:
        (yearA?.interactions.length ?? 0) + (yearB?.interactions.length ?? 0) > 0
          ? "올해는 두 사람 모두 각자의 변화 신호가 있어, 관계 자체보다 개인 일정과 컨디션이 관계에 영향을 주기 쉽습니다."
          : "올해는 관계를 크게 흔드는 신호보다 기본 리듬을 유지하는 쪽이 중요합니다.",
      evidence: [
        yearA ? `첫 번째 ${yearA.year}년 ${yearA.ganZhi}: ${yearA.interactions.slice(0, 2).join(", ") || "강한 상호작용 적음"}` : "",
        yearB ? `두 번째 ${yearB.year}년 ${yearB.ganZhi}: ${yearB.interactions.slice(0, 2).join(", ") || "강한 상호작용 적음"}` : "",
        `일주 ${chartA.day.ganZhi}·${chartB.day.ganZhi}`,
      ]
        .filter(Boolean)
        .join(" / "),
    },
  ];
}

function compatibilityRepairReport(
  score: number,
  branches: ReturnType<typeof crossBranchRelations>,
  elements: ReturnType<typeof elementComplement>,
  palace: ReturnType<typeof relationToneFromDayBranches>,
  context: (typeof RELATION_CONTEXT)[CompatibilityRelationType],
): CompatibilityResult["repairReport"] {
  const copy = relationCopy(context);
  const level: NonNullable<CompatibilityResult["repairReport"]>["level"] =
    score < 55 || branches.badCount > branches.goodCount ? "repairFirst" : score < 75 || branches.badCount > 0 ? "needsCare" : "smooth";
  const hasBranchFriction = branches.badCount > 0;
  const weakComplement = elements.score < 10;
  const palaceFriction = palace.score < 0;

  const headline =
    level === "repairFirst"
      ? "좋고 나쁨보다 먼저, 부딪히는 방식을 정리해야 오래 갑니다"
      : level === "needsCare"
        ? "맞는 부분은 살리고, 반복되는 불편함은 규칙으로 줄이면 좋아집니다"
        : "잘 맞는 흐름을 당연하게 두지 말고 생활 습관으로 고정하면 더 안정됩니다";

  const intro =
    level === "repairFirst"
      ? `${context.label}로 볼 때 두 사람은 이어질 이유가 있어도 ${copy.area}에서 피로가 생기기 쉽습니다. 이 관계는 좋고 나쁨보다 "어떤 상황에서 서로가 힘들어지는지"를 먼저 알아야 합니다.`
      : level === "needsCare"
        ? `${context.label}로 볼 때 기본적으로 이어질 수 있는 힘은 있습니다. 다만 편해진 뒤에 ${copy.area}이 흐려지면 좋은 흐름도 쉽게 피곤해질 수 있습니다.`
        : `${context.label}로 볼 때 서로에게 안정감을 주는 부분이 있습니다. 이 장점은 저절로 유지되기보다 ${copy.area}을 계속 맞출 때 오래 갑니다.`;

  const whyItHappens = [
    hasBranchFriction
      ? "함께 있을 때 잘 맞는 장면도 있지만, 피곤하거나 급한 상황에서는 서로의 방식이 세게 다르게 느껴질 수 있습니다."
      : `강하게 부딪히는 신호는 약한 편이라, 큰 충돌보다 ${copy.area}을 당연하게 넘기는 흐름을 조심하면 좋습니다.`,
    weakComplement
      ? "서로가 부족한 부분을 자동으로 채워주는 힘은 강하지 않습니다. 그래서 상대에게 기대기보다 각자의 생활 리듬을 먼저 안정시키는 편이 좋습니다."
      : "서로 다른 강점이 있어 역할을 나누면 보완이 됩니다. 다만 도움을 주는 방식이 상대에게 간섭처럼 느껴지지 않게 말투를 조절해야 합니다.",
    palaceFriction
      ? `${copy.area}에서 사소한 차이가 예민하게 느껴질 수 있습니다. 감정으로 밀기보다 기준을 먼저 맞추는 편이 좋습니다.`
      : `${copy.area}을 잘 맞추면 관계가 훨씬 안정됩니다. 편해진 뒤에도 확인을 줄이지 않는 것이 중요합니다.`,
  ];

  const conflictCycle = [
    {
      step: "1단계. 기대가 말로 정리되지 않음",
      body: `한쪽은 ${copy.area}에 대한 기준을 상대도 알고 있을 거라 여기고, 다른 쪽은 갑자기 요구받는 느낌을 받을 수 있습니다.`,
      repair: `원하는 것을 성격 평가가 아니라 행동 기준으로 말하세요. ${copy.action}`,
    },
    {
      step: "2단계. 작은 불편함이 쌓임",
      body: "바로 말하면 싸울까 봐 넘기다가, 나중에는 작은 말투에도 크게 반응하기 쉽습니다.",
      repair: "불편함을 10점 만점 중 4점일 때 말하세요. 8점이 된 뒤에는 대화가 해결보다 방어로 흐르기 쉽습니다.",
    },
    {
      step: "3단계. 결론부터 내림",
      body: "상대의 행동을 '나를 무시한다', '책임감이 없다'처럼 사람 자체의 문제로 해석하면 갈등이 커집니다.",
      repair: "의도 단정 전에 사실, 영향, 요청을 나눠 말하세요. '어제 답이 늦어서 불안했어. 바쁠 때는 짧게라도 알려줘'처럼요.",
    },
    {
      step: "4단계. 회복 없이 넘어감",
      body: "싸움이 끝난 뒤에도 다시 맞추는 과정이 없으면 같은 문제가 반복됩니다.",
      repair: "대화 마지막에 다음 행동 하나만 정하세요. 거창한 약속보다 '다음 주까지 이것만 해보기'가 관계를 더 안정시킵니다.",
    },
  ];

  const byPerson = {
    me: [
      "내가 불편한 지점을 참다가 한 번에 터뜨리는지, 바로 확인해보는지 먼저 살피세요.",
      "상대가 바뀌어야 한다는 말보다 내가 원하는 행동을 한 문장으로 정리해 말하는 편이 좋습니다.",
      `${copy.frictionSignal}를 먼저 구분해야 감정 소모가 줄어듭니다.`,
    ],
    partner: [
      `상대는 내 기준을 이미 알고 있을 거라고 넘기지 말고, ${copy.area}을 구체적으로 확인해주는 편이 좋습니다.`,
      "방어적으로 설명하기보다 먼저 '그렇게 느낄 수 있겠다'고 받아주면 갈등이 훨씬 빨리 내려갑니다.",
      "좋은 의도로 한 조언도 타이밍이 맞지 않으면 간섭처럼 들릴 수 있으니, 먼저 필요한지 물어보는 방식이 좋습니다.",
    ],
    together: [
      context.action,
      `갈등 규칙을 하나 정하세요. ${copy.area}에서 문제가 생기면 언제, 어떤 방식으로 다시 맞출지 구체적일수록 좋습니다.`,
      "좋았던 점과 고칠 점을 같은 자리에서 섞지 말고 따로 말하세요. 칭찬은 칭찬대로, 조율은 조율대로 분리해야 덜 방어적입니다.",
    ],
  };

  const scripts = [
    "“내가 원하는 건 네가 틀렸다는 말이 아니라, 다음에는 이렇게 맞춰보자는 거야.”",
    "“지금 바로 결론내리면 서로 세게 말할 것 같아서, 오늘은 여기까지 정리하고 내일 다시 얘기하자.”",
    "“나는 이 부분에서 서운했어. 네 의도는 다를 수 있으니까, 어떻게 생각했는지 먼저 듣고 싶어.”",
    copy.script,
  ];

  const avoid = [
    "상대의 행동 하나를 보고 관계 전체를 단정하기",
    `답답하다는 이유로 ${copy.area} 문제를 한꺼번에 꺼내기`,
    "사과를 받자마자 바로 예전 일을 다시 꺼내기",
    copy.avoid,
  ];

  return { level, headline, intro, whyItHappens, conflictCycle, byPerson, scripts, avoid };
}

function compatibilityQuestionInsight(
  question: string | undefined,
  score: number,
  branches: ReturnType<typeof crossBranchRelations>,
  palace: ReturnType<typeof relationToneFromDayBranches>,
  context: (typeof RELATION_CONTEXT)[CompatibilityRelationType],
): CompatibilityResult["questionInsight"] | undefined {
  const clean = question?.trim();
  if (!clean) return undefined;
  const copy = relationCopy(context);

  const compact = clean.replace(/\s+/g, "");
  const isDecision = /계속|이어|정리|끊|그만|헤어|이혼|퇴사|동업|시작|고백|말해|연락|기다|만나|살/.test(compact);
  const asksMind = /마음|속마음|생각|좋아|싫어|진심|관심|나를/.test(compact);
  const asksConflict = /싸|갈등|불편|안맞|안 맞|서운|힘들|지쳐|문제|답답/.test(clean);
  const asksTiming = /언제|시기|올해|이번|지금|타이밍/.test(compact);
  const asksWork = /일|직장|회사|사업|동업|돈|성과|보고|상사|직원|동료/.test(compact);
  const asksFamily = /가족|부모|자식|엄마|아빠|형제|자매|남매|집안/.test(compact);

  const intent = asksMind
    ? copy.kind === "love"
      ? "상대의 마음을 단정해 달라는 질문이라기보다, 이 관계에서 내가 어떻게 받아들여지고 있는지 확인하고 싶은 질문입니다."
      : `${context.label}에서 상대가 나를 어떻게 받아들이는지보다, 실제로 ${copy.area}이 맞는지 확인하고 싶은 질문입니다.`
    : asksConflict
      ? `두 사람이 왜 반복해서 불편해지는지, 그리고 ${copy.area} 중 어디부터 조율해야 하는지 알고 싶은 질문입니다.`
      : asksTiming
        ? `지금 움직여도 되는지, 아니면 ${context.label}의 속도를 늦춰 확인해야 하는지 묻는 질문입니다.`
        : isDecision
          ? `${context.label}를 계속 이어갈지, 거리를 둘지, 기준을 다시 세울지 판단하고 싶은 질문입니다.`
          : asksWork || context.label.includes("업무") || context.label.includes("직원") || context.label.includes("동업")
            ? "감정보다 역할·책임·성과 기준이 맞는지 확인하고 싶은 질문입니다."
            : asksFamily || context.label.includes("가족") || context.label.includes("부모")
              ? "정과 책임 사이에서 어디까지 맞춰야 하는지 확인하고 싶은 질문입니다."
              : "이 관계가 내게 어떤 흐름인지, 편하게 이어가려면 무엇을 봐야 하는지 묻는 질문입니다.";

  const hasFriction = branches.badCount > 0 || palace.score < 0 || score < 55;
  const answer =
    score >= 75 && !hasFriction
      ? `${context.label}로 볼 때 기본 흐름은 좋은 편입니다. 다만 좋다는 말로 끝내기보다, 편해질수록 ${copy.area}을 생략하지 않는 것이 핵심입니다.`
      : score >= 55
        ? `${context.label}로 볼 때 이어갈 힘은 있지만 자동으로 편해지는 관계는 아닙니다. 지금 질문의 핵심은 좋고 나쁨보다, ${copy.area} 중 어떤 기준을 맞추면 덜 지치는지에 가깝습니다.`
        : `${context.label}로 볼 때 서로 다른 결이 분명합니다. 끊어야 한다고 단정할 수는 없지만, 감정으로 밀어붙이기보다 ${copy.area}의 기준을 먼저 정해야 합니다.`;

  const signals = [
    hasFriction
      ? copy.frictionSignal
      : copy.goodSignal,
    asksMind
      ? "상대의 말보다 반복 행동을 보세요. 약속을 지키는지, 불편한 대화 뒤 회복하려는 행동이 있는지가 더 중요합니다."
      : "서로가 원하는 것을 말했을 때 방어보다 조율로 이어지는지 확인하세요.",
    asksWork || context.label.includes("업무") || context.label.includes("동업")
      ? "마감, 돈, 결정권, 책임 범위를 적었을 때 오해가 줄어드는지 확인하세요."
      : `${copy.area}처럼 반복되는 문제를 하나씩 분리해서 말할 수 있는지 확인하세요.`,
  ];

  const actions = [
    "오늘은 이 관계에서 가장 불편한 지점을 하나만 적고, 상대 성격이 아니라 구체적 행동으로 바꿔 써보세요.",
    copy.action,
    isDecision
      ? "결정은 바로 내리지 말고, 이번 주 안에 바뀌어야 할 조건 2개와 내가 지킬 조건 1개를 먼저 정하세요."
      : `이번 주에는 큰 결론보다 ${copy.area} 중 하나를 골라 실제로 맞춰보세요.`,
  ];

  return { question: clean, intent, answer, signals, actions };
}

function seededPick<T>(items: T[], seed: string, count: number): T[] {
  const scored = items.map((item, index) => {
    let hash = 0;
    const text = `${seed}:${index}:${String(item)}`;
    for (let i = 0; i < text.length; i++) hash = (hash * 31 + text.charCodeAt(i)) >>> 0;
    return { item, score: hash };
  });
  return scored
    .sort((a, b) => a.score - b.score)
    .slice(0, count)
    .map((x) => x.item);
}

function includesAny(text: string, words: string[]) {
  return words.some((word) => text.includes(word));
}

function compatibilitySolutionPlan(
  score: number,
  branches: ReturnType<typeof crossBranchRelations>,
  elements: ReturnType<typeof elementComplement>,
  palace: ReturnType<typeof relationToneFromDayBranches>,
  context: (typeof RELATION_CONTEXT)[CompatibilityRelationType],
  chartA: SajuChart,
  chartB: SajuChart,
  questionInsight?: CompatibilityResult["questionInsight"],
  roleLabels = { first: "나", second: "상대" },
): CompatibilityResult["solutionPlan"] {
  const me = personSummary(roleLabels.first, chartA);
  const partner = personSummary(roleLabels.second, chartB);
  const myWeak = weakestElement(chartA.fiveElements);
  const myStrong = strongestElement(chartA.fiveElements);
  const partnerStrong = strongestElement(chartB.fiveElements);
  const hasFriction = score < 55 || branches.badCount > branches.goodCount || palace.score < 0;
  const hasQuestion = Boolean(questionInsight?.question);
  const relationshipLabel = context.label;
  const questionText = questionInsight?.question ?? "";
  const copy = relationCopy(context);
  const asksWork = includesAny(`${questionText}${relationshipLabel}`, ["일", "직장", "회사", "사업", "동업", "업무", "성과", "돈", "직원", "동료"]);
  const asksFamily = includesAny(`${questionText}${relationshipLabel}`, ["가족", "부모", "자식", "엄마", "아빠", "형제", "자매", "남매"]);
  const asksLove = includesAny(`${questionText}${relationshipLabel}`, ["연애", "연인", "배우자", "마음", "고백", "이별", "결혼"]);
  const asksFriend = copy.kind === "friend" || includesAny(`${questionText}${relationshipLabel}`, ["친구", "지인", "우정"]);
  const seed = [
    chartA.year.ganZhi,
    chartA.month.ganZhi,
    chartA.day.ganZhi,
    chartA.hour?.ganZhi ?? "no-hour-a",
    chartB.year.ganZhi,
    chartB.month.ganZhi,
    chartB.day.ganZhi,
    chartB.hour?.ganZhi ?? "no-hour-b",
    relationshipLabel,
    questionText,
    String(score),
  ].join("|");

  const title = hasQuestion ? "질문 기준으로 보는 관계 맞춤 솔루션" : `${relationshipLabel} 맞춤 솔루션`;
  const problem = hasQuestion
    ? `지금 핵심은 "${questionInsight?.question}"에 대한 답을 바로 단정하는 것이 아니라, 이 관계에서 반복되는 부담과 확인해야 할 조건을 분리하는 것입니다.`
    : `${relationshipLabel}로 볼 때 핵심은 점수보다 ${copy.area}에서 편한 접점과 피로한 접점을 나눠보는 것입니다.`;

  const personalContext = `${me.label}는 ${me.dayMaster} 기질을 중심으로 ${me.strongestElement}이 강하고, ${me.weakestElement}은 보완하면 좋은 편입니다. 그래서 이 관계에서는 내 방식만 밀기보다, 약한 부분을 상대에게 어떻게 요청할지 먼저 정리하는 것이 중요합니다.`;

  const relationshipContext =
    score >= 75 && !hasFriction
      ? `${partner.label}는 ${partner.dayMaster} 기질을 중심으로 움직이며, 두 사람은 기본 흐름이 꽤 안정적입니다. 다만 편하다는 이유로 ${copy.area}을 생략하면 나중에 작은 불편함이 쌓일 수 있습니다.`
      : score >= 55
        ? `${partner.label}는 ${partner.dayMaster} 기질을 중심으로 움직이며, 두 사람은 맞는 부분과 다른 부분이 함께 있습니다. 좋게 이어가려면 감정 확인보다 ${copy.area}을 현실적으로 맞추는 과정이 필요합니다.`
        : `${partner.label}는 ${partner.dayMaster} 기질을 중심으로 움직이며, 두 사람은 결이 다른 부분이 선명합니다. 관계를 바로 포기하라는 뜻은 아니지만, 마음만으로 밀기보다 ${copy.area}의 규칙을 먼저 만들어야 피로가 줄어듭니다.`;

  const priority = hasFriction
    ? `1순위는 관계를 더 깊게 밀어붙이는 것이 아니라, ${copy.area}에서 부딪히는 장면을 줄이는 운영 규칙을 정하는 것입니다.`
    : elements.score < 10
      ? "1순위는 서로에게 과하게 기대기보다, 각자 부족한 부분을 생활 습관과 역할 분담으로 보완하는 것입니다."
      : `1순위는 잘 맞는 부분을 당연하게 두지 않고, ${copy.area}을 반복 가능한 좋은 습관으로 고정하는 것입니다.`;

  const weakElementActions: Record<keyof FiveElementBalance, string[]> = {
    wood: [
      "막연히 참기보다 새로 시도할 행동을 하나 정하세요. 예: 먼저 연락하기, 대화 시간을 잡기, 역할표를 새로 쓰기.",
      "관계가 답답하면 큰 결론보다 작은 시작을 만드세요. 예: 20분 산책 대화, 한 가지 부탁만 말하기.",
      "상대에게 바라는 변화를 말할 때는 '앞으로 이렇게 해보자'처럼 다음 행동으로 표현하세요.",
    ],
    fire: [
      "마음을 숨기기보다 좋은 감정과 불편한 감정을 각각 한 문장씩 표현하세요.",
      "분위기가 식었다고 느끼면 거창한 이벤트보다 짧은 칭찬, 감사 표현, 안부 확인을 먼저 늘리세요.",
      "말하지 않아도 알겠지라고 넘기지 말고, 관계에서 따뜻했던 장면을 구체적으로 말해보세요.",
    ],
    earth: [
      "관계가 흔들릴수록 생활 기준을 잡으세요. 예: 연락 시간, 만나는 주기, 돈 쓰는 기준, 역할 분담.",
      "감정 대화 뒤에는 꼭 실행 기준 하나를 남기세요. 예: '다음에는 약속 변경을 하루 전에 말하기'.",
      "관계를 오래 보고 싶다면 말보다 반복 가능한 루틴을 만드세요. 예: 주 1회 확인 대화, 월 1회 돈 기준 점검.",
    ],
    metal: [
      "상대가 서운하게 한 일을 한꺼번에 말하지 말고, 가장 중요한 기준 하나만 또렷하게 말하세요.",
      "거절해야 할 부탁과 받아줄 수 있는 부탁을 구분하세요. 애매하게 넘길수록 나중에 더 피곤해집니다.",
      "관계가 흐려질 때는 기준을 세우세요. 예: 말투, 약속, 돈, 가족 문제에서 넘지 말아야 할 선.",
    ],
    water: [
      "바로 반응하기 전에 내 감정이 서운함인지 불안인지 피로인지 먼저 적어보세요.",
      "대화 전 10분 정도 혼자 정리한 뒤 말하세요. 감정이 올라온 상태에서 결론내리면 말이 세질 수 있습니다.",
      "상대의 말보다 반복 행동을 관찰하세요. 약속을 지키는지, 회복하려는 행동이 있는지가 더 중요합니다.",
    ],
  };

  const strongElementActions: Record<keyof FiveElementBalance, string[]> = {
    wood: ["내가 먼저 방향을 잡는 힘은 장점이지만, 상대에게도 선택지를 2개 이상 주세요."],
    fire: ["표현력이 강한 편이면 감정을 바로 쏟기보다 핵심 요구를 짧게 말하는 쪽이 더 잘 전달됩니다."],
    earth: ["책임감이 강한 편이면 혼자 떠안기 전에 상대의 몫을 구체적으로 나눠주세요."],
    metal: ["기준이 또렷한 편이면 맞고 틀림보다 서로 지킬 최소 기준부터 합의하세요."],
    water: ["생각이 깊은 편이면 오래 혼자 해석하지 말고 확인 질문을 짧게 던지세요."],
  };

  const relationActions = asksWork
    ? [
        "역할, 마감, 비용, 최종 결정권을 짧은 메모로 남겨보세요.",
        "감정이 아니라 결과물 기준으로 말하세요. 예: '언제까지 어떤 형태로 받을지'를 먼저 정하기.",
        "친분과 업무 기준을 분리하세요. 고마움은 따로 말하고, 수정 요청은 문서처럼 남기는 편이 좋습니다.",
        "돈이나 성과가 얽힌 관계라면 시작 전에 중단 조건과 정산 기준을 정하세요.",
      ]
    : asksFamily
      ? [
          "가족이라도 도와줄 수 있는 범위와 어려운 범위를 따로 말해두세요.",
          "부모님·자식·형제 문제는 감정 대화 전에 돈, 시간, 돌봄 범위를 숫자로 정리하세요.",
          "정 때문에 바로 떠안기보다 내가 할 몫과 상대가 할 몫을 분리하세요.",
          "오래된 가족 역할에 갇히지 않도록 '이번에는 내가 여기까지만 할게'처럼 범위를 말하세요.",
        ]
      : asksFriend
        ? [
            "부탁과 거절 기준을 미리 가볍게 말하세요.",
            "돈 문제는 금액이 작아도 기한과 방식을 분명히 하세요.",
            "연락 텀을 애정이나 의리로 재단하지 말고 서로의 생활 리듬으로 인정하세요.",
            "친해서 괜찮겠지로 넘기지 말고, 불편한 부탁은 바로 작게 말하세요.",
          ]
        : asksLove
        ? [
            "연락 빈도, 만나는 주기, 서운함을 말하는 방식을 먼저 맞추세요.",
            "상대 마음을 추측하기보다 반복 행동을 보세요. 약속을 지키는지, 회복하려는 행동이 있는지가 핵심입니다.",
            "애정 확인을 몰아붙이기보다 이번 주에 지켜볼 행동 기준 2개를 정하세요.",
            "좋아하는 마음과 생활 기준은 따로 확인하세요. 마음이 있어도 생활 리듬이 안 맞으면 피로가 쌓입니다.",
          ]
        : [
            "연락, 만남, 돈, 일정 중 가장 자주 부딪히는 항목 하나만 골라 기준을 맞춰보세요.",
            "관계가 편해도 부탁과 거절의 기준은 흐리지 마세요.",
            "좋은 관계일수록 사소한 서운함을 너무 오래 묵히지 않는 것이 중요합니다.",
            "같이 있을 때 편한 활동과 피곤한 활동을 따로 구분해보세요.",
          ];

  const frictionActions = hasFriction
    ? [
        "갈등이 생긴 뒤에는 바로 끝내지 말고, 다음에는 무엇을 다르게 할지 하나만 합의하세요.",
        "서운함이 10점 중 4점일 때 말하세요. 8점이 된 뒤에는 해결보다 방어가 먼저 나옵니다.",
        "피곤한 날에는 중요한 결론을 미루고, 사실 확인만 하세요.",
        "상대의 의도를 단정하기 전에 '내가 이해한 게 맞아?'라고 한 번 확인하세요.",
      ]
    : [
        "좋았던 행동을 구체적으로 말해 관계의 강점을 습관으로 고정하세요.",
        "편해졌다고 표현을 줄이지 말고, 작은 고마움을 바로 말하세요.",
        "무난한 흐름일수록 돈, 일정, 가족 문제 같은 현실 기준을 미리 맞춰두세요.",
        "잘 맞는다고 느끼는 장면을 반복 가능한 루틴으로 만들어두세요.",
      ];

  const stopPool = [
    "상대의 행동 하나만 보고 관계 전체를 바로 판단하지 않기",
    "답답한 마음이 올라온 날에 결론, 이별, 동업 중단, 손절 같은 큰 결정을 바로 내리지 않기",
    hasFriction
      ? "서운한 일을 오래 쌓아두다가 한 번에 터뜨리지 않기"
      : "편하다는 이유로 고마움 표현과 확인 질문을 줄이지 않기",
    myStrong === "metal" ? "내 기준이 맞다는 확신만으로 상대의 속도를 재단하지 않기" : "내 방식이 편하다는 이유로 상대의 리듬을 무시하지 않기",
    myStrong === "fire" ? "감정이 올라온 순간에 긴 메시지로 몰아치지 않기" : "말을 아끼다가 상대가 알아서 눈치채길 기다리지 않기",
    asksWork ? "일 문제를 친분이나 정으로 덮지 않기" : copy.avoid,
  ];

  const todayPool = [
    hasQuestion
      ? "내 질문을 '상대가 어떤 사람인가'가 아니라 '내가 확인해야 할 조건은 무엇인가'로 다시 써보세요."
      : `${copy.area}에서 편한 장면 1개와 피곤한 장면 1개를 각각 적어보세요.`,
    "상대에게 바라는 것을 성격 평가가 아니라 행동 요청 한 문장으로 바꿔보세요.",
    context.action,
    ...weakElementActions[myWeak],
    ...strongElementActions[myStrong],
    ...seededPick(relationActions, `${seed}:relation-today`, 2),
  ];

  const weekPool = [
    "이번 주에는 큰 결론보다 작은 약속 하나를 정하고 실제로 지켜지는지 확인하세요.",
    ...relationActions,
    ...frictionActions,
    partnerStrong === "earth"
      ? "상대가 안정감을 중시하는 편이라면 말보다 약속을 지키는 모습으로 신뢰를 쌓으세요."
      : "상대가 움직임이 빠른 편이라면 결정 전에 확인해야 할 기준을 짧게 정리해 공유하세요.",
    myWeak === "water"
      ? "이번 주에는 중요한 대화 전 메모장에 감정, 사실, 요청을 나눠 적고 시작하세요."
      : `이번 주에는 ${copy.area}에서 반복되는 장면 하나를 기록해 다음 대화의 근거로 쓰세요.`,
  ];

  const scriptPool = [
    `“내가 지금 확인하고 싶은 건 너를 몰아붙이려는 게 아니라, ${copy.area}에서 반복해서 힘들어지는 지점을 줄이는 방법이야.”`,
    "“나는 이 부분에서 부담을 느껴. 다음에는 이렇게 해주면 훨씬 편할 것 같아.”",
    asksWork ? copy.script : "“지금 바로 결론내리기보다 이번 주에 이 약속 하나가 지켜지는지 보고 다시 얘기하자.”",
    myWeak === "fire"
      ? "“내가 표현이 부족해서 애매하게 보였을 수 있어. 내가 원하는 건 이거야.”"
      : "“감정적으로 말하고 싶지는 않아서, 사실과 요청을 나눠서 말해볼게.”",
    myWeak === "earth"
      ? "“우리 이 문제를 느낌으로 넘기지 말고, 다음부터 어떻게 할지 기준을 하나 정하자.”"
      : "“내가 지금 원하는 건 큰 약속보다 오늘부터 바꿀 수 있는 작은 행동 하나야.”",
    asksFamily || asksFriend ? copy.script : "“내가 서운했던 건 네 사람이 싫어서가 아니라, 이 행동이 반복돼서 힘들었던 거야.”",
    asksLove
      ? "“나를 좋아하는지 단정해달라는 게 아니라, 우리가 서로 편해지는 방식을 맞춰보고 싶어.”"
      : `“이번에는 누가 맞고 틀렸는지보다 ${copy.area}에서 다음에 어떻게 할지 정하자.”`,
  ];

  const signalPool = [
    "내가 요청을 구체적으로 말했을 때 상대가 방어보다 조율로 반응하는지",
    "같은 문제가 반복될 때 서로가 책임을 미루기보다 다음 행동을 정하는지",
    hasFriction
      ? "피곤하거나 바쁜 날에도 말투와 약속 기준이 크게 무너지지 않는지"
      : copy.goodSignal,
    asksWork ? "역할과 마감을 적었을 때 실제 오해가 줄어드는지" : "서운함을 말한 뒤 상대가 행동을 조금이라도 바꾸는지",
    myWeak === "metal" ? "애매한 부탁과 거절을 분명히 했을 때 마음이 덜 소모되는지" : "내가 원하는 것을 말로 꺼냈을 때 관계가 더 편해지는지",
    partnerStrong === "water" ? "상대가 바로 답하지 않아도 시간을 준 뒤 더 깊게 반응하는지" : "상대가 말보다 행동으로 안정감을 보여주는지",
  ];

  const stopDoing = seededPick(stopPool, `${seed}:stop`, 3);
  const todayActions = seededPick(todayPool, `${seed}:today`, 4);
  const weekActions = seededPick(weekPool, `${seed}:week`, 4);
  const scripts = seededPick(scriptPool, `${seed}:scripts`, 4);
  const checkSignals = seededPick(signalPool, `${seed}:signals`, 4);

  return {
    title,
    problem,
    personalContext,
    relationshipContext,
    priority,
    stopDoing,
    todayActions,
    weekActions,
    scripts,
    checkSignals,
  };
}

/**
 * 두 사람의 사주 궁합을 계산한다 (결정론적, 참고용).
 * 일간 관계 + 지지 합충 + 오행 보완을 종합해 0~100 점수로 환산한다.
 */
export function computeCompatibility(
  birthA: BirthInfo,
  birthB: BirthInfo,
  relationType: CompatibilityRelationType = "romantic",
  question?: string,
  roleLabels = { first: "나", second: "상대" },
): CompatibilityResult {
  const context = RELATION_CONTEXT[relationType] ?? RELATION_CONTEXT.romantic;
  const chartA = computeSajuChart(birthA);
  const chartB = computeSajuChart(birthB);

  const zhisA = [chartA.year.zhi, chartA.month.zhi, chartA.day.zhi, ...(chartA.hour ? [chartA.hour.zhi] : [])];
  const zhisB = [chartB.year.zhi, chartB.month.zhi, chartB.day.zhi, ...(chartB.hour ? [chartB.hour.zhi] : [])];

  const dm = dayMasterRelation(chartA.dayMasterGan, chartB.dayMasterGan);
  const branches = crossBranchRelations(zhisA, zhisB);
  const elements = elementComplement(chartA.fiveElements, chartB.fiveElements);
  const palace = relationToneFromDayBranches(chartA.day.zhi, chartB.day.zhi);
  const roles = roleChemistry(chartA, chartB, roleLabels);

  const branchScore = Math.max(-14, Math.min(18, branches.goodCount * 7 - branches.badCount * 5));
  const raw = 55 + dm.score + branchScore + elements.score + palace.score;
  const score = Math.max(0, Math.min(100, Math.round(raw)));

  const baseBreakdown = [
    { label: "두 사람의 기질", score: Math.round((dm.score / 22) * 100), note: dm.text },
    { label: context.palaceLabel, score: Math.max(0, Math.min(100, 55 + palace.score * 3)), note: palace.body },
    {
      label: "함께 있을 때 흐름",
      score: Math.max(0, Math.min(100, 50 + branchScore * 3)),
      note:
        (branches.good.length ? `잘 맞음: ${branches.good.join(", ")}` : "뚜렷하게 붙는 부분은 없어요") +
        (branches.bad.length ? ` / 주의: ${branches.bad.join(", ")}` : " / 큰 충돌은 없어요"),
    },
    { label: "서로 채워주는 부분", score: Math.round((elements.score / 20) * 100), note: elements.text },
  ];
  const breakdown = baseBreakdown.map((item) => ({ ...item, ...compatibilityBreakdownDetails(item.label, item.score, context) }));

  // 가장 강한 축과 가장 조율이 필요한 축을 짚어, 종합 요약을 구체적으로 만든다.
  const sortedByScore = [...breakdown].sort((x, y) => y.score - x.score);
  const strongAxis = sortedByScore[0];
  const weakAxis = sortedByScore[sortedByScore.length - 1];
  const axisDiffers = strongAxis.label !== weakAxis.label;
  const strongPhrase = `특히 '${strongAxis.label}'이(가) 이 관계의 강점이에요`;
  const weakPhrase = axisDiffers ? `, '${weakAxis.label}'은(는) 기준을 미리 맞춰두면 편해집니다` : "";

  const summary =
    score >= 75
      ? `${context.label}로 볼 때 서로 잘 맞고 보완이 되는 흐름입니다. ${strongPhrase}${weakPhrase}. 다른 점도 성장으로 쓰기 좋습니다.`
      : score >= 55
        ? `${context.label}로 볼 때 무난하게 맞는 부분이 있습니다. ${strongPhrase}${weakPhrase}. 몇 가지 기준만 조율하면 관계가 더 편안해집니다.`
        : `${context.label}로 볼 때 결이 다른 부분이 있습니다. 그래도 ${strongPhrase}${weakPhrase}. 서로의 다름을 이해하고 접점의 기준을 정하는 노력이 필요합니다.`;

  const cautionPoints = [
    ...(branches.bad.length > 0
      ? ["감정이 올라왔을 때 바로 결론을 내리면 서로의 의도를 오해하기 쉽습니다."]
      : ["큰 충돌 신호는 약한 편이지만, 익숙해질수록 표현이 줄어들 수 있습니다."]),
    score < 55
      ? "속도와 기대치가 다를 수 있으니 약속, 연락, 돈 문제는 처음부터 기준을 맞추는 편이 좋습니다."
      : context.caution,
  ];

  const actionPlan = [
    "서운한 점은 바로 판정하지 말고, 구체적인 상황과 원하는 행동을 한 문장으로 말해보세요.",
    "중요한 결정은 감정이 올라온 날보다 하루 뒤에 다시 확인하는 편이 안정적입니다.",
    context.action,
  ];

  const highlights = [
    ...(isWorkRelation(context)
      ? [
          {
            title: "업무가 맞는 지점",
            body: dm.text,
            action: "좋은 성과가 나온 업무 방식은 말로만 넘기지 말고 예시와 기준으로 남겨두세요.",
          },
          {
            title: "어긋나기 쉬운 지점",
            body: branches.bad.length > 0 ? branches.bad.join(" ") : "강하게 부딪히는 신호는 약하지만, 기준을 생략하면 오해가 생길 수 있습니다.",
            action: "갈등이 생기면 성격 문제가 아니라 지시·보고·검수 방식 차이로 놓고 조율하세요.",
          },
          {
            title: "함께 일하는 방법",
            body: palace.body,
            action: "업무 요청은 마감, 결과물 형태, 우선순위를 같이 적고 피드백은 수정 기준으로 말하세요.",
          },
        ]
      : [
          {
            title: "끌리는 지점",
            body: dm.text,
            action: "처음 좋았던 부분을 당연하게 여기지 말고 자주 말로 확인해 주세요.",
          },
          {
            title: "부딪히는 지점",
            body: branches.bad.length > 0 ? branches.bad.join(" ") : "크게 세게 부딪히는 신호는 약한 편입니다.",
            action: "갈등이 생기면 성격 문제가 아니라 방식 차이로 놓고 조율하는 편이 좋습니다.",
          },
          {
            title: "오래 가는 방법",
            body: palace.body,
            action: "서로가 편해지는 생활 기준을 초반에 맞추고, 감정이 올라올 때는 잠시 속도를 늦추세요.",
          },
        ]),
  ];
  const purposes = purposeFits(score, branchScore, elements.score, palace.score, context);
  const timing = compatibilityTiming(birthA, birthB, chartA, chartB);
  const repairReport = compatibilityRepairReport(score, branches, elements, palace, context);
  const questionInsight = compatibilityQuestionInsight(question, score, branches, palace, context);
  const solutionPlan = compatibilitySolutionPlan(score, branches, elements, palace, context, chartA, chartB, questionInsight, roleLabels);
  const expertEvidence = [
    `관계 유형: ${context.label}`,
    `일간 관계: ${chartA.dayMasterGan}·${chartB.dayMasterGan} / ${dm.text}`,
    `일지 관계: ${chartA.day.zhi}·${chartB.day.zhi} / ${palace.evidence}`,
    `상대 십성: ${roles?.map((r) => r.evidence).join(" / ")}`,
    `전체 지지 상호작용: ${[...branches.good, ...branches.bad].join(", ") || "강한 합충형파해 신호 적음"}`,
    `오행 보완: ${elements.text}`,
    `현재 시기 흐름: ${timing?.map((t) => t.evidence).join(" / ")}`,
  ];

  return {
    relationType,
    relationLabel: context.label,
    score,
    dayMasterRelation: dm.text,
    branchRelations: [...branches.good, ...branches.bad],
    elementComplement: elements.text,
    summary,
    questionInsight,
    solutionPlan,
    breakdown,
    highlights,
    cautionPoints,
    actionPlan,
    repairReport,
    improvementTips: context.improvement,
    partnerPalace: { title: palace.title, body: palace.body, evidence: palace.evidence },
    roleChemistry: roles,
    purposeFits: purposes,
    timing,
    expertEvidence,
    people: [personSummary(roleLabels.first, chartA), personSummary(roleLabels.second, chartB)],
  };
}
