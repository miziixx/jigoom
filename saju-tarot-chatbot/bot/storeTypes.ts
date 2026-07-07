// 롱폴링(fileStore)과 웹훅(kvStore) 두 저장소 구현이 공유하는 타입/인터페이스.
import type { BirthInfo } from "../src/types/index.js";

export interface ChatTurn {
  role: "user" | "assistant";
  content: string;
}

export interface UserRecord {
  birthInfo: BirthInfo | null;
  history: ChatTurn[];
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
}

export function emptyUser(): UserRecord {
  return { birthInfo: null, history: [], updatedAt: new Date().toISOString() };
}
