import { TAROT_DECK } from "../data/tarotDeck";
import type { DrawnTarotCard } from "../types";

export type SpreadSize = 1 | 3 | 5;

export const SPREAD_LABEL: Record<SpreadSize, string> = {
  1: "1장 (오늘의 카드)",
  3: "3장 (과거·현재·미래)",
  5: "5장 (상황·장애물·조언·주변·전개)",
};

// 각 스프레드에서 자리(포지션)가 갖는 의미 — 카드 조합 해석의 근거가 된다
const POSITION_LABELS: Record<SpreadSize, string[]> = {
  1: ["핵심 메시지"],
  3: ["과거/원인", "현재 상황", "가까운 흐름"],
  5: ["현재 상황", "장애물/과제", "조언", "주변/환경의 흐름", "가능성 높은 전개"],
};

/** count장을 중복 없이 무작위로 뽑고, 각 카드는 50% 확률로 역방향이 된다 */
export function drawCards(count: SpreadSize): DrawnTarotCard[] {
  const shuffled = [...TAROT_DECK].sort(() => Math.random() - 0.5);
  const labels = POSITION_LABELS[count];
  return shuffled.slice(0, count).map((card, index) => ({
    card,
    reversed: Math.random() < 0.5,
    position: index + 1,
    positionLabel: labels[index],
  }));
}
