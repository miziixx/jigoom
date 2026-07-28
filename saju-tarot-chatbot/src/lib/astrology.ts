// astronomy-engine은 CJS라 tsx(롱폴링) ESM 로더에서 named import가 안 풀린다.
// createRequire로 CJS module.exports를 직접 가져와 tsx·Vercel 양쪽에서 동작하게 한다. (봇 복사본 전용)
import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const { Body, EclipticLongitude, SiderealTime, SunPosition } =
  require("astronomy-engine") as typeof import("astronomy-engine");
// Body는 값(enum)이자 타입으로 쓰인다. require는 값만 주므로 타입은 별칭으로 따로 확보한다.
type Body = import("astronomy-engine").Body;
import { Lunar } from "lunar-javascript";
import { BIRTH_PLACES } from "../data/birthPlaces.js";
import type {
  AstrologyAspect,
  AstrologyPlacement,
  AstrologyTransitTheme,
  AstrologyProfile,
  BirthInfo,
  ClassicalPlacement,
  VedicDashaInfo,
  VedicPlacement,
  ZodiacSign,
} from "../types/index.js";

const SIGNS: ZodiacSign[] = [
  "양자리",
  "황소자리",
  "쌍둥이자리",
  "게자리",
  "사자자리",
  "처녀자리",
  "천칭자리",
  "전갈자리",
  "사수자리",
  "염소자리",
  "물병자리",
  "물고기자리",
];

const SIGN_RULER: Record<ZodiacSign, string> = {
  양자리: "화성",
  황소자리: "금성",
  쌍둥이자리: "수성",
  게자리: "달",
  사자자리: "태양",
  처녀자리: "수성",
  천칭자리: "금성",
  전갈자리: "화성",
  사수자리: "목성",
  염소자리: "토성",
  물병자리: "토성",
  물고기자리: "목성",
};

const BODY_LABEL: Record<string, string> = {
  Sun: "태양",
  Moon: "달",
  Mercury: "수성",
  Venus: "금성",
  Mars: "화성",
  Jupiter: "목성",
  Saturn: "토성",
  Uranus: "천왕성",
  Neptune: "해왕성",
  Pluto: "명왕성",
};

const MODERN_KEYWORD: Record<string, string> = {
  태양: "삶의 방향과 자아감",
  달: "감정 습관과 안정 욕구",
  상승궁: "첫인상과 방어 방식",
  금성: "사랑받고 싶은 방식",
  화성: "욕망과 추진력",
};

export const NAKSHATRAS = [
  "아슈위니",
  "바라니",
  "크리티카",
  "로히니",
  "므리기사라",
  "아르드라",
  "푸나르바수",
  "푸샤",
  "아슐레샤",
  "마가",
  "푸르바 팔구니",
  "우타라 팔구니",
  "하스타",
  "치트라",
  "스와티",
  "비샤카",
  "아누라다",
  "제슈타",
  "물라",
  "푸르바 아샤다",
  "우타라 아샤다",
  "슈라바나",
  "다니슈타",
  "샤타비샤",
  "푸르바 바드라파다",
  "우타라 바드라파다",
  "레바티",
];

const VIMSHOTTARI_SEQUENCE = ["케투", "금성", "태양", "달", "화성", "라후", "목성", "토성", "수성"];
const DASHA_YEARS: Record<string, number> = {
  케투: 7,
  금성: 20,
  태양: 6,
  달: 10,
  화성: 7,
  라후: 18,
  목성: 16,
  토성: 19,
  수성: 17,
};

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

function pad2(n: number): string {
  return String(n).padStart(2, "0");
}

function normalizeDegrees(deg: number): number {
  return ((deg % 360) + 360) % 360;
}

function signOf(longitude: number): { sign: ZodiacSign; degree: number; index: number } {
  const lon = normalizeDegrees(longitude);
  const index = Math.floor(lon / 30);
  return { sign: SIGNS[index], degree: lon - index * 30, index };
}

function formatDegree(degree: number): string {
  return `${Math.floor(degree)}도`;
}

function solarBirthDate(birthInfo: BirthInfo): { year: number; month: number; day: number; hour: number; minute: number } {
  let year = birthInfo.year;
  let month = birthInfo.month;
  let day = birthInfo.day;
  const hour = birthInfo.hour ?? 12;
  const minute = birthInfo.minute ?? 0;

  if (birthInfo.calendarType === "lunar") {
    const lunarMonth = birthInfo.isLeapMonth ? -Math.abs(month) : month;
    const solar = Lunar.fromYmdHms(year, lunarMonth, day, hour, minute, 0).getSolar();
    year = solar.getYear();
    month = solar.getMonth();
    day = solar.getDay();
  }

  return { year, month, day, hour, minute };
}

