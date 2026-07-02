import { Lunar, Solar } from "lunar-javascript";
import type { BirthInfo, FiveElementBalance, SajuChart, SajuPillar } from "../types";

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

// lunar-javascript 의 십성 표기(중국어 간체)를 한국 명리 용어로 변환
const SHISHEN_TO_KOREAN: Record<string, string> = {
  比肩: "비견",
  劫财: "겁재",
  食神: "식신",
  伤官: "상관",
  偏财: "편재",
  正财: "정재",
  七杀: "편관(칠살)",
  正官: "정관",
  偏印: "편인",
  正印: "정인",
  日主: "일주(나 자신)",
};

function shishenToKorean(shishen: string): string {
  return SHISHEN_TO_KOREAN[shishen] ?? shishen;
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
  const { calendarType, year, month, day, hour } = birthInfo;
  const placeholderHour = hour ?? 12;

  const lunar =
    calendarType === "lunar"
      ? Lunar.fromYmdHms(year, month, day, placeholderHour, 0, 0)
      : Solar.fromYmdHms(year, month, day, placeholderHour, 0, 0).getLunar();

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

  const tenGods = [
    `연간: ${shishenToKorean(ec.getYearShiShenGan())}`,
    `월간: ${shishenToKorean(ec.getMonthShiShenGan())}`,
    `시간: ${hour === null ? "출생시간 모름" : shishenToKorean(ec.getTimeShiShenGan())}`,
  ];

  return {
    year: yearPillar,
    month: monthPillar,
    day: dayPillar,
    hour: timePillar,
    fiveElements,
    tenGods,
    dayMasterGan: dayPillar.gan,
  };
}
