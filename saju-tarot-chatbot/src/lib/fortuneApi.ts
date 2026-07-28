import type { BirthInfo, FortuneResult } from "../types";
import { computeFortuneEvidence, kstDateOf } from "./fortune";
import { buildFallbackFortune } from "./fortuneFallback";

/**
 * 오늘의 운세 클라이언트 API + 캐시.
 *
 * 캐싱 전략 (서버 DB가 없는 이 앱에 맞춘 (userId, 날짜) 캐시의 구현):
 * - 키 = (명식 서명, KST 오늘 날짜). 같은 날 재방문 시 캐시 반환 → LLM 비용 절감.
 * - KST 자정을 넘기면 날짜가 바뀌어 키가 달라지므로 자동으로 새로 생성된다.
 * - 근거(evidence)는 결정론적이라 캐시된 값을 그대로 신뢰한다.
 */
const CACHE_PREFIX = "saju-tarot-chatbot:fortune:";

function birthSignature(b: BirthInfo): string {
  return [
    b.calendarType,
    b.year,
    b.month,
    b.day,
    b.hour ?? "x",
    b.minute ?? 0,
    b.birthPlace ?? "none",
    b.gender,
  ].join("-");
}

function cacheKey(b: BirthInfo, dateIso: string): string {
  return `${CACHE_PREFIX}${birthSignature(b)}:${dateIso}`;
}

function readCache(key: string): FortuneResult | null {
  try {
    const raw = localStorage.getItem(key);
    return raw ? (JSON.parse(raw) as FortuneResult) : null;
  } catch {
    return null;
  }
}

function writeCache(key: string, result: FortuneResult): void {
  try {
    localStorage.setItem(key, JSON.stringify(result));
  } catch {
    // 저장 실패는 무시 (다음 방문 때 다시 생성)
  }
}

/** 이 명식의 오늘 이외 오래된 캐시를 정리한다 (localStorage 누적 방지) */
function pruneOldCache(b: BirthInfo, keepDateIso: string): void {
  try {
    const prefix = `${CACHE_PREFIX}${birthSignature(b)}:`;
    const toRemove: string[] = [];
    for (let i = 0; i < localStorage.length; i++) {
      const k = localStorage.key(i);
      if (k && k.startsWith(prefix) && k !== `${prefix}${keepDateIso}`) toRemove.push(k);
    }
    toRemove.forEach((k) => localStorage.removeItem(k));
  } catch {
    // no-op
  }
}

export interface GetFortuneOptions {
  /** 캐시를 무시하고 새로 생성 (다시 생성 버튼) */
  force?: boolean;
  /** 테스트/미리보기용 기준 시각 주입 */
  now?: Date;
}

/**
 * 오늘(Asia/Seoul)의 운세를 반환한다.
 * 캐시가 있으면 그대로, 없으면 근거를 계산해 /api/fortune으로 문장을 생성한다.
 * 네트워크/서버 실패 시 룰 기반 폴백으로 항상 사용 가능한 결과를 만든다.
 */
export async function getTodayFortune(birthInfo: BirthInfo, opts: GetFortuneOptions = {}): Promise<FortuneResult> {
  const now = opts.now ?? new Date();
  const kst = kstDateOf(now);
  const key = cacheKey(birthInfo, kst.iso);

  if (!opts.force) {
    const cached = readCache(key);
    if (cached) return cached;
  }

  const evidence = computeFortuneEvidence(birthInfo, now);

  let result: FortuneResult;
  try {
    const res = await fetch("/api/fortune", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ evidence }),
    });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = (await res.json()) as { content: FortuneResult["content"]; source: FortuneResult["source"] };
    result = { evidence, content: data.content, source: data.source ?? "llm", createdAt: new Date().toISOString() };
  } catch {
    // 서버에 닿지 못해도 근거만으로 룰 기반 운세를 제공한다
    result = { evidence, content: buildFallbackFortune(evidence), source: "fallback", createdAt: new Date().toISOString() };
  }

  writeCache(key, result);
  pruneOldCache(birthInfo, kst.iso);
  return result;
}
