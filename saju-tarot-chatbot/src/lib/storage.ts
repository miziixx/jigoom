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

export function isSessionSaved(id: string): boolean {
  return loadSessions().some((s) => s.id === id);
}

export function deleteSession(id: string): void {
  const sessions = loadSessions().filter((s) => s.id !== id);
  localStorage.setItem(STORAGE_KEY, JSON.stringify(sessions));
}

export function deleteAllSessions(): void {
  localStorage.removeItem(STORAGE_KEY);
}

/** 즐겨찾기 토글 후, 바뀐 세션을 반환한다 */
export function toggleFavorite(id: string): ReadingSession | undefined {
  const sessions = loadSessions();
  const session = sessions.find((s) => s.id === id);
  if (session) {
    session.favorite = !session.favorite;
    localStorage.setItem(STORAGE_KEY, JSON.stringify(sessions));
  }
  return session;
}