function utcDateOf(birthInfo: BirthInfo): Date {
  const b = solarBirthDate(birthInfo);
  const dateStr = `${b.year}-${pad2(b.month)}-${pad2(b.day)}`;
  const utcOffset = DST_PERIODS.some(([start, end]) => dateStr >= start && dateStr <= end) ? 10 : 9;
  return new Date(Date.UTC(b.year, b.month - 1, b.day, b.hour - utcOffset, b.minute, 0));
}

function placeOf(birthInfo: BirthInfo) {
  const place = birthInfo.birthPlace && birthInfo.birthPlace !== "none" ? BIRTH_PLACES[birthInfo.birthPlace] : BIRTH_PLACES.seoul;
  return {
    ...place,
    defaulted: !birthInfo.birthPlace || birthInfo.birthPlace === "none",
  };
}

function sunLongitude(date: Date): number {
  return SunPosition(date).elon;
}

function bodyLongitude(body: Body, date: Date): number {
  return body === Body.Sun ? sunLongitude(date) : EclipticLongitude(body, date);
}

function placement(body: string, longitude: number, house?: number): AstrologyPlacement {
  const s = signOf(longitude);
  return {
    body,
    sign: s.sign,
    degree: Number(s.degree.toFixed(2)),
    absoluteLongitude: Number(normalizeDegrees(longitude).toFixed(2)),
    house,
    keyword: MODERN_KEYWORD[body] ?? `${body}의 작용`,
  };
}

function ayanamsaLahiriApprox(date: Date): number {
  const year = date.getUTCFullYear() + (date.getUTCMonth() + 0.5) / 12;
  return 23.85675 + (year - 2000) * 0.013968;
}

function sidereal(longitude: number, date: Date): number {
  return normalizeDegrees(longitude - ayanamsaLahiriApprox(date));
}

function ascendantLongitude(date: Date, latitude: number, longitude: number): number {
  const lst = normalizeDegrees(SiderealTime(date) * 15 + longitude);
  const theta = (lst * Math.PI) / 180;
  const phi = (latitude * Math.PI) / 180;
  const eps = (23.439291 * Math.PI) / 180;
  const asc = Math.atan2(-Math.cos(theta), Math.sin(theta) * Math.cos(eps) + Math.tan(phi) * Math.sin(eps));
  return normalizeDegrees((asc * 180) / Math.PI);
}

function wholeSignHouse(longitude: number, ascLongitude?: number): number | undefined {
  if (ascLongitude === undefined) return undefined;
  const signIndex = signOf(longitude).index;
  const ascIndex = signOf(ascLongitude).index;
  return ((signIndex - ascIndex + 12) % 12) + 1;
}

function dignity(body: string, sign: ZodiacSign): ClassicalPlacement["dignity"] {
  const domicile: Record<string, ZodiacSign[]> = {
    태양: ["사자자리"],
    달: ["게자리"],
    수성: ["쌍둥이자리", "처녀자리"],
    금성: ["황소자리", "천칭자리"],
    화성: ["양자리", "전갈자리"],
    목성: ["사수자리", "물고기자리"],
    토성: ["염소자리", "물병자리"],
  };
  const exaltation: Record<string, ZodiacSign> = {
    태양: "양자리",
    달: "황소자리",
    수성: "처녀자리",
    금성: "물고기자리",
    화성: "염소자리",
    목성: "게자리",
    토성: "천칭자리",
  };
  const detriment: Record<string, ZodiacSign[]> = {
    태양: ["물병자리"],
    달: ["염소자리"],
    수성: ["사수자리", "물고기자리"],
    금성: ["전갈자리", "양자리"],
    화성: ["천칭자리", "황소자리"],
    목성: ["쌍둥이자리", "처녀자리"],
    토성: ["게자리", "사자자리"],
  };
  const fall: Record<string, ZodiacSign> = {
    태양: "천칭자리",
    달: "전갈자리",
    수성: "물고기자리",
    금성: "처녀자리",
    화성: "게자리",
    목성: "염소자리",
    토성: "양자리",
  };

  if (domicile[body]?.includes(sign)) return "도미사일";
  if (exaltation[body] === sign) return "엑잘테이션";
  if (detriment[body]?.includes(sign)) return "디트리먼트";
  if (fall[body] === sign) return "폴";
  return "페레그린";
}

