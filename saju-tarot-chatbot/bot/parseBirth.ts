import type { BirthInfo, Gender } from "../src/types/index.js";

// 지역 표기 → BIRTH_PLACES 키 매핑 (진태양시 보정용)
const PLACE_ALIASES: Array<[RegExp, string]> = [
  [/서울|경기|인천/, "seoul"],
  [/강원/, "gangwon"],
  [/대전|세종|충청|충북|충남|청주|천안/, "daejeon"],
  [/전북|전주/, "jeonbuk"],
  [/광주|전남|목포|여수/, "gwangju"],
  [/대구|경북|포항|구미/, "daegu"],
  [/부산|울산|경남|창원|김해/, "busan"],
  [/제주/, "jeju"],
];

export interface ParseResult {
  ok: boolean;
  birthInfo?: BirthInfo;
  error?: string;
}

/**
 * 자유 입력에서 생년월일시·성별·달력·출생지를 추출한다.
 * 예: "1993-03-15 14:30 여 서울", "음력 1990.5.2 07시20분 남 부산", "1988년 7월 15일 시간모름 남자"
 */
export function parseBirthInput(raw: string): ParseResult {
  const text = raw.trim();

  // 달력
  const isLunar = /음력|음\s/.test(text);
  const isLeapMonth = /윤달|윤월/.test(text);

  // 날짜: 1993-03-15 / 1993.3.15 / 1993년 3월 15일
  const dateMatch = text.match(/(19\d{2}|20\d{2})\s*[.\-/년]\s*(\d{1,2})\s*[.\-/월]\s*(\d{1,2})\s*일?/);
  if (!dateMatch) {
    return { ok: false, error: "생년월일을 찾지 못했어요. 예: 1993-03-15 또는 1993년 3월 15일" };
  }
  const year = Number(dateMatch[1]);
  const month = Number(dateMatch[2]);
  const day = Number(dateMatch[3]);
  if (month < 1 || month > 12 || day < 1 || day > 31) {
    return { ok: false, error: `날짜가 이상해요: ${year}년 ${month}월 ${day}일` };
  }

  // 시간: 14:30 / 14시 30분 / 14시 / "시간모름"
  let hour: number | null = null;
  let minute = 0;
  const unknownTime = /시간\s*모름|모름|미상/.test(text);
  if (!unknownTime) {
    const rest = text.slice(dateMatch.index! + dateMatch[0].length);
    const timeMatch = rest.match(/(\d{1,2})\s*[:시]\s*(\d{1,2})?\s*분?/);
    if (timeMatch) {
      hour = Number(timeMatch[1]);
      minute = timeMatch[2] !== undefined ? Number(timeMatch[2]) : 0;
      if (hour > 23 || minute > 59) {
        return { ok: false, error: `출생 시각이 이상해요: ${hour}시 ${minute}분 (0~23시로 입력해 주세요)` };
      }
    }
  }
  if (hour === null && !unknownTime) {
    return {
      ok: false,
      error: "출생 시각을 찾지 못했어요. 예: 14:30 또는 14시 30분. 모르면 '시간모름'이라고 적어주세요.",
    };
  }

  // 성별
  let gender: Gender | null = null;
  if (/남/.test(text)) gender = "male";
  if (/여/.test(text)) gender = "female";
  if (!gender) {
    return { ok: false, error: "성별을 찾지 못했어요. '남' 또는 '여'를 함께 적어주세요." };
  }

  // 출생지 (선택)
  let birthPlace = "none";
  for (const [re, key] of PLACE_ALIASES) {
    if (re.test(text)) {
      birthPlace = key;
      break;
    }
  }

  const birthInfo: BirthInfo = {
    calendarType: isLunar ? "lunar" : "solar",
    year,
    month,
    day,
    hour,
    minute,
    isLeapMonth: isLunar ? isLeapMonth : undefined,
    birthPlace,
    gender,
  };
  return { ok: true, birthInfo };
}

export function describeBirthInfo(b: BirthInfo): string {
  const cal = b.calendarType === "lunar" ? `음력${b.isLeapMonth ? "(윤달)" : ""}` : "양력";
  const time = b.hour === null ? "시간 모름" : `${String(b.hour).padStart(2, "0")}:${String(b.minute ?? 0).padStart(2, "0")}`;
  const gender = b.gender === "male" ? "남" : "여";
  const place = b.birthPlace && b.birthPlace !== "none" ? ` · 출생지 보정: ${b.birthPlace}` : "";
  return `${cal} ${b.year}년 ${b.month}월 ${b.day}일 ${time} · ${gender}${place}`;
}
