// AI 결과 재사용 캐시 (localStorage).
// 같은 입력(원국+질문+포커스 등)이면 저장된 결과를 그대로 돌려줘서, 매번 API를
// 새로 부르지 않게 한다. 결과 일관성 + 토큰 비용 절감이 목적.
// 날짜 의존(올해/이번달/오늘 흐름) 결과가 오래 고정되지 않도록, 키에 기간 버킷을 섞는다.

const PREFIX = "insight-cache:";
const MAX_ENTRIES = 60; // 오래된 항목은 정리 (localStorage 용량 보호)

/** 키 순서에 무관하게 안정적으로 직렬화한다. */
function stableStringify(value: unknown): string {
  if (value === null || typeof value !== "object") return JSON.stringify(value);
  if (Array.isArray(value)) return `[${value.map(stableStringify).join(",")}]`;
  const obj = value as Record<string, unknown>;
  const keys = Object.keys(obj).sort();
  return `{${keys.map((k) => `${JSON.stringify(k)}:${stableStringify(obj[k])}`).join(",")}}`;
}

function hash(input: string): string {
  let h = 5381;
  for (let i = 0; i < input.length; i++) h = (h * 33) ^ input.charCodeAt(i);
  return (h >>> 0).toString(36);
}

/** 오늘(YYYY-MM-DD) 또는 이번 달(YYYY-MM) 버킷. 날짜 의존 결과의 신선도 기준. */
export function periodBucket(granularity: "day" | "month"): string {
  const d = new Date();
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  if (granularity === "month") return `${y}-${m}`;
  return `${y}-${m}-${String(d.getDate()).padStart(2, "0")}`;
}

function keyOf(namespace: string, payload: unknown): string {
  return `${PREFIX}${namespace}:${hash(stableStringify(payload))}`;
}

export function getCachedResult<T>(namespace: string, payload: unknown): T | null {
  try {
    const raw = localStorage.getItem(keyOf(namespace, payload));
    if (!raw) return null;
    const parsed = JSON.parse(raw) as { v: T; t: number };
    // 접근 시각 갱신 (LRU 정리용)
    localStorage.setItem(keyOf(namespace, payload), JSON.stringify({ v: parsed.v, t: Date.now() }));
    return parsed.v;
  } catch {
    return null;
  }
}

export function setCachedResult<T>(namespace: string, payload: unknown, value: T): void {
  try {
    localStorage.setItem(keyOf(namespace, payload), JSON.stringify({ v: value, t: Date.now() }));
    pruneIfNeeded();
  } catch {
    // 용량 초과 등은 조용히 무시 (캐시는 있으면 좋은 부가기능)
  }
}

/** 캐시 항목이 너무 많으면 오래된 것부터 제거한다. */
function pruneIfNeeded(): void {
  const entries: Array<{ key: string; t: number }> = [];
  for (let i = 0; i < localStorage.length; i++) {
    const key = localStorage.key(i);
    if (!key || !key.startsWith(PREFIX)) continue;
    try {
      const t = (JSON.parse(localStorage.getItem(key) || "{}") as { t?: number }).t ?? 0;
      entries.push({ key, t });
    } catch {
      entries.push({ key, t: 0 });
    }
  }
  if (entries.length <= MAX_ENTRIES) return;
  entries.sort((a, b) => a.t - b.t);
  for (const e of entries.slice(0, entries.length - MAX_ENTRIES)) localStorage.removeItem(e.key);
}
