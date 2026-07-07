// 로컬 파일 저장소 — 롱폴링(bot/index.ts, 로컬 개발/테스트용)에서만 쓴다.
// Vercel 서버리스(웹훅)는 파일시스템이 요청마다 초기화되므로 kvStore.ts(Upstash Redis)를 쓴다.
import { mkdirSync, readFileSync, writeFileSync, existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import type { BirthInfo } from "../src/types/index.js";
import { MAX_HISTORY, emptyUser, type ChatTurn, type Store, type UserRecord } from "./storeTypes.js";

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
  return users[key];
}

export const fileStore: Store = {
  async getUser(chatId: number): Promise<UserRecord> {
    return getUserSync(chatId);
  },

  async setBirthInfo(chatId: number, birthInfo: BirthInfo): Promise<void> {
    const user = getUserSync(chatId);
    user.birthInfo = birthInfo;
    user.history = []; // 사주가 바뀌면 이전 해석 맥락은 무효
    user.updatedAt = new Date().toISOString();
    save();
  },

  async appendHistory(chatId: number, ...turns: ChatTurn[]): Promise<void> {
    const user = getUserSync(chatId);
    user.history.push(...turns);
    if (user.history.length > MAX_HISTORY) {
      user.history = user.history.slice(user.history.length - MAX_HISTORY);
    }
    user.updatedAt = new Date().toISOString();
    save();
  },

  async clearHistory(chatId: number): Promise<void> {
    const user = getUserSync(chatId);
    user.history = [];
    user.updatedAt = new Date().toISOString();
    save();
  },

  async deleteUser(chatId: number): Promise<void> {
    const users = load();
    delete users[String(chatId)];
    save();
  },
};
