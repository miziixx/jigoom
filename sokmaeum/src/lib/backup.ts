import type { ReadingSession } from "../types";
import { loadSessions, replaceAllSessions } from "./storage";

/**
 * 챗봇 대화(리딩 세션 + messages) 백업/복원.
 * 이 앱은 서버 DB 없이 localStorage에만 저장하므로, 기기 교체·초기화에 대비해
 * 대화를 JSON 파일로 내보내고 다시 가져올 수 있게 한다.
 */

const BACKUP_VERSION = 1;

interface BackupFile {
  app: "sokmaeum";
  version: number;
  exportedAt: string;
  sessions: ReadingSession[];
}

/** 저장된 모든 대화 세션을 백업 JSON 문자열로 직렬화 */
export function exportSessions(): string {
  const file: BackupFile = {
    app: "sokmaeum",
    version: BACKUP_VERSION,
    exportedAt: new Date().toISOString(),
    sessions: loadSessions(),
  };
  return JSON.stringify(file, null, 2);
}

/** 백업 JSON을 파일로 다운로드 */
export function downloadBackup(): void {
  const json = exportSessions();
  const blob = new Blob([json], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  const date = new Date().toISOString().slice(0, 10).replace(/-/g, "");
  a.href = url;
  a.download = `sokmaeum-backup-${date}.json`;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}

export interface ImportResult {
  ok: boolean;
  imported: number;
  message: string;
}

/**
 * 백업 JSON을 복원한다.
 * - mode "merge": 같은 id는 백업본으로 갱신, 나머지는 유지
 * - mode "replace": 기존 세션을 모두 지우고 백업본으로 대체
 */
export function importSessions(json: string, mode: "merge" | "replace"): ImportResult {
  let parsed: unknown;
  try {
    parsed = JSON.parse(json);
  } catch {
    return { ok: false, imported: 0, message: "JSON 형식이 올바르지 않습니다." };
  }

  const file = parsed as Partial<BackupFile>;
  if (!file || file.app !== "sokmaeum" || !Array.isArray(file.sessions)) {
    return { ok: false, imported: 0, message: "이 앱의 백업 파일이 아닙니다." };
  }

  const incoming = file.sessions.filter(
    (s): s is ReadingSession =>
      !!s && typeof (s as ReadingSession).id === "string" && Array.isArray((s as ReadingSession).messages),
  );
  if (incoming.length === 0) {
    return { ok: false, imported: 0, message: "복원할 대화가 없습니다." };
  }

  try {
    if (mode === "replace") {
      replaceAllSessions(incoming);
      return { ok: true, imported: incoming.length, message: `${incoming.length}개의 대화를 복원했습니다(덮어쓰기).` };
    }
    // merge: id 기준으로 갱신/추가 후 최신순 정렬
    const existing = new Map(loadSessions().map((s) => [s.id, s]));
    for (const s of incoming) existing.set(s.id, s);
    const merged = [...existing.values()].sort((a, b) => (a.createdAt < b.createdAt ? 1 : -1));
    replaceAllSessions(merged);
    return { ok: true, imported: incoming.length, message: `${incoming.length}개의 대화를 병합했습니다.` };
  } catch {
    return { ok: false, imported: 0, message: "저장 공간이 부족해 복원하지 못했습니다." };
  }
}
