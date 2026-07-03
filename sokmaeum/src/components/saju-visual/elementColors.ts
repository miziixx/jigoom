import type { FiveElementBalance } from "../../types";

/** 오행별 표시 색상·라벨 (그래프/기둥 카드 공용) */
export const ELEMENT_META: Record<
  keyof FiveElementBalance,
  { ko: string; color: string; soft: string }
> = {
  wood: { ko: "목", color: "#4caf72", soft: "rgba(76,175,114,0.18)" },
  fire: { ko: "화", color: "#e5533c", soft: "rgba(229,83,60,0.18)" },
  earth: { ko: "토", color: "#d0a24c", soft: "rgba(208,162,76,0.18)" },
  metal: { ko: "금", color: "#c9ccd6", soft: "rgba(201,204,214,0.16)" },
  water: { ko: "수", color: "#4d8fe0", soft: "rgba(77,143,224,0.18)" },
};

export const ELEMENT_ORDER: (keyof FiveElementBalance)[] = ["wood", "fire", "earth", "metal", "water"];

// 천간·지지 → 오행 (색 매핑용, 한글 기준)
const GAN_EL: Record<string, keyof FiveElementBalance> = {
  갑: "wood", 을: "wood", 병: "fire", 정: "fire", 무: "earth",
  기: "earth", 경: "metal", 신: "metal", 임: "water", 계: "water",
};
const ZHI_EL: Record<string, keyof FiveElementBalance> = {
  자: "water", 축: "earth", 인: "wood", 묘: "wood", 진: "earth", 사: "fire",
  오: "fire", 미: "earth", 신: "metal", 유: "metal", 술: "earth", 해: "water",
};

export function elementOfChar(ch: string): keyof FiveElementBalance | null {
  return GAN_EL[ch] ?? ZHI_EL[ch] ?? null;
}

export function colorOfChar(ch: string): string {
  const el = elementOfChar(ch);
  return el ? ELEMENT_META[el].color : "var(--text-dim)";
}

export function softOfChar(ch: string): string {
  const el = elementOfChar(ch);
  return el ? ELEMENT_META[el].soft : "var(--surface-alt)";
}
