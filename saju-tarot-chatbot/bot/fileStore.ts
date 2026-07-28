// 로컬 파일 저장소 — 롱폴링(bot/index.ts, 로컬 개발/테스트용)에서만 쓴다.
// Vercel 서버리스(웹훅)는 파일시스템이 요청마다 초기화되므로 kvStore.ts(Upstash Redis)를 쓴다.
import { mkdirSync, readFileSync, writeFileSync, existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import type { BirthInfo } from "../src/types/index.js";
import type { StoredPillars } from "./parseFourPillars.js";
import {
  MAX_HISTORY,
  HISTORY_TTL_MINUTES,
  emptyUser,
  applyHistoryExpiry,
  type ChatTurn,
  type MemoryCategory,
  type MemoryEntry,
  type PendingState,
  type StoredTarot,
  type Store,
  type StudyRecord,
  type UserRecord,
} from "./storeTypes.js";

const DATA_DIR = process.env.BOT_DATA_DIR ?? join(dirname(fileURLToPath(import.meta.url)), "data");
const DATA_FILE = join(DATA_DIR, "users.json");

let cache: Record<string, UserRecord> | null = null;

function load(): Record<string, UserRecord> {
  if (cache) return cache;
  if (existsSync(DATA_FILE)) {
    try {
      cache = JSON.parse(readFileSync(DATA_FILE, "utf-8"));
    } catch {
      cache = {};
    }
  } else {
    cache = {};
  }
  return cache!;
}

function save(): void {
  mkdirSync(DATA_DIR, { recursive: true });
  writeFileSync(DATA_FILE, JSON.stringify(load(), null, 2), "utf-8");
}

function getUserSync(chatId: number): UserRecord {
  const users = load();
  const key = String(chatId);
  if (!users[key]) {
    users[key] = emptyUser();
  }
  const expired = applyHistoryExpiry(users[key]);
  if (expired !== users[key]) {
    users[key] = expired;
    save();
  }
  return users[key];
}

export const fileStore: Store = {
  async getUser(chatId: number): Promise<UserRecord> {
    return getUserSync(chatId);
  },

  async setBirthInfo(chatId: number, birthInfo: BirthInfo): Promise<void> {
    const user = getUserSync(chatId);
    user.birthInfo = birthInfo;
    user.pillars = null; // 생년월일시로 등록하면 팔자 직접입력은 해제
    user.history = []; // 사주가 바뀌면 이전 해석 맥락은 무효
    user.pending = null;
    user.lastTarot = null;
    user.updatedAt = new Date().toISOString();
    save();
  },

  async updateGender(chatId: number, gender: BirthInfo["gender"]): Promise<void> {
    const user = getUserSync(chatId);
    if (!user.birthInfo) return; // 성별로 대운 방향이 갈리는 건 되짚은 생일이 있을 때만
    user.birthInfo = { ...user.birthInfo, gender };
    user.updatedAt = new Date().toISOString();
    save();
  },

  async setPillars(chatId: number, pillars: StoredPillars): Promise<void> {
    const user = getUserSync(chatId);
    user.pillars = pillars;
    user.birthInfo = null; // 팔자 직접입력으로 등록하면 생년월일시는 해제
    user.history = [];
    user.pending = null;
    user.lastTarot = null;
    user.updatedAt = new Date().toISOString();
    save();
  },

  async setPending(chatId: number, pending: PendingState | null): Promise<void> {
    const user = getUserSync(chatId);
    user.pending = pending;
    user.updatedAt = new Date().toISOString();
    save();
  },

  async setLastTarot(chatId: number, tarot: StoredTarot | null): Promise<void> {
    const user = getUserSync(chatId);
    user.lastTarot = tarot;
    user.updatedAt = new Date().toISOString();
    save();
  },

  async setStudy(chatId: number, study: StudyRecord | null): Promise<void> {
    const user = getUserSync(chatId);
    user.study = study;
    user.updatedAt = new Date().toISOString();
    save();
  },

  async appendHistory(chatId: number, ...turns: ChatTurn[]): Promise<void> {
    const user = getUserSync(chatId);
    user.history.push(...turns);
    if (user.history.length > MAX_HISTORY) {
      user.history = user.history.slice(user.history.length - MAX_HISTORY);
    }
    user.historyExpiresAt = new Date(Date.now() + HISTORY_TTL_MINUTES * 60 * 1000).toISOString();
    user.updatedAt = new Date().toISOString();
    save();
  },

  async clearHistory(chatId: number): Promise<void> {
    const user = getUserSync(chatId);
    user.history = [];
    user.historyExpiresAt = null;
    user.pending = null;
    user.lastTarot = null;
    user.updatedAt = new Date().toISOString();
    save();
  },

  async deleteUser(chatId: number): Promise<void> {
    const users = load();
    delete users[String(chatId)];
    save();
  },

  async addMemory(chatId: number, entry: Omit<MemoryEntry, "id" | "createdAt">): Promise<MemoryEntry> {
    const user = getUserSync(chatId);
    if (!user.memories) user.memories = [];
    const full: MemoryEntry = { ...entry, id: `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`, createdAt: new Date().toISOString() };
    user.memories.push(full);
    user.updatedAt = new Date().toISOString();
    save();
    return full;
  },

  async deleteMemory(chatId: number, opts: { mode: "recent" | "all"; category?: MemoryCategory; count?: number }): Promise<number> {
    const user = getUserSync(chatId);
    const memories = user.memories ?? [];
    const matches = (m: MemoryEntry) => !opts.category || m.category === opts.category;
    let removed = 0;
    if (opts.mode === "all") {
      const before = memories.length;
      user.memories = memories.filter((m) => !matches(m));
      removed = before - user.memories.length;
    } else {
      const count = opts.count ?? 1;
      const kept: MemoryEntry[] = [];
      for (let i = memories.length - 1; i >= 0; i--) {
        if (matches(memories[i]) && removed < count) {
          removed++;
          continue;
        }
        kept.unshift(memories[i]);
      }
      user.memories = kept;
    }
    user.updatedAt = new Date().toISOString();
    save();
    return removed;
  },
};
