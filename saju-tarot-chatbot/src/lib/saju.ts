import { Lunar, Solar } from "lunar-javascript";
import type {
  BirthInfo,
  CompatibilityResult,
  FiveElementBalance,
  GyeokgukInfo,
  LuckCycles,
  MonthFlowInfo,
  SajuChart,
  SajuPillar,
  SinsalHit,
  StrengthAssessment,
  TimeCorrection,
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

function computeGyeokguk(dayGan: string, monthZhi: string, strength: StrengthAssessment): GyeokgukInfo {
  const stems = HIDDEN_STEMS[monthZhi] ?? [];
  const main = stems[stems.length - 1] ?? "";
  const tenGod = tenGodOf(dayGan, main);
  const base = GYEOKGUK_BY_TENGOD[tenGod] ?? { name: "일반격", gloss: "뚜렷한 격이 잡히지 않는 균형형 구조예요." };

  const ratio = strength.supportScore / strength.totalScore;
  // 극도로 치우치면 종격 후보로 표시 (참고용)
  if (ratio <= 0.2) {
    return {
      name: `${base.name} · 종격(從格) 후보`,
      basis: `월지 ${monthZhi}의 정기(${main}) 기준 ${tenGod} + 일간이 매우 약함(지지세력 ${(ratio * 100).toFixed(0)}%)`,
      gloss: `${base.gloss} 다만 일간이 매우 약해, 강한 세력을 따라가는 종격으로 볼 여지도 있어요(관법에 따라 달라지는 참고용).`,
    };
  }
  if (ratio >= 0.8) {
    return {
      name: `${base.name} · 종왕/종강격 후보`,
      basis: `월지 ${monthZhi}의 정기(${main}) 기준 ${tenGod} + 일간이 매우 강함(지지세력 ${(ratio * 100).toFixed(0)}%)`,
      gloss: `${base.gloss} 다만 일간이 매우 강해, 그 힘을 그대로 쓰는 종왕/종강격으로 볼 여지도 있어요(참고용).`,
    };
  }
  return {
    name: base.name,
    basis: `월지 ${monthZhi}의 정기(${main}) 기준 일간과의 관계 = ${tenGod}`,
    gloss: base.gloss,
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

  const twelveStages = zhis.map((z) => `${z.label} ${z.char}: ${twelveStageOf(dayGan, z.char)}`);
  const gongmangZhis = gongmangOf(dayGan, dayPillar.zhi);
  const gongmangHits = zhis.filter((z) => gongmangZhis.includes(z.char)).map((z) => `${z.label} ${z.char}`);
  const gongmang = `${gongmangZhis} 공망${gongmangHits.length > 0 ? ` (원국 내 해당: ${gongmangHits.join(", ")})` : " (원국 내 해당 지지 없음)"}`;

  const sinsal = computeSinsal(dayGan, dayPillar.zhi, monthPillar.zhi, yearPillar.zhi, gans, zhis);
  const gyeokguk = computeGyeokguk(dayGan, monthPillar.zhi, strength);
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

/**
 * 두 사람의 사주 궁합을 계산한다 (결정론적, 참고용).
 * 일간 관계 + 지지 합충 + 오행 보완을 종합해 0~100 점수로 환산한다.
 */
export function computeCompatibility(birthA: BirthInfo, birthB: BirthInfo): CompatibilityResult {
  const chartA = computeSajuChart(birthA);
  const chartB = computeSajuChart(birthB);

  const zhisA = [chartA.year.zhi, chartA.month.zhi, chartA.day.zhi, ...(chartA.hour ? [chartA.hour.zhi] : [])];
  const zhisB = [chartB.year.zhi, chartB.month.zhi, chartB.day.zhi, ...(chartB.hour ? [chartB.hour.zhi] : [])];

  const dm = dayMasterRelation(chartA.dayMasterGan, chartB.dayMasterGan);
  const branches = crossBranchRelations(zhisA, zhisB);
  const elements = elementComplement(chartA.fiveElements, chartB.fiveElements);

  const branchScore = Math.max(-14, Math.min(18, branches.goodCount * 7 - branches.badCount * 5));
  const raw = 55 + dm.score + branchScore + elements.score;
  const score = Math.max(0, Math.min(100, Math.round(raw)));

  const breakdown = [
    { label: "두 사람의 기질", score: Math.round((dm.score / 22) * 100), note: dm.text },
    {
      label: "함께 있을 때 흐름",
      score: Math.max(0, Math.min(100, 50 + branchScore * 3)),
      note:
        (branches.good.length ? `잘 맞음: ${branches.good.join(", ")}` : "뚜렷하게 붙는 부분은 없어요") +
        (branches.bad.length ? ` / 주의: ${branches.bad.join(", ")}` : " / 큰 충돌은 없어요"),
    },
    { label: "서로 채워주는 부분", score: Math.round((elements.score / 20) * 100), note: elements.text },
  ];

  const summary =
    score >= 75
      ? "서로 잘 맞고 보완이 되는 좋은 궁합이에요. 다른 점도 성장으로 쓰기 좋아요."
      : score >= 55
        ? "무난하게 잘 어울리는 궁합이에요. 몇 가지만 서로 배려하면 편안해요."
        : "결이 다른 부분이 있는 궁합이에요. 서로의 다름을 이해하려는 노력이 관계를 키워요.";

  const cautionPoints = [
    ...(branches.bad.length > 0
      ? ["감정이 올라왔을 때 바로 결론을 내리면 서로의 의도를 오해하기 쉽습니다."]
      : ["큰 충돌 신호는 약한 편이지만, 익숙해질수록 표현이 줄어들 수 있습니다."]),
    score < 55
      ? "속도와 기대치가 다를 수 있으니 약속, 연락, 돈 문제는 처음부터 기준을 맞추는 편이 좋습니다."
      : "잘 맞는다고 느낄수록 상대가 알아서 이해해줄 거라 넘기지 않는 것이 좋습니다.",
  ];

  const actionPlan = [
    "서운한 점은 바로 판정하지 말고, 구체적인 상황과 원하는 행동을 한 문장으로 말해보세요.",
    "중요한 결정은 감정이 올라온 날보다 하루 뒤에 다시 확인하는 편이 안정적입니다.",
    "둘 다 편한 방식만 고집하기보다 연락 빈도, 돈 쓰는 방식, 쉬는 방식의 최소 기준을 정해두세요.",
  ];

  const highlights = [
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
      body: elements.text,
      action: "서로가 잘하는 역할을 나누고, 부족한 쪽을 비난보다 보완으로 다루세요.",
    },
  ];

  return {
    score,
    dayMasterRelation: dm.text,
    branchRelations: [...branches.good, ...branches.bad],
    elementComplement: elements.text,
    summary,
    breakdown,
    highlights,
    cautionPoints,
    actionPlan,
    people: [personSummary("첫 번째 사람", chartA), personSummary("두 번째 사람", chartB)],
  };
}
