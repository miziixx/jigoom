import { TAROT_DECK } from "../data/tarotDeck";
import type { DrawnTarotCard } from "../types";

/** count장을 중복 없이 무작위로 뽑고, 각 카드는 50% 확률로 역방향이 된다 */
export function drawCards(count: number): DrawnTarotCard[] {
  const shuffled = [...TAROT_DECK].sort(() => Math.random() - 0.5);
  return shuffled.slice(0, count).map((card, index) => ({
    card,
    reversed: Math.random() < 0.5,
    position: index + 1,
  }));
}
