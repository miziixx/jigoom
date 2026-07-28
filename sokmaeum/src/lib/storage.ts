import type { ReadingSession } from "../types";

const STORAGE_KEY = "sokmaeum:sessions";

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

/** 세션 목록 전체를 통째로 교체 저장한다 (백업 복원용) */
export function replaceAllSessions(sessions: ReadingSession[]): void {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(sessions));
}

export function deleteSession(id: string): void {
  const sessions = loadSessions().filter((s) => s.id !== id);
  localStorage.setItem(STORAGE_KEY, JSON.stringify(sessions));
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
