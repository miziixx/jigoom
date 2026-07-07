import type { BirthInfo, CompatibilityRelationType, Gender } from "../src/types/index.js";

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
  /** 생년월일시 토큰을 걷어낸 나머지 텍스트(질문일 수 있음). 등록 즉시 답할 때 쓴다. */
  remainder?: string;
}

/** 두 자리 연도('95년')를 4자리로 편다. 현재 연도 기준 미래는 1900년대로 본다. */
function normalizeYear(raw: string): number {
  const n = Number(raw);
  if (raw.length !== 2) return n;
  const pivot = new Date().getFullYear() % 100; // 올해의 두 자리 (예: 26)
  return n <= pivot ? 2000 + n : 1900 + n;
}

/** 성별 토큰(공백으로 떨어지든 붙어 있든)이 들어 있는지 */
function hasGenderToken(text: string): boolean {
  return /남자|여자|남성|여성/.test(text) || /(?:^|\s)[남여](?=[\s.,)]|$)/.test(text);
}

/** 생년월일시 등록/재등록 시도로 볼 만한 입력인지 (연도 + 성별 토큰이 함께 있는지) */
export function looksLikeBirthInput(text: string): boolean {
  const hasYear = /(?:19|20)\d{2}\s*[.\-/년]/.test(text) || /(?:^|\D)\d{2}\s*년/.test(text);
  return hasYear && hasGenderToken(text);
}

// 관계 키워드 → CompatibilityRelationType. 앞쪽(더 구체적)부터 검사한다.
const RELATION_KEYWORDS: Array<[RegExp, CompatibilityRelationType]> = [
  [/연인|애인|배우자|부부|남친|여친|남자친구|여자친구|남편|아내|썸/, "romantic"],
  [/부모|엄마|아빠|자식|자녀|아들|딸|모녀|부자|모자/, "parentChild"],
  [/형제|자매|남매|형|누나|언니|오빠|동생/, "siblings"],
  [/사장|상사|직원|부하|고용|팀장|대표/, "bossEmployee"],
  [/동료|동업|파트너|직장/, "coworker"],
  [/친구|지인/, "friend"],
  [/가족/, "family"],
];

/** 자유 입력에서 관계 유형을 뽑는다. 못 찾으면 null (기본값은 호출부가 결정). */
export function parseRelationType(text: string): CompatibilityRelationType | null {
  for (const [re, type] of RELATION_KEYWORDS) {
    if (re.test(text)) return type;
  }
  return null;
}

/**
 * 자유 입력에서 생년월일시·성별·달력·출생지를 추출한다.
 * 예: "1993-03-15 14:30 여 서울", "음력 1990.5.2 07시20분 남 부산", "1988년 7월 15일 시간모름 남자"
 */
export function parseBirthInput(raw: string): ParseResult {
  const text = raw.trim();
  // residual: 생년월일시 토큰을 하나씩 걷어낸 나머지. 남으면 질문으로 본다.
  let residual = text;
  const strike = (s?: string | null) => {
    if (s) residual = residual.replace(s, " ");
  };

  // 달력
  const isLunar = /음력|음\s/.test(text);
  const isLeapMonth = /윤달|윤월/.test(text);

  // 날짜: 1993-03-15 / 1993.3.15 / 1993년 3월 15일 / 95년 8월 23일(두 자리 연도)
  const dateMatch = text.match(/((?:19|20)\d{2}|\d{2})\s*[.\-/년]\s*(\d{1,2})\s*[.\-/월]\s*(\d{1,2})\s*일?/);
  if (!dateMatch) {
    return { ok: false, error: "생년월일을 찾지 못했어요. 예: 1993-03-15 또는 1993년 3월 15일" };
  }
  const year = normalizeYear(dateMatch[1]);
  const month = Number(dateMatch[2]);
  const day = Number(dateMatch[3]);
  if (month < 1 || month > 12 || day < 1 || day > 31) {
    return { ok: false, error: `날짜가 이상해요: ${year}년 ${month}월 ${day}일` };
  }
  strike(dateMatch[0]);

  // 시간: 14:30 / 14시 30분 / 14시 / "시간모름"/"시간 몰라"
  let hour: number | null = null;
  let minute = 0;
  const unknownTime = /시간\s*(?:모름|몰라|모르|미상|없)|(?:^|\s)(?:모름|미상)(?=\s|$|[.,])/.test(text);
  if (!unknownTime) {
    const rest = text.slice(dateMatch.index! + dateMatch[0].length);
    const timeMatch = rest.match(/(\d{1,2})\s*[:시]\s*(\d{1,2})?\s*분?/);
    if (timeMatch) {
      hour = Number(timeMatch[1]);
      minute = timeMatch[2] !== undefined ? Number(timeMatch[2]) : 0;
      if (hour > 23 || minute > 59) {
        return { ok: false, error: `출생 시각이 이상해요: ${hour}시 ${minute}분 (0~23시로 입력해 주세요)` };
      }
      strike(timeMatch[0]);
    }
  }
  if (hour === null && !unknownTime) {
    return {
      ok: false,
      error: "출생 시각을 찾지 못했어요. 예: 14:30 또는 14시 30분. 모르면 '시간모름'이라고 적어주세요.",
    };
  }

  // 성별 — "남자/여자/남성/여성"은 붙어 있어도 인정(예: "23일남자").
  // 한 글자 "남"/"여"는 지명 오탐(여수·남해 등)을 막으려 공백/경계로 감싸인 것만 인정한다.
  let gender: Gender | null = null;
  const longGender = text.match(/남자|여자|남성|여성/);
  if (longGender) {
    gender = longGender[0].startsWith("남") ? "male" : "female";
    strike(longGender[0]);
  } else {
    const shortGender = text.match(/(?:^|\s)([남여])(?=[\s.,)]|$)/);
    if (shortGender) {
      gender = shortGender[1] === "남" ? "male" : "female";
      strike(shortGender[1]);
    }
  }
  if (!gender) {
    return { ok: false, error: "성별을 찾지 못했어요. '남' 또는 '여'를 함께 적어주세요." };
  }

  // 출생지 (선택)
  let birthPlace = "none";
  for (const [re, key] of PLACE_ALIASES) {
    const m = text.match(re);
    if (m) {
      birthPlace = key;
      strike(m[0]);
      break;
    }
  }

  // 나머지에서 달력/시간모름/구분 문자를 마저 걷어내면 질문 텍스트만 남는다.
  const remainder = residual
    .replace(/음력|양력|윤달|윤월/g, " ")
    .replace(/시간\s*(?:모름|몰라|모르겠?|미상|없[음어])|모름|미상/g, " ")
    .replace(/[,./·~()]/g, " ")
    .replace(/\s+/g, " ")
    .trim();

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
  return { ok: true, birthInfo, remainder };
}

export function describeBirthInfo(b: BirthInfo): string {
  const cal = b.calendarType === "lunar" ? `음력${b.isLeapMonth ? "(윤달)" : ""}` : "양력";
  const time = b.hour === null ? "시간 모름" : `${String(b.hour).padStart(2, "0")}:${String(b.minute ?? 0).padStart(2, "0")}`;
  const gender = b.gender === "male" ? "남" : "여";
  const place = b.birthPlace && b.birthPlace !== "none" ? ` · 출생지 보정: ${b.birthPlace}` : "";
  return `${cal} ${b.year}년 ${b.month}월 ${b.day}일 ${time} · ${gender}${place}`;
}