function vedicPlacement(body: string, tropicalLongitude: number, date: Date, house?: number): VedicPlacement {
  const lon = sidereal(tropicalLongitude, date);
  const s = signOf(lon);
  const nakIndex = Math.floor(lon / (360 / 27));
  const nakDegree = lon - nakIndex * (360 / 27);
  return {
    body,
    sign: s.sign,
    degree: Number(s.degree.toFixed(2)),
    absoluteLongitude: Number(lon.toFixed(2)),
    nakshatra: NAKSHATRAS[nakIndex],
    pada: Math.floor(nakDegree / (360 / 108)) + 1,
    keyword: house ? `시데리얼 ${house}하우스 흐름` : "시데리얼 달의 마음결",
  };
}

function julianDay(date: Date): number {
  return date.getTime() / 86400000 + 2440587.5;
}

function meanRahuLongitude(date: Date): number {
  const t = (julianDay(date) - 2451545.0) / 36525;
  return normalizeDegrees(125.04452 - 1934.136261 * t + 0.0020708 * t * t + (t * t * t) / 450000);
}

function addYears(date: Date, years: number): Date {
  return new Date(date.getTime() + years * 365.2425 * 86400000);
}

function dashaInfo(date: Date, siderealMoonLongitude: number): VedicDashaInfo {
  const nakSize = 360 / 27;
  const nakIndex = Math.floor(siderealMoonLongitude / nakSize);
  const lord = VIMSHOTTARI_SEQUENCE[nakIndex % VIMSHOTTARI_SEQUENCE.length];
  const lordYears = DASHA_YEARS[lord];
  const elapsedInNak = siderealMoonLongitude - nakIndex * nakSize;
  const remainingRatio = 1 - elapsedInNak / nakSize;
  const balanceAtBirthYears = lordYears * remainingRatio;

  let currentLord = lord;
  let start = date;
  let end = addYears(date, balanceAtBirthYears);
  const now = new Date();
  let idx = VIMSHOTTARI_SEQUENCE.indexOf(lord);
  while (end < now) {
    start = end;
    idx = (idx + 1) % VIMSHOTTARI_SEQUENCE.length;
    currentLord = VIMSHOTTARI_SEQUENCE[idx];
    end = addYears(start, DASHA_YEARS[currentLord]);
  }

  return {
    system: "Vimshottari",
    currentMahaDasha: currentLord,
    currentMahaDashaStart: start.toISOString().slice(0, 10),
    currentMahaDashaEnd: end.toISOString().slice(0, 10),
    birthNakshatraLord: lord,
    balanceAtBirthYears: Number(balanceAtBirthYears.toFixed(2)),
    note: "달의 시데리얼 나크샤트라 기준 Vimshottari 마하다샤 근사 계산입니다.",
  };
}

function signLine(p: AstrologyPlacement | VedicPlacement): string {
  return `${p.body} ${p.sign} ${formatDegree(p.degree)}`;
}

