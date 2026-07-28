import type { QualityEvent } from "./qualityTypes.js";

/**
 * Quality 이벤트 저장소 (Observer — 절대 throw하지 않는다).
 *
 * 인터페이스 + localStorage 구현 + 메모리 구현.
 * 저장 실패가 리딩을 깨뜨리면 안 되므로 모든 메서드는 실패를 삼키고 안전한 기본값을 돌려준다.
 * 향후 서버/DB sink는 이 인터페이스를 구현해 drop-in으로 교체할 수 있다 (확장성).
 */

export interface QualityStore {
  append(event: QualityEvent): void;
  readAll(): QualityEvent[];
  clear(): void;
  count(): number;
}

/** localStorage 링버퍼 상한 (개인정보 없음이라 넉넉히 둬도 되지만 용량 보호) */
export const QUALITY_STORE_CAP = 2000;
const STORAGE_KEY = "quality-events-v1";

function safeParse(raw: string | null): QualityEvent[] {
  if (!raw) return [];
  try {
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? (parsed as QualityEvent[]) : [];
  } catch {
    return [];
  }
}

/** 메모리 저장소 (테스트·SSR·localStorage 불가 환경 fallback) */
export class MemoryQualityStore implements QualityStore {
  private events: QualityEvent[] = [];
  constructor(private cap: number = QUALITY_STORE_CAP) {}

  append(event: QualityEvent): void {
    this.events.push(event);
    if (this.events.length > this.cap) {
      this.events.splice(0, this.events.length - this.cap);
    }
  }
  readAll(): QualityEvent[] {
    return this.events.slice();
  }
  clear(): void {
    this.events = [];
  }
  count(): number {
    return this.events.length;
  }
}

/** localStorage 저장소. 접근 불가·용량 초과 시 조용히 실패한다. */
export class LocalStorageQualityStore implements QualityStore {
  constructor(
    private key: string = STORAGE_KEY,
    private cap: number = QUALITY_STORE_CAP,
  ) {}

  private storage(): Storage | null {
    try {
      if (typeof localStorage === "undefined") return null;
      return localStorage;
    } catch {
      return null;
    }
  }

  append(event: QualityEvent): void {
    const s = this.storage();
    if (!s) return;
    try {
      const events = safeParse(s.getItem(this.key));
      events.push(event);
      const trimmed = events.length > this.cap ? events.slice(events.length - this.cap) : events;
      s.setItem(this.key, JSON.stringify(trimmed));
    } catch {
      // 용량 초과(QuotaExceeded) 등 — 관찰자는 조용히 포기한다
    }
  }
  readAll(): QualityEvent[] {
    const s = this.storage();
    if (!s) return [];
    try {
      return safeParse(s.getItem(this.key));
    } catch {
      return [];
    }
  }
  clear(): void {
    const s = this.storage();
    if (!s) return;
    try {
      s.removeItem(this.key);
    } catch {
      // ignore
    }
  }
  count(): number {
    return this.readAll().length;
  }
}

/** 앱 기본 저장소: 브라우저면 localStorage, 아니면 메모리. */
let defaultStore: QualityStore | null = null;

export function getQualityStore(): QualityStore {
  if (defaultStore) return defaultStore;
  const hasLocalStorage = (() => {
    try {
      return typeof localStorage !== "undefined";
    } catch {
      return false;
    }
  })();
  defaultStore = hasLocalStorage ? new LocalStorageQualityStore() : new MemoryQualityStore();
  return defaultStore;
}

/** 테스트에서 저장소를 주입/초기화 */
export function setQualityStore(store: QualityStore | null): void {
  defaultStore = store;
}
