// 만세력에서 뽑은 사주팔자(여덟 글자)를 그대로 붙여넣는 입력을 읽는다.
// 생년월일시 파서(parseBirth.ts)와 별개로, 이미 계산된 원국 자체를 받는 경로다.
import { toHangul } from "../src/lib/saju.js";
import type { FourPillarsInput } from "../src/lib/saju.js";
import type { Gender } from "../src/types/index.js";

// 천간 10 · 지지 12 (한글). 한자는 toHangul 로 먼저 한글로 바꾼 뒤 매칭한다.
const GAN = "갑을병정무기경신임계";
const ZHI = "자축인묘진사오미신유술해";
// 간지 2글자(천간+지지) 토큰. "신"은 천간(辛)·지지(申) 양쪽이라 자리(앞=간, 뒤=지)로 구분된다.
const GZ = `[${GAN}][${ZHI}]`;
const GZ_RE = new RegExp(GZ, "g");

const PILLAR_LABEL_RE = /연주|년주|월주|일주|시주/;
const UNKNOWN_TIME_RE = /시간\s*(?:모름|몰라|모르|미상|없)/;

export interface StoredPillars {
  year: string;
  month: string;
  day: string;
  hour: string | null;
  /** 선택: 입력에 성별이 있으면 담아 해석 참고에 쓴다 (계산에는 불필요) */
  gender?: Gender;
}

export interface FourPillarsResult {
  ok: boolean;
  pillars?: StoredPillars;
  error?: string;
  /** 팔자 토큰·라벨을 걷어낸 나머지(질문일 수 있음). 등록 즉시 답할 때 쓴다. */
  remainder?: string;
}

/** 라벨/구분자를 공백으로 바꿔 간지 토큰만 남기기 쉽게 만든다. 간지 글자는 건드리지 않는다. */
function stripLabels(t: string): string {
  return t
    .replace(/연주|년주|월주|일주|시주|연간|월간|일간|시간|연지|월지|일지|시지|생년|생월|생일|생시/g, " ")
    .replace(/[년월일시주:：,.\/·|\-()[\]{}]/g, " ");
}

type PillarMap = Partial<Record<"year" | "month" | "day" | "hour", string>>;

/** 라벨이 있으면 라벨 기준으로 각 기둥 간지를 뽑는다(만세력 표기 순서가 시일월년이어도 안전). */
function extractLabeled(t: string): PillarMap | null {
  if (!PILLAR_LABEL_RE.test(t)) return null;
  const grab = (labelSrc: string): string | undefined => {
    const m = t.match(new RegExp(`(?:${labelSrc})\\s*[:：]?\\s*(${GZ})`));
    return m ? m[1] : undefined;
  };
  return {
    year: grab("연주|년주"),
    month: grab("월주"),
    day: grab("일주"),
    hour: grab("시주"),
  };
}

const UNIT_TO_KEY: Record<string, "year" | "month" | "day" | "hour"> = {
  년: "year",
  월: "month",
  일: "day",
  시: "hour",
};

/**
 * 각 간지에 단위(년/월/일/시)가 붙어 있으면 그 단위 기준으로 매핑한다.
 * 예: "경오년 무자월 임술일 갑진시" 뿐 아니라 "정묘시 임술일 무자월 경오년"(역순)도 정확히 읽는다.
 */
function extractBySuffix(t: string): PillarMap | null {
  const re = new RegExp(`(${GZ})\\s*(년|월|일|시)`, "g");
  const map: PillarMap = {};
  for (const m of t.matchAll(re)) {
    const key = UNIT_TO_KEY[m[2]];
    if (key && !map[key]) map[key] = m[1];
  }
  // 연·월·일 단위가 다 붙어 있을 때만 신뢰(부분적으로만 붙은 경우는 위치 기반이 더 안전)
  return map.year && map.month && map.day ? map : null;
}

function detectGender(t: string): Gender | undefined {
  if (/남자|남성|(?:^|\s)남(?=[\s.,)]|$)/.test(t)) return "male";
  if (/여자|여성|(?:^|\s)여(?=[\s.,)]|$)/.test(t)) return "female";
  return undefined;
}

