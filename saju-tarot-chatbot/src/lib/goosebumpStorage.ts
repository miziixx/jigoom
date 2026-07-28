import type { GoosebumpConfirmation } from "../types";

const STORAGE_KEY = "saju-tarot-chatbot:goosebump-confirmations";

/** 소름 엔진(C-1) 확인/부인 기록 — §7 point 2: "실측 적중 통계가 다시 신뢰 소재가 된다" 선순환용. */
export function loadGoosebumpConfirmations(): GoosebumpConfirmation[] {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    return raw ? (JSON.parse(raw) as GoosebumpConfirmation[]) : [];
  } catch {
    return [];
  }
}

export function saveGoosebumpConfirmation(confirmation: GoosebumpConfirmation): void {
  const list = loadGoosebumpConfirmations();
  list.unshift(confirmation);
  localStorage.setItem(STORAGE_KEY, JSON.stringify(list));
}

/** 지금까지 쌓인 적중 통계 (공유 카드·신뢰 배지에서 재사용). */
export function goosebumpAccuracySummary(): { total: number; yes: number; no: number; unsure: number } {
  const list = loadGoosebumpConfirmations();
  return {
    total: list.length,
    yes: list.filter((c) => c.answer === "yes").length,
    no: list.filter((c) => c.answer === "no").length,
    unsure: list.filter((c) => c.answer === "unsure").length,
  };
}
