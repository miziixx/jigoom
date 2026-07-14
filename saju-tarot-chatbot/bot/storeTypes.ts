// 롱폴링(fileStore)과 웹훅(kvStore) 두 저장소 구현이 공유하는 타입/인터페이스.
import type { BirthInfo, CompatibilityRelationType, DrawnTarotCard } from "../src/types/index.js";
import type { StoredPillars } from "./parseFourPillars.js";
import type { SpreadId } from "../src/lib/tarot.js";

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

/**
 * 마지막으로 뽑은 타로 스프레드. 후속 질문("그 카드 무슨 뜻이야?", "한 장 더")에서
 * 같은 카드를 근거로 이어 풀어주기 위해 유지한다. 새 스프레드를 뽑으면 통째로 덮어쓴다.
 * TTL은 대화 맥락(history)과 함께 초기화된다.
 */
export interface StoredTarot {
  spreadId: SpreadId;
  /** 이 스프레드를 뽑을 때의 질문(자리·해석의 맥락) */
  question: string;
  cards: DrawnTarotCard[];
  drawnAt: string;
}

/**
 * 학습모드 진도. 구조는 bot/studyMode.ts의 StudyState와 동일하지만,
 * 저장소 계층이 studyMode 구현을 몰라도 되게 여기서는 형태만 느슨하게 둔다.
 * history TTL·/reset과 무관하게 유지된다("배운 건 늘 기억") — /delete 때만 지워진다.
 */
export interface StudyRecord {
  chapter: number;
  passed: number[];
  quiz: Array<{ chapter: number; prompt: string; answers: string[]; explain: string; isReview?: boolean }> | null;
  qIndex: number;
  correctInQuiz: number;
  wrongNotes: Array<{ chapter: number; prompt: string; answers: string[]; explain: string }>;
  stats: { answered: number; correct: number };
  startedAt: string;
  /** true면 지금 들어오는 일반 텍스트를 퀴즈 답으로 처리한다 */
  active: boolean;
  /** "더 설명해줘" 딥다이브가 근거로 쓸, 방금 보여준 개념 */
  lastShown: { chapter: number; concept: string; explain: string } | null;
}

export interface UserRecord {
  birthInfo: BirthInfo | null;
  /** 생년월일시 대신 만세력 사주팔자(여덟 글자)를 직접 등록한 경우. birthInfo 와 상호배타. */
  pillars?: StoredPillars | null;
  history: ChatTurn[];
  /** 마지막으로 뽑은 타로 스프레드(후속 질문 맥락용). 없으면 아직 안 뽑음. */
  lastTarot?: StoredTarot | null;
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
  /** 학습모드 진도·오답노트. TTL 없음 — /delete 때만 삭제. */
  study?: StudyRecord | null;
  updatedAt: string;
}

// 오래된 맥락은 잘라 토큰을 아끼고 최근 대화 흐름만 유지한다.
// history는 프롬프트 캐시가 안 되는(고정 근거·시스템만 캐시됨) 부분이라 매 턴 입력 원가로
// 쌓인다 → 상한을 낮춰 긴 대화의 입력 토큰을 줄인다. 더 오래된 맥락은 memory 요약이 담당.
export const MAX_HISTORY = 16;

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
  /** 마지막 타로 스프레드 저장/해제 (후속 질문 맥락용, null이면 해제) */
  setLastTarot(chatId: number, tarot: StoredTarot | null): Promise<void>;
  /** 사용자가 명시적으로 요청한 요약만 기억에 추가한다 (원문 저장 금지) */
  addMemory(chatId: number, entry: Omit<MemoryEntry, "id" | "createdAt">): Promise<MemoryEntry>;
  /** 기억 삭제. mode "recent"면 가장 최근 N개, "all"이면 전부(옵션으로 카테고리 한정) */
  deleteMemory(chatId: number, opts: { mode: "recent" | "all"; category?: MemoryCategory; count?: number }): Promise<number>;
  /** 학습모드 진도 저장/해제 (null이면 진도 삭제) */
  setStudy(chatId: number, study: StudyRecord | null): Promise<void>;
}

export function emptyUser(): UserRecord {
  return {
    birthInfo: null,
    pillars: null,
    history: [],
    historyExpiresAt: null,
    pending: null,
    lastTarot: null,
    memories: [],
    study: null,
    updatedAt: new Date().toISOString(),
  };
}

/** history가 TTL을 넘겼으면 빈 배열로 되돌린 UserRecord를 반환한다 (원본 저장값은 호출부가 그대로 두거나 다시 저장). */
export function applyHistoryExpiry(user: UserRecord): UserRecord {
  if (!user.historyExpiresAt) return user;
  if (new Date(user.historyExpiresAt).getTime() > Date.now()) return user;
  // 맥락이 만료되면 타로 후속 질문 맥락(lastTarot)도 함께 비운다.
  return { ...user, history: [], historyExpiresAt: null, lastTarot: null };
}
