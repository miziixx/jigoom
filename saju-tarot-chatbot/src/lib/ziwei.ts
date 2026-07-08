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
export function computeZiweiChart(birth: BirthInfo): ZiweiChart | null {
  if (birth.hour === null || birth.hour === undefined) return null;
  const dateStr = `${birth.year}-${pad(birth.month)}-${pad(birth.day)}`;
  const timeIndex = timeIndexFromHour(birth.hour);
  const genderCh = birth.gender === "male" ? "男" : "女";

  try {
    const chart =
      birth.calendarType === "lunar"
        ? astro.byLunar(dateStr, timeIndex, genderCh, Boolean(birth.isLeapMonth), true, "ko-KR")
        : astro.bySolar(dateStr, timeIndex, genderCh, true, "ko-KR");

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
