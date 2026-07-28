import type { BirthInfo } from "../types";
import { loadProfile, saveProfile } from "./profile";

/**
 * 저장된 사주 목록 (C-4 사이드바 "저장된 사주 전환", 재기획안 §5).
 *
 * profile.ts의 단일 "현재 프로필" 개념은 그대로 둔다(BirthInfoForm·useFortuneStore·TarotTodayPage·
 * ComboPage가 이미 그걸 읽고 쓰므로 건드리면 회귀 위험). 이 모듈은 그 위에 "이름 붙은 여러 명식"
 * 목록만 추가한다 — 목록에서 하나를 고르면(activateProfile) 기존 saveProfile()을 호출해 "현재
 * 프로필"을 바꿔치기하므로, 기존 소비자들은 코드 변경 없이 전환된 명식을 그대로 이어받는다.
 */
export interface SavedProfile {
  id: string;
  label: string;
  birthInfo: BirthInfo;
  savedAt: string;
}

const LIST_KEY = "saju-tarot-chatbot:profile-list";

function defaultLabel(birthInfo: BirthInfo): string {
  if (birthInfo.displayName?.trim()) return birthInfo.displayName.trim();
  return `${birthInfo.year}-${String(birthInfo.month).padStart(2, "0")}-${String(birthInfo.day).padStart(2, "0")}`;
}

export function loadProfileList(): SavedProfile[] {
  try {
    const raw = localStorage.getItem(LIST_KEY);
    return raw ? (JSON.parse(raw) as SavedProfile[]) : [];
  } catch {
    return [];
  }
}

/** 같은 생년월일시(같은 명식)면 새로 추가하지 않고 기존 항목을 갱신한다. */
export function saveProfileToList(birthInfo: BirthInfo, label?: string): SavedProfile {
  const list = loadProfileList();
  const key = JSON.stringify({ y: birthInfo.year, m: birthInfo.month, d: birthInfo.day, h: birthInfo.hour, min: birthInfo.minute, c: birthInfo.calendarType });
  const existingIndex = list.findIndex(
    (p) => JSON.stringify({ y: p.birthInfo.year, m: p.birthInfo.month, d: p.birthInfo.day, h: p.birthInfo.hour, min: p.birthInfo.minute, c: p.birthInfo.calendarType }) === key,
  );
  const entry: SavedProfile = {
    id: existingIndex >= 0 ? list[existingIndex].id : `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
    label: label?.trim() || defaultLabel(birthInfo),
    birthInfo,
    savedAt: new Date().toISOString(),
  };
  if (existingIndex >= 0) list[existingIndex] = entry;
  else list.unshift(entry);
  localStorage.setItem(LIST_KEY, JSON.stringify(list));
  return entry;
}

export function deleteProfileFromList(id: string): void {
  const list = loadProfileList().filter((p) => p.id !== id);
  localStorage.setItem(LIST_KEY, JSON.stringify(list));
}

/** 목록에서 하나를 골라 "현재 프로필"로 전환한다. 기존 saveProfile()을 그대로 재사용한다. */
export function activateProfile(id: string): BirthInfo | null {
  const found = loadProfileList().find((p) => p.id === id);
  if (!found) return null;
  saveProfile(found.birthInfo);
  return found.birthInfo;
}

/** 지금 "현재 프로필"이 목록의 어느 항목과 같은 명식인지(전환 UI에 표시용). */
export function activeProfileId(): string | null {
  const current = loadProfile();
  if (!current) return null;
  const list = loadProfileList();
  const key = (b: BirthInfo) => `${b.year}-${b.month}-${b.day}-${b.hour}-${b.minute}-${b.calendarType}`;
  const found = list.find((p) => key(p.birthInfo) === key(current));
  return found?.id ?? null;
}
