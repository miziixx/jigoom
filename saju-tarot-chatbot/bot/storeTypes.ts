// 롱폴링(fileStore)과 웹훅(kvStore) 두 저장소 구현이 공유하는 타입/인터페이스.
import type { BirthInfo, CompatibilityRelationType } from "../src/types/index.js";
import type { StoredPillars } from "./parseFourPillars.js";

export interface ChatTurn {
  role: "user" | "assistant";
  content: string;
}

/** 궁합: 상대 생년월일시 입력을 기다리는 중간 상태 */
export interface PendingCompat {
  type: "compat";
  /** /궁합 명령에서 관계를 미리 지정했으면 담아둔다 (없으면 상대 입력 줄에서 찾음) */
  relationType?: CompatibilityRelationType;
}

/**
 * "기억(memory)" 카테고리. 사용자가 명시적으로 "기억해줘"라고 한 내용만,
 * 원문이 아니라 짧은 요약으로 저장한다. TTL 없이 명시적 삭제 요청 전까지 유지된다.
 */
export type MemoryCategory = "projectMemory" | "userPreference" | "repeatedPattern" | "writingStyle" | "decisionLog";

export interface MemoryEntry {
  id: string;
  category: MemoryCategory;
  /** 원문이 아니라 1~2문장 요약만 저장한다 */
  summary: string;
  /** 민감한 내용(건강·연애·재정·가족 등)으로 판단되면 true */
  sensitive: boolean;
  createdAt: string;
}

export interface UserRecord {
  birthInfo: BirthInfo | null;
  /** 생년월일시 대신 만세력 사주팔자(여덟 글자)를 직접 등록한 경우. birthInfo 와 상호배타. */
  pillars?: StoredPillars | null;
  history: ChatTurn[];
  /**
   * history 세션 만료 시각. 이 시각이 지나면 history는 자동으로 빈 배열 취급된다
   * (짧은 대화 맥락은 유지하되, 민감한 대화 원문이 서버에 무기한 쌓이지 않게 함).
   * null이면 만료 없음(아직 대화가 시작되지 않은 상태).
   */
  historyExpiresAt?: string | null;
  /** 여러 메시지에 걸친 흐름(궁합 등) 대기 상태. 없으면 일반 대화. */
  pending?: PendingCompat | null;
  /** 사용자가 명시적으로 "기억해줘"라고 요청한 요약들. TTL 없음. */
  memories?: MemoryEntry[];
  updatedAt: string;
}

// 오래된 맥락은 잘라 토큰을 아끼고 최근 대화 흐름만 유지한다
export const MAX_HISTORY = 40;

// history 세션 TTL(분). BOT_HISTORY_TTL_MINUTES env로 조정 가능. 기본 45분.
export const HISTORY_TTL_MINUTES = Number(process.env.BOT_HISTORY_TTL_MINUTES ?? "45") || 45;

export interface Store {
  getUser(chatId: number): Promise<UserRecord>;
  setBirthInfo(chatId: number, birthInfo: BirthInfo): Promise<void>;
  /** 만세력 사주팔자(여덟 글자) 직접 등록. birthInfo 는 지우고 대화 맥락도 초기화한다. */
  setPillars(chatId: number, pillars: StoredPillars): Promise<void>;
  appendHistory(chatId: number, ...turns: ChatTurn[]): Promise<void>;
  clearHistory(chatId: number): Promise<void>;
  deleteUser(chatId: number): Promise<void>;
  /** 궁합 등 다단계 흐름의 대기 상태를 저장/해제 (null이면 해제) */
  setPending(chatId: number, pending: PendingCompat | null): Promise<void>;
  /** 사용자가 명시적으로 요청한 요약만 기억에 추가한다 (원문 저장 금지) */
  addMemory(chatId: number, entry: Omit<MemoryEntry, "id" | "createdAt">): Promise<MemoryEntry>;
  /** 기억 삭제. mode "recent"면 가장 최근 N개, "all"이면 전부(옵션으로 카테고리 한정) */
  deleteMemory(chatId: number, opts: { mode: "recent" | "all"; category?: MemoryCategory; count?: number }): Promise<number>;
}

export function emptyUser(): UserRecord {
  return {
    birthInfo: null,
    pillars: null,
    history: [],
    historyExpiresAt: null,
    pending: null,
    memories: [],
    updatedAt: new Date().toISOString(),
  };
}

/** history가 TTL을 넘겼으면 빈 배열로 되돌린 UserRecord를 반환한다 (원본 저장값은 호출부가 그대로 두거나 다시 저장). */
export function applyHistoryExpiry(user: UserRecord): UserRecord {
  if (!user.historyExpiresAt) return user;
  if (new Date(user.historyExpiresAt).getTime() > Date.now()) return user;
  return { ...user, history: [], historyExpiresAt: null };
}
