import type { BirthInfo } from "../types";
import { loadSessions } from "./storage";

/**
 * 사용자 명식(생년월일시) 프로필을 localStorage에 저장한다.
 * 이 앱은 서버 인증이 없으므로 "저장된 사용자 명식"은 곧 이 프로필이다.
 * 오늘의 운세 탭에서 매일 재입력 없이 명식을 재사용하기 위한 저장소.
 */
const PROFILE_KEY = "sokmaeum:profile";

export function loadProfile(): BirthInfo | null {
  try {
    const raw = localStorage.getItem(PROFILE_KEY);
    return raw ? (JSON.parse(raw) as BirthInfo) : null;
  } catch {
    return null;
  }
}

export function saveProfile(birthInfo: BirthInfo): void {
  try {
    localStorage.setItem(PROFILE_KEY, JSON.stringify(birthInfo));
  } catch {
    // 저장 실패(용량 등)는 치명적이지 않다
  }
}

export function clearProfile(): void {
  try {
    localStorage.removeItem(PROFILE_KEY);
  } catch {
    // no-op
  }
}

/**
 * 저장된 명식을 해석한다.
 * 1) 명시적으로 저장한 프로필 → 2) 없으면 기존 리딩 기록의 가장 최근 birthInfo 재사용.
 * (기존 앱에 이미 명식이 있으면 그대로 재사용한다는 요구사항 반영)
 */
export function resolveSavedBirth(): BirthInfo | null {
  const profile = loadProfile();
  if (profile) return profile;
  const last = loadSessions().find((s) => s.birthInfo);
  return last?.birthInfo ?? null;
}
