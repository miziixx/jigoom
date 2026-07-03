import type { BirthInfo, MysticReadingResult, ReadingInterest } from "../../types";
import { kstDateOf } from "../../lib/fortune";
import { buildMysticEvidence } from "./evidenceMapper";
import { buildFallbackReading } from "./buildFallbackReading";

/**
 * 속마음 리딩 클라이언트 API + 캐시.
 * 오늘의 운세와 동일한 전략: (명식 서명 + 관심사 + KST 연-월) 키로 캐싱한다.
 * 세운/월운은 월 단위로 바뀌므로 연-월이 키에 들어가 매월 자동 갱신된다.
 */
const CACHE_PREFIX = "sokmaeum:mystic:";

function birthSignature(b: BirthInfo): string {
  return [b.calendarType, b.year, b.month, b.day, b.hour ?? "x", b.minute ?? 0, b.birthPlace ?? "none", b.gender].join("-");
}

function cacheKey(b: BirthInfo, interest: ReadingInterest, ym: string): string {
  return `${CACHE_PREFIX}${birthSignature(b)}:${interest}:${ym}`;
}

function readCache(key: string): MysticReadingResult | null {
  try {
    const raw = localStorage.getItem(key);
    return raw ? (JSON.parse(raw) as MysticReadingResult) : null;
  } catch {
    return null;
  }
}

function writeCache(key: string, result: MysticReadingResult): void {
  try {
    localStorage.setItem(key, JSON.stringify(result));
  } catch {
    // 저장 실패는 무시
  }
}

export interface GetMysticOptions {
  /** 캐시 무시하고 새로 생성 */
  force?: boolean;
  now?: Date;
}

/**
 * 속마음 리딩을 반환한다.
 * 근거는 결정론적 엔진이 계산하고, /api/mystic에서 문장을 생성한다.
 * 네트워크/서버 실패 시 룰 기반 폴백으로 항상 결과를 만든다.
 */
export async function getMysticReading(
  birthInfo: BirthInfo,
  interest: ReadingInterest,
  opts: GetMysticOptions = {},
): Promise<MysticReadingResult> {
  const now = opts.now ?? new Date();
  const kst = kstDateOf(now);
  const ym = kst.iso.slice(0, 7); // YYYY-MM
  const key = cacheKey(birthInfo, interest, ym);

  if (!opts.force) {
    const cached = readCache(key);
    if (cached) return cached;
  }

  const evidence = buildMysticEvidence(birthInfo, interest, now);

  let result: MysticReadingResult;
  try {
    const res = await fetch("/api/mystic", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ evidence }),
    });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = (await res.json()) as { result: MysticReadingResult };
    result = data.result;
  } catch {
    result = buildFallbackReading(evidence);
  }

  writeCache(key, result);
  return result;
}
