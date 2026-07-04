import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import TarotFactsPanel from "./TarotFactsPanel.js";
import { TAROT_DECK } from "../data/tarotDeck.js";
import type { DrawnTarotCard } from "../types/index.js";

function drawn(namePrefix: string, position: number, positionLabel: string, reversed = false): DrawnTarotCard {
  const card = TAROT_DECK.find((c) => c.name.startsWith(namePrefix));
  if (!card) throw new Error(`카드 없음: ${namePrefix}`);
  return { card, reversed, position, positionLabel };
}

describe("TarotFactsPanel", () => {
  it("각 카드의 자리·방향·원소 근거를 보여준다", () => {
    const cards = [
      drawn("Ace of Wands", 1, "현재 상황"),
      drawn("Ace of Cups", 2, "장애물/과제", true),
      drawn("Ace of Pentacles", 3, "조언"),
    ];
    const html = renderToStaticMarkup(<TarotFactsPanel cards={cards} />);
    expect(html).toContain("현재 상황");
    expect(html).toContain("역방향");
    expect(html).toContain("불");
    expect(html).toContain("물");
    // 배열 근거: 정/역·메이저 비율 칩
    expect(html).toContain("정방향");
    expect(html).toContain("메이저");
    // 인접 관계: 불↔물은 약화
    expect(html).toContain("힘이 부딪힘");
  });

  it("카드가 없으면 아무것도 렌더하지 않는다", () => {
    expect(renderToStaticMarkup(<TarotFactsPanel cards={[]} />)).toBe("");
  });
});