/** 사주팔자 붙여넣기로 볼 만한 입력인지. 일상 문장의 우연한 간지 인접을 오탐하지 않게 보수적으로 본다. */
export function looksLikeFourPillars(raw: string): boolean {
  const t = toHangul(raw.trim());
  const tokens = stripLabels(t).match(GZ_RE) ?? [];
  // 붙여넣은 긴 문서/여러 줄 텍스트(예: 공부 계획표, "기억해줘"로 넘긴 메모)에 간지 글자가
  // 우연히 섞여 있는 경우를 팔자 입력으로 오인하지 않는다. 진짜 팔자 입력은 짧고, 간지가
  // 내용의 큰 비중을 차지한다 — 여러 줄이거나 아주 긴데 간지 비중이 낮으면 팔자가 아니다.
  const nonSpaceLen = t.replace(/\s+/g, "").length;
  const lineCount = t.split("\n").filter((l) => l.trim()).length;
  const ganzhiShare = nonSpaceLen > 0 ? (tokens.length * 2) / nonSpaceLen : 0;
  if ((lineCount >= 4 || nonSpaceLen > 150) && ganzhiShare < 0.3) return false;

  if (tokens.length >= 4) return true; // 팔자(4기둥)가 다 잡히면 확실
  if (tokens.length >= 3 && (PILLAR_LABEL_RE.test(t) || UNKNOWN_TIME_RE.test(t))) return true;
  if (extractBySuffix(t)) return true; // 연·월·일에 단위(년/월/일)가 붙어 명확 (예: "갑자년 정축월 병인일")
  return false;
}

/**
 * 팔자를 쓰려 했지만 원국을 세울 만큼(연·월·일주)은 안 되는 부분 입력인지.
 * 예: "갑자년 정축월"만 주면 일주(본인)가 없어 사주 해석도, 날짜 역추적도 못 한다.
 */
export function looksLikePartialPillars(raw: string): boolean {
  if (looksLikeFourPillars(raw)) return false;
  const t = toHangul(raw.trim());
  const suffixed = t.match(new RegExp(`(?:${GZ})\\s*(?:년|월|일|시)`, "g")) ?? [];
  return suffixed.length >= 2; // 간지+단위가 둘 이상이면 팔자를 쓰려던 것으로 본다
}

/** 사주팔자 여덟 글자(시주는 모르면 생략 가능)를 원국 입력으로 파싱한다. */
export function parseFourPillars(raw: string): FourPillarsResult {
  const t = toHangul(raw.trim());
  const gender = detectGender(t);
  const unknownTime = UNKNOWN_TIME_RE.test(t);

  let year: string | undefined;
  let month: string | undefined;
  let day: string | undefined;
  let hour: string | null = null;

  const mapped = extractLabeled(t) ?? extractBySuffix(t);
  if (mapped && mapped.year && mapped.month && mapped.day) {
    year = mapped.year;
    month = mapped.month;
    day = mapped.day;
    hour = mapped.hour ?? null;
  } else {
    const tokens = stripLabels(t).match(GZ_RE) ?? [];
    if (tokens.length < 3) {
      return {
        ok: false,
        error:
          "사주팔자를 못 읽었어요. 연·월·일(·시) 간지를 순서대로 적어주세요. 예: `경오 무자 임술 갑진` 또는 `연주 경오 월주 무자 일주 임술 시주 갑진`",
      };
    }
    [year, month, day] = tokens;
    hour = tokens[3] ?? null;
  }

  if (unknownTime) hour = null;

  if (!year || !month || !day) {
    return { ok: false, error: "연·월·일 간지를 모두 찾지 못했어요. 예: `경오 무자 임술 갑진`" };
  }

  // 뒤따르는 질문은 보통 팔자 뒤에 온다. 마지막 간지 토큰 이후만 잘라내면
  // 질문 본문("신약사주야?" 등)을 라벨 제거로 뭉개지 않고 온전히 남길 수 있다.
  const usedTokens = [year, month, day, hour].filter(Boolean) as string[];
  let lastEnd = 0;
  for (const tok of usedTokens) {
    const i = t.lastIndexOf(tok);
    if (i >= 0) lastEnd = Math.max(lastEnd, i + tok.length);
  }
  const remainder = t
    .slice(lastEnd)
    .replace(/^\s*(?:시|일|월|년|주)(?=\s)/, " ") // 마지막 기둥에 붙은 단위 글자(예: "갑진시")의 잔여 제거
    .replace(/남자|여자|남성|여성|음력|양력|윤달|윤월/g, " ")
    .replace(UNKNOWN_TIME_RE, " ")
    .replace(/[,.\/·|:：()[\]]/g, " ")
    .replace(/\s+/g, " ")
    .trim();

  const pillars: StoredPillars = { year, month, day, hour, gender };
  return { ok: true, pillars, remainder };
}

/** 저장된 팔자를 엔진 입력 형태로 변환 */
export function toFourPillarsInput(p: StoredPillars): FourPillarsInput {
  return { year: p.year, month: p.month, day: p.day, hour: p.hour };
}

/** 등록 확인용 한 줄 요약 */
export function describePillars(p: StoredPillars): string {
  const g = p.gender === "male" ? " · 남" : p.gender === "female" ? " · 여" : "";
  const hour = p.hour ?? "시주 모름";
  return `사주팔자 직접 입력 — 연주 ${p.year} · 월주 ${p.month} · 일주 ${p.day} · 시주 ${hour}${g}`;
}
