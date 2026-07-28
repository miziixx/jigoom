import { describe, expect, it } from "vitest";
import {
  describeElementalDignities,
  elementalRelation,
  tarotElementOf,
} from "./tarotSymbolism.js";
import { TAROT_DECK } from "../data/tarotDeck.js";
import type { DrawnTarotCard } from "../types/index.js";

function cardByName(name: string) {
  const card = TAROT_DECK.find((c) => c.name.startsWith(name));
  if (!card) throw new Error(`카드 없음: ${name}`);
  return card;
}

function drawn(name: string, position: number, positionLabel: string): DrawnTarotCard {
  return { card: cardByName(name), reversed: false, position, positionLabel };
}

describe("슈트 → 원소 매핑", () => {
  it("네 슈트와 메이저를 원소로 옮긴다", () => {
    expect(tarotElementOf(cardByName("Ace of Wands"))).toBe("불");
    expect(tarotElementOf(cardByName("Ace of Cups"))).toBe("물");
    expect(tarotElementOf(cardByName("Ace of Swords"))).toBe("공기");
    expect(tarotElementOf(cardByName("Ace of Pentacles"))).toBe("흙");
    expect(tarotElementOf(cardByName("The Fool"))).toBe("메이저");
  });
});

describe("원소 관계(엘리멘탈 디그니티) 규칙", () => {
  it("같은 원소와 친한 원소는 강화한다", () => {
    expect(elementalRelation("불", "불")).toBe("강화");
    expect(elementalRelation("불", "공기")).toBe("강화"); // 둘 다 능동
    expect(elementalRelation("물", "흙")).toBe("강화"); // 둘 다 수용
  });
  it("정반대 원소는 약화한다", () => {
    expect(elementalRelation("불", "물")).toBe("약화");
    expect(elementalRelation("공기", "흙")).toBe("약화");
  });
  it("애매한 조합은 중립이다", () => {
    expect(elementalRelation("불", "흙")).toBe("중립");
    expect(elementalRelation("공기", "물")).toBe("중립");
  });
  it("메이저가 끼면 강화로 본다", () => {
    expect(elementalRelation("메이저", "물")).toBe("강화");
  });
});

describe("배열 원소 진단 직렬화", () => {
  it("원소 분포와 인접 관계, 종합 판단을 담는다", () => {
    const cards = [
      drawn("Ace of Wands", 1, "현재 상황"),
      drawn("Ace of Cups", 2, "장애물/과제"),
      drawn("Ace of Pentacles", 3, "조언"),
    ];
    const text = describeElementalDignities(cards);
    expect(text).toContain("원소 분포");
    expect(text).toContain("인접 자리 원소 관계");
    // 불↔물 = 약화, 물↔흙 = 강화
    expect(text).toContain("약화");
    expect(text).toContain("강화");
    expect(text).toContain("종합:");
  });

  it("같은 슈트가 이어지면 강화 흐름으로 판단한다", () => {
    const cards = [
      drawn("Ace of Wands", 1, "현재"),
      drawn("Two of Wands", 2, "가까운 흐름"),
      drawn("Three of Wands", 3, "조언"),
    ];
    const text = describeElementalDignities(cards);
    expect(text).toContain("한쪽으로 뚜렷하게 몰리는");
    expect(text).toContain("중심 에너지");
  });

  it("빈 배열은 빈 문자열을 준다", () => {
    expect(describeElementalDignities([])).toBe("");
  });
});
