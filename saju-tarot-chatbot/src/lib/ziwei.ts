import { astro } from "iztro";
import type { BirthInfo, Gender } from "../types/index.js";

/**
 * 자미두수(紫微斗數) 계산 래퍼 (Phase 0).
 *
 * 원칙(CLAUDE.md 계승):
 *   - 계산은 검증된 엔진(iztro), 해석만 LLM. 배치·별·사화는 iztro가 결정론으로 계산하고,
 *     이 파일은 그 출력을 앱에서 쓰기 좋은 안정된 형태로 정규화만 한다(값 지어내기 금지).
 *   - 자미두수는 사주와 함께 쓰는 '교차검증'용 명식(natal) 계열이다. 여기서는 원식 차트만 낸다.
 *     분야별 판정(deriveZiweiDomainVerdicts)과 교차검증은 다음 단계에서 이 차트를 소비한다.
 *   - 출생 시간을 모르면 명궁 자체가 잡히지 않아 차트가 무의미하므로 null을 반환한다.
 *
 * iztro 요약:
 *   astro.bySolar(YYYY-MM-DD, 시진인덱스(0~12), '男'|'女', fixLeap, 'ko-KR')
 *   astro.byLunar(YYYY-MM-DD, 시진인덱스, 성별, 윤달여부, fixLeap, 'ko-KR')
 *   시진 인덱스: 0=자시(0시), 4=진시(8시), 12=야자시(23시) = Math.floor((시+1)/2)
 */

export interface ZiweiStar {
  name: string;
  /** 사화: 록/권/과/기 (없으면 undefined) */
  mutagen?: string;
  /** 묘왕리함 밝기 -3(함)~+3(묘). 별의 힘 세기. */
  brightness: number;
}

export interface ZiweiPalace {
  /** 궁 이름 (명궁·형제·부처·자녀·재백·질액·천이·노복·관록·전택·복덕·부모) */
  name: string;
  branch: string;
  stem: string;
  majorStars: ZiweiStar[];
  minorStars: string[];
  /** 삼방사정 방조: 대궁 + 삼합 2궁의 주성 (이 궁을 볼 때 함께 참작) */
  sanfangStars: ZiweiStar[];
  /** 신궁 여부 */
  isBody: boolean;
  /** 명궁 여부 */
  isSoul: boolean;
}

export interface ZiweiChart {
  /** 명궁 지지 */
  soulBranch: string;
  /** 신궁 지지 */
  bodyBranch: string;
  /** 오행국 (예: "수이국", "목삼국") */
  fiveElementsClass: string;
  palaces: ZiweiPalace[];
  timeKnown: boolean;
  gender: Gender;
  source: "iztro";
}

function pad(n: number): string {
  return String(n).padStart(2, "0");
}

/** 0~23시 → iztro 시진 인덱스(0~12). 23시는 야자시(12). */
function timeIndexFromHour(hour: number): number {
  return Math.floor((hour + 1) / 2);
}

/** iztro 밝기 문자열("[+3]"·"[-1]" 등) → 숫자. 값 없으면 0(평). */
function parseBrightness(b: string | undefined): number {
  const m = /(-?\d+)/.exec(b ?? "");
  return m ? Number(m[1]) : 0;
}

type IztroStar = { name: string; mutagen?: string; brightness?: string };
function toStar(s: IztroStar): ZiweiStar {
  return { name: s.name, mutagen: s.mutagen || undefined, brightness: parseBrightness(s.brightness) };
}

/**
 * BirthInfo로 자미두수 원식 차트를 계산한다.
 * 출생 시간을 모르면(hour === null) 명궁을 잡을 수 없어 null을 반환한다.
 */
function buildAstrolabe(birth: BirthInfo) {
  const dateStr = `${birth.year}-${pad(birth.month)}-${pad(birth.day)}`;
  const timeIndex = timeIndexFromHour(birth.hour ?? 0);
  const genderCh = birth.gender === "male" ? "男" : "女";
  return birth.calendarType === "lunar"
    ? astro.byLunar(dateStr, timeIndex, genderCh, Boolean(birth.isLeapMonth), true, "ko-KR")
    : astro.bySolar(dateStr, timeIndex, genderCh, true, "ko-KR");
}

