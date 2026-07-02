import type { ReadingSession } from "../types";

const STORAGE_KEY = "saju-tarot-chatbot:sessions";

export function loadSessions(): ReadingSession[] {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    return raw ? (JSON.parse(raw) as ReadingSession[]) : [];
  } catch {
    return [];
  }
}

export function saveSession(session: ReadingSession): void {
  const sessions = loadSessions().filter((s) => s.id !== session.id);
  sessions.unshift(session);
  localStorage.setItem(STORAGE_KEY, JSON.stringify(sessions));
}

export function deleteSession(id: string): void {
  const sessions = loadSessions().filter((s) => s.id !== id);
  localStorage.setItem(STORAGE_KEY, JSON.stringify(sessions));
}
