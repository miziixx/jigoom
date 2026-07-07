// 롱폴링(fileStore)과 웹훅(kvStore) 두 저장소 구현이 공유하는 타입/인터페이스.
import type { BirthInfo, CompatibilityRelationType } from "../src/types/index.js";

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

export interface UserRecord {
  birthInfo: BirthInfo | null;
  history: ChatTurn[];
  /** 여러 메시지에 걸친 흐름(궁합 등) 대기 상태. 없으면 일반 대화. */
  pending?: PendingCompat | null;
  updatedAt: string;
}

// 오래된 맥락은 잘라 토큰을 아끼고 최근 대화 흐름만 유지한다
export const MAX_HISTORY = 40;

export interface Store {
  getUser(chatId: number): Promise<UserRecord>;
  setBirthInfo(chatId: number, birthInfo: BirthInfo): Promise<void>;
  appendHistory(chatId: number, ...turns: ChatTurn[]): Promise<void>;
  clearHistory(chatId: number): Promise<void>;
  deleteUser(chatId: number): Promise<void>;
  /** 궁합 등 다단계 흐름의 대기 상태를 저장/해제 (null이면 해제) */
  setPending(chatId: number, pending: PendingCompat | null): Promise<void>;
}

export function emptyUser(): UserRecord {
  return { birthInfo: null, history: [], pending: null, updatedAt: new Date().toISOString() };
}
