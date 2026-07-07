import { mkdirSync, readFileSync, writeFileSync, existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
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

const DATA_DIR = process.env.BOT_DATA_DIR ?? join(dirname(fileURLToPath(import.meta.url)), "data");
const DATA_FILE = join(DATA_DIR, "users.json");
// 오래된 맥락은 잘라 토큰을 아끼고 최근 대화 흐름만 유지한다
const MAX_HISTORY = 40;

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

export function getUser(chatId: number): UserRecord {
  const users = load();
  const key = String(chatId);
  if (!users[key]) {
    users[key] = { birthInfo: null, history: [], updatedAt: new Date().toISOString() };
  }
  return users[key];
}

export function setBirthInfo(chatId: number, birthInfo: BirthInfo): void {
  const user = getUser(chatId);
  user.birthInfo = birthInfo;
  user.history = []; // 사주가 바뀌면 이전 해석 맥락은 무효
  user.updatedAt = new Date().toISOString();
  save();
}

export function appendHistory(chatId: number, ...turns: ChatTurn[]): void {
  const user = getUser(chatId);
  user.history.push(...turns);
  if (user.history.length > MAX_HISTORY) {
    user.history = user.history.slice(user.history.length - MAX_HISTORY);
  }
  user.updatedAt = new Date().toISOString();
  save();
}

export function clearHistory(chatId: number): void {
  const user = getUser(chatId);
  user.history = [];
  user.updatedAt = new Date().toISOString();
  save();
}

export function deleteUser(chatId: number): void {
  const users = load();
  delete users[String(chatId)];
  save();
}
