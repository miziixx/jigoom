// 사주팔자(여덟 글자) → 실제 양력 생년월일 역추적.
// 날짜를 되짚으면 대운·사령까지 되살아나므로, 팔자만 붙여넣어도 완전한 원국을 계산할 수 있다.
import { computeSajuChart, inferSolarDatesFromPillars, toHangul } from "../src/lib/saju.js";
import type { BirthInfo } from "../src/types/index.js";
import type { StoredPillars } from "./parseFourPillars.js";

// 지지 → 대표 출생 시각(각 2시간 블록 중앙). 자시는 자정 경계를 피해 00:30(조자시, 당일)로 둔다.
const ZHI_HOUR: Record<string, { hour: number; minute: number }> = {
  자: { hour: 0, minute: 30 },
  축: { hour: 2, minute: 0 },
  인: { hour: 4, minute: 0 },
  묘: { hour: 6, minute: 0 },
  진: { hour: 8, minute: 0 },
  사: { hour: 10, minute: 0 },
  오: { hour: 12, minute: 0 },
  미: { hour: 14, minute: 0 },
  신: { hour: 16, minute: 0 },
  유: { hour: 18, minute: 0 },
  술: { hour: 20, minute: 0 },
  해: { hour: 22, minute: 0 },
};

const WEEKDAYS = ["일", "월", "화", "수", "목", "금", "토"];

export interface InferBirthResult {
  ok: boolean;
  /** 검증까지 통과한 실제 생년월일 (대운 포함 전체 원국 계산 가능) */
  birthInfo?: BirthInfo;
  weekday?: string;
  /** 적어준 시주가 계산과 안 맞아 시주를 빼고 등록했는지 */
  hourDropped?: boolean;
  /** 성별 미입력이라 남성 기준으로 가정했는지 (대운 방향에 영향) */
  genderAssumed?: boolean;
  /** 같은 팔자의 다른 60년 주기 연도들 (참고용) */
  otherYears?: number[];
}

/**
 * 팔자로 실제 생일을 되짚어 검증된 BirthInfo 를 만든다.
 * - 같은 간지는 60년 주기 → 오늘 이전 중 가장 최근(가장 어린)을 자동 선택.
 * - 되짚은 날짜가 입력 팔자를 그대로 재현하는지 computeSajuChart 로 검증.
 * - 실패하면 ok:false (호출부는 팔자 직접해석으로 폴백).
 */
export function inferBirthFromPillars(p: StoredPillars): InferBirthResult {
  const dates = inferSolarDatesFromPillars(p.year, p.month, p.day);
  if (dates.length === 0) return { ok: false };

  const today = new Date();
  const isPast = (d: { year: number; month: number; day: number }) =>
    new Date(d.year, d.month - 1, d.day) <= today;
  const past = dates.filter(isPast);
  const pool = past.length > 0 ? past : dates; // 전부 미래면(비정상) 그냥 후보 전체
  const chosen = pool[pool.length - 1]; // 오름차순 → 가장 최근
  const otherYears = dates.filter((d) => d !== chosen).map((d) => d.year);

  const genderAssumed = !p.gender;
  const gender = p.gender ?? "male";

  const hourZhi = p.hour ? p.hour[1] : null;
  const rep = hourZhi ? ZHI_HOUR[hourZhi] : null;

  let birthInfo: BirthInfo = {
    calendarType: "solar",
    year: chosen.year,
    month: chosen.month,
    day: chosen.day,
    hour: rep ? rep.hour : null,
    minute: rep ? rep.minute : 0,
    gender,
    birthPlace: "none",
  };

  // 검증: 되짚은 생일이 입력 팔자(연·월·일)를 그대로 재현하는가
  const chart = computeSajuChart(birthInfo);
  const ymdOk =
    chart.year.ganZhi === toHangul(p.year) &&
    chart.month.ganZhi === toHangul(p.month) &&
    chart.day.ganZhi === toHangul(p.day);
  if (!ymdOk) return { ok: false };

  // 시주 검증: 안 맞으면(대표 시각·서머타임 경계 등) 시주는 빼고 등록
  let hourDropped = false;
  if (p.hour && rep) {
    if (chart.hour?.ganZhi !== toHangul(p.hour)) {
      birthInfo = { ...birthInfo, hour: null, minute: 0 };
      hourDropped = true;
    }
  }

  const weekday = WEEKDAYS[new Date(chosen.year, chosen.month - 1, chosen.day).getDay()];
  return { ok: true, birthInfo, weekday, hourDropped, genderAssumed, otherYears };
}