export function computeAstrologyProfile(birthInfo: BirthInfo): AstrologyProfile {
  const date = utcDateOf(birthInfo);
  const place = placeOf(birthInfo);
  const timeKnown = birthInfo.hour !== null;
  const ascLon = timeKnown ? ascendantLongitude(date, place.latitude, place.longitude) : undefined;

  const sunLon = bodyLongitude(Body.Sun, date);
  const moonLon = bodyLongitude(Body.Moon, date);
  const venusLon = bodyLongitude(Body.Venus, date);
  const marsLon = bodyLongitude(Body.Mars, date);

  const sun = placement("태양", sunLon, wholeSignHouse(sunLon, ascLon));
  const moon = placement("달", moonLon, wholeSignHouse(moonLon, ascLon));
  const ascendant = ascLon !== undefined ? placement("상승궁", ascLon, 1) : undefined;
  const venus = placement("금성", venusLon, wholeSignHouse(venusLon, ascLon));
  const mars = placement("화성", marsLon, wholeSignHouse(marsLon, ascLon));

  // 세대 행성(천왕·해왕·명왕): 별자리는 또래 세대가 공유하지만, 하우스·각도는 개인 차트에서 의미가 크다.
  const outer: AstrologyPlacement[] = [Body.Uranus, Body.Neptune, Body.Pluto].map((body) => {
    const lon = bodyLongitude(body, date);
    return placement(BODY_LABEL[body], lon, wholeSignHouse(lon, ascLon));
  });

  const classicalBodies = [Body.Sun, Body.Moon, Body.Mercury, Body.Venus, Body.Mars, Body.Jupiter, Body.Saturn];
  const classicalPlacements: ClassicalPlacement[] = classicalBodies.map((body) => {
    const label = BODY_LABEL[body];
    const base = placement(label, bodyLongitude(body, date), wholeSignHouse(bodyLongitude(body, date), ascLon));
    return {
      ...base,
      dignity: dignity(label, base.sign),
      ruler: SIGN_RULER[base.sign],
    };
  });

  const sunHouse = sun.house;
  const sect = sunHouse === undefined ? "unknown" : sunHouse >= 7 && sunHouse <= 12 ? "day" : "night";
  const vedicSun = vedicPlacement("태양", sunLon, date, wholeSignHouse(sidereal(sunLon, date), ascLon ? sidereal(ascLon, date) : undefined));
  const vedicMoon = vedicPlacement("달", moonLon, date, wholeSignHouse(sidereal(moonLon, date), ascLon ? sidereal(ascLon, date) : undefined));
  const lagna = ascLon !== undefined ? vedicPlacement("라그나", ascLon, date, 1) : undefined;
  const rahuLon = meanRahuLongitude(date);
  const ketuLon = normalizeDegrees(rahuLon + 180);
  const rahu = vedicPlacement("라후", rahuLon, date, wholeSignHouse(sidereal(rahuLon, date), ascLon ? sidereal(ascLon, date) : undefined));
  const ketu = vedicPlacement("케투", ketuLon, date, wholeSignHouse(sidereal(ketuLon, date), ascLon ? sidereal(ascLon, date) : undefined));
  const dasha = dashaInfo(date, vedicMoon.absoluteLongitude);

  const locationLabel = `${place.label}${place.defaulted ? " 기준(출생지 미선택)" : ""}`;
  const accuracyNote = timeKnown
    ? "출생시간과 지역 대표 좌표를 기준으로 상승궁·하우스를 계산했습니다. 분 단위가 다르면 상승궁 경계 근처에서는 달라질 수 있습니다."
    : "출생시간이 없어 태양·달·행성 별자리 중심으로 계산했고, 상승궁·하우스·라그나는 제외했습니다.";

  return {
    calculatedAt: date.toISOString(),
    locationLabel,
    timeKnown,
    accuracyNote,
    modern: {
      sun,
      moon,
      ascendant,
      venus,
      mars,
      outer,
      summary: [
        `${signLine(sun)}: 삶의 방향`,
        `${signLine(moon)}: 감정 습관`,
        ascendant ? `${signLine(ascendant)}: 첫인상과 방어 방식` : "상승궁: 출생시간 필요",
        `${signLine(venus)}: 사랑받고 싶은 방식`,
        `${signLine(mars)}: 욕망과 추진력`,
        `세대 행성 ${outer.map((p) => `${p.body} ${p.sign}${p.house ? ` ${p.house}하우스` : ""}`).join(", ")}: 시대 배경과 무의식의 큰 테마 (하우스로 개인화)`,
      ],
    },
    classical: {
      sect,
      ascendant,
      placements: classicalPlacements,
      summary: [
        `차트 구분: ${sect === "day" ? "데이 차트" : sect === "night" ? "나이트 차트" : "출생시간 미상"}`,
        `차트 룰러 후보: ${ascendant ? SIGN_RULER[ascendant.sign] : "상승궁 계산 필요"}`,
        `강한 품위: ${
          classicalPlacements
            .filter((p) => p.dignity === "도미사일" || p.dignity === "엑잘테이션")
            .map((p) => `${p.body} ${p.dignity}`)
            .join(", ") || "뚜렷한 도미사일/엑잘테이션 적음"
        }`,
      ],
    },
    vedic: {
      ayanamsa: `Lahiri 근사 ${ayanamsaLahiriApprox(date).toFixed(2)}도`,
      lagna,
      moon: vedicMoon,
      sun: vedicSun,
      rahu,
      ketu,
      dasha,
      summary: [
        lagna ? `라그나 ${lagna.sign}: 삶을 시작하는 방식` : "라그나: 출생시간 필요",
        `달 ${vedicMoon.sign} / ${vedicMoon.nakshatra} ${vedicMoon.pada}파다: 마음의 기본 리듬`,
        `태양 ${vedicSun.sign}: 사회적 방향성`,
        `라후 ${rahu.sign} / 케투 ${ketu.sign}: 집착과 내려놓음의 축`,
        `현재 ${dasha.currentMahaDasha} 마하다샤: ${dasha.currentMahaDashaStart}~${dasha.currentMahaDashaEnd}`,
      ],
    },
    notes: [
      `현대: ${signLine(sun)}, ${signLine(moon)}, ${signLine(venus)}, ${signLine(mars)}`,
      `고전: ${sect === "day" ? "낮 차트" : sect === "night" ? "밤 차트" : "시간 미상"}, ${classicalPlacements
        .slice(0, 4)
        .map((p) => `${p.body} ${p.sign} ${p.dignity}`)
        .join(", ")}`,
      `베딕: ${vedicMoon.nakshatra} ${vedicMoon.pada}파다, ${lagna ? `라그나 ${lagna.sign}` : "라그나 미계산"}, 라후 ${rahu.sign}, 케투 ${ketu.sign}, ${dasha.currentMahaDasha} 마하다샤`,
      accuracyNote,
    ],
  };
}