export function computeZiweiChart(birth: BirthInfo): ZiweiChart | null {
  if (birth.hour === null || birth.hour === undefined) return null;

  try {
    const chart = buildAstrolabe(birth);

    const palaces: ZiweiPalace[] = chart.palaces.map((p) => {
      // 삼방사정: 이 궁 + 대궁(opposite) + 삼합 2궁(wealth·career)의 주성을 방조로 모은다.
      let sanfangStars: ZiweiStar[] = [];
      try {
        const s = chart.surroundedPalaces(p.name);
        sanfangStars = [...s.opposite.majorStars, ...s.wealth.majorStars, ...s.career.majorStars].map(toStar);
      } catch {
        sanfangStars = [];
      }
      return {
        name: p.name,
        branch: p.earthlyBranch,
        stem: p.heavenlyStem,
        majorStars: p.majorStars.map(toStar),
        minorStars: p.minorStars.map((s) => s.name),
        sanfangStars,
        isBody: p.isBodyPalace,
        isSoul: p.name === "명궁",
      };
    });

    return {
      soulBranch: chart.earthlyBranchOfSoulPalace,
      bodyBranch: chart.earthlyBranchOfBodyPalace,
      fiveElementsClass: chart.fiveElementsClass,
      palaces,
      timeKnown: true,
      gender: birth.gender,
      source: "iztro",
    };
  } catch {
    return null;
  }
}

// ── 자미두수 운한(대한·유년) — 엔진 업그레이드 Z-1 (docs/engine-upgrade-2026-07.md) ──────────
// 계산은 전부 iztro의 horoscope()에 위임하고, 여기서는 앱에서 쓰기 좋은 형태로 정규화만 한다.
// iztro horoscope() 실측(2026-07-10, iztro 2.5.8):
//   h.decadal / h.yearly = { index(대한·유년 명궁이 앉는 본명 궁 배열 인덱스),
//                            heavenlyStem, earthlyBranch, mutagen: [록,권,과,기 순서의 별 이름 4개], ... }
//   chart.palaces[index].decadal.range = 그 궁 대한의 [시작나이, 끝나이]

/** 운한 사화 하나: 어떤 별에 록/권/과/기가 붙고, 그 별이 본명 어느 궁에 있는지 */
export interface ZiweiLuckMutagen {
  star: string;
  type: "록" | "권" | "과" | "기";
  /** 그 별이 앉아 있는 본명 궁 이름 (원국에서 못 찾으면 null — 값 지어내기 금지) */
  natalPalace: string | null;
}

/** 대한 또는 유년 한 스코프 */
export interface ZiweiLuckScope {
  /** 운한 간지 */
  stem: string;
  branch: string;
  /** 운한 명궁이 앉는 본명 궁 (이 10년/올해를 그 궁의 주제로 읽는다) */
  palaceOfSoul: { name: string; branch: string } | null;
  /** 대한만: 나이 구간 [시작, 끝] (iztro range 그대로) */
  ageRange?: [number, number];
  /** 운한 사화 (록·권·과·기 순) */
  mutagens: ZiweiLuckMutagen[];
}

export interface ZiweiLuck {
  decade: ZiweiLuckScope | null;
  year: ZiweiLuckScope | null;
  /** 기준 시점 (ISO 날짜) */
  at: string;
  source: "iztro";
}

const MUTAGEN_TYPES = ["록", "권", "과", "기"] as const;

/**
 * BirthInfo + 기준 시점으로 자미두수 대한·유년을 계산한다.
 * 출생 시간을 모르면 명궁을 잡을 수 없어 null (원식 차트와 동일한 규칙).
 */
export function computeZiweiHoroscope(birth: BirthInfo, at: Date = new Date()): ZiweiLuck | null {
  if (birth.hour === null || birth.hour === undefined) return null;

  try {
    const chart = buildAstrolabe(birth);
    const horoscope = chart.horoscope(at);

    const findNatalPalace = (starName: string): string | null => {
      for (const palace of chart.palaces) {
        if (palace.majorStars.some((s) => s.name === starName)) return palace.name;
        if (palace.minorStars.some((s) => s.name === starName)) return palace.name;
      }
      return null;
    };

    const toScope = (item: { index: number; heavenlyStem: string; earthlyBranch: string; mutagen: string[] }, withAge: boolean): ZiweiLuckScope | null => {
      if (!item) return null;
      const natal = chart.palaces[item.index];
      return {
        stem: item.heavenlyStem,
        branch: item.earthlyBranch,
        palaceOfSoul: natal ? { name: natal.name, branch: natal.earthlyBranch } : null,
        ageRange: withAge && natal ? natal.decadal.range : undefined,
        mutagens: (item.mutagen ?? []).slice(0, 4).map((star, i) => ({
          star,
          type: MUTAGEN_TYPES[i],
          natalPalace: findNatalPalace(star),
        })),
      };
    };

    return {
      decade: toScope(horoscope.decadal, true),
      year: toScope(horoscope.yearly, false),
      at: at.toISOString().slice(0, 10),
      source: "iztro",
    };
  } catch {
    return null;
  }
}