// ── 어스펙트(각도 패턴) 계산 — 봇 비서용 추가 (sokmaeum 원본엔 없던 계산) ──────────
// 표준 5대 각도(합/육십분/사각/삼분/충)를 orb 범위 안에서 탐지한다.

const ASPECT_ANGLES: Array<{ name: AstrologyAspect["aspect"]; angle: number; orb: number }> = [
  { name: "합", angle: 0, orb: 8 },
  { name: "육십분", angle: 60, orb: 4 },
  { name: "사각", angle: 90, orb: 6 },
  { name: "삼분", angle: 120, orb: 6 },
  { name: "충", angle: 180, orb: 8 },
];

function angularDiff(a: number, b: number): number {
  const diff = Math.abs(normalizeDegrees(a) - normalizeDegrees(b));
  return diff > 180 ? 360 - diff : diff;
}

/** 개인 천체(태양/달/수성/금성/화성) + 사회 천체(목성/토성) + 세대 천체(천왕/해왕/명왕) 사이 주요 각도를 계산한다. */
export function computeMajorAspects(profile: AstrologyProfile): AstrologyAspect[] {
  const bodies: AstrologyPlacement[] = [
    profile.modern.sun,
    profile.modern.moon,
    profile.modern.venus,
    profile.modern.mars,
    ...profile.classical.placements.filter((p) => p.body === "수성" || p.body === "목성" || p.body === "토성"),
    ...profile.modern.outer,
  ];

  const aspects: AstrologyAspect[] = [];
  for (let i = 0; i < bodies.length; i++) {
    for (let j = i + 1; j < bodies.length; j++) {
      const diff = angularDiff(bodies[i].absoluteLongitude, bodies[j].absoluteLongitude);
      for (const candidate of ASPECT_ANGLES) {
        const orb = Math.abs(diff - candidate.angle);
        if (orb <= candidate.orb) {
          aspects.push({
            bodyA: bodies[i].body,
            bodyB: bodies[j].body,
            aspect: candidate.name,
            angle: Number(diff.toFixed(2)),
            orb: Number(orb.toFixed(2)),
          });
          break;
        }
      }
    }
  }
  return aspects;
}

// ── 오늘 트랜짓 테마 — 봇 비서용 추가 ──────────
// 오늘 태양/달의 트로피컬 경도를 원국 상승궁 기준 whole-sign 하우스에 대입해
// "오늘 어느 삶의 영역이 활성화되는지"만 짧게 계산한다(트랜짓 전체 계산은 아님).
const HOUSE_THEME: Record<number, string> = {
  1: "나 자신과 시작하는 힘",
  2: "돈과 자원",
  3: "소통과 일상",
  4: "집과 마음의 기반",
  5: "표현과 즐거움",
  6: "일상 루틴과 컨디션",
  7: "관계와 협업",
  8: "깊은 정서와 정리",
  9: "배움과 시야 확장",
  10: "커리어와 사회적 방향",
  11: "동료·커뮤니티",
  12: "휴식과 내면 정리",
};

export function computeCurrentTransitTheme(profile: AstrologyProfile, now: Date = new Date()): AstrologyTransitTheme {
  const ascLon = profile.classical.ascendant?.absoluteLongitude;
  const sunHouse = wholeSignHouse(bodyLongitude(Body.Sun, now), ascLon);
  const moonHouse = wholeSignHouse(bodyLongitude(Body.Moon, now), ascLon);

  const parts: string[] = [];
  if (sunHouse) parts.push(`오늘 태양은 당신의 ${sunHouse}하우스(${HOUSE_THEME[sunHouse]})를 지나는 중`);
  if (moonHouse) parts.push(`달은 ${moonHouse}하우스(${HOUSE_THEME[moonHouse]}) 쪽 감정을 건드리는 중`);
  const theme = parts.length > 0 ? parts.join(", ") + "이에요." : "출생시간이 없어 오늘 트랜짓 하우스는 계산하지 못했어요(별자리 흐름만 참고).";

  return {
    date: now.toISOString().slice(0, 10),
    sunTransitHouse: sunHouse,
    moonTransitHouse: moonHouse,
    theme,
  };
}
