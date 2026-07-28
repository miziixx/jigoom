import { describe, expect, it } from "vitest";
import {
  TAROT_COMBOS,
  TAROT_COMBO_LIST,
  comboPairKey,
  detectCardCombos,
} from "./tarotCombos.js";
import { TAROT_DECK } from "./tarotDeck.js";
import type { DrawnTarotCard } from "../types/index.js";

/**
 * 타로 카드 조합 KB 완결성·안전성 audit (엔진 업그레이드 T-2).
 * "모든 조합이 실존 카드(0~77) 쌍이고 중복이 없다" + 감지기 정확성 + 서술 안전성.
 */

const DECK_IDS = new Set(TAROT_DECK.map((c) => c.id));

function drawById(id: number, position: number, reversed = false): DrawnTarotCard {
  const card = TAROT_DECK.find((c) => c.id === id);
  if (!card) throw new Error(`카드 없음: ${id}`);
  return { card, reversed, position };
}

describe("타로 조합 KB 완결성", () => {
  it("40개 이상의 조합을 담는다", () => {
    expect(TAROT_COMBO_LIST.length).toBeGreaterThanOrEqual(40);
  });

  it("모든 조합이 실존 카드(0~77) 서로 다른 두 장이다", () => {
    for (const e of TAROT_COMBO_LIST) {
      const [a, b] = e.cards;
      expect(DECK_IDS.has(a), `${e.label} a=${a}`).toBe(true);
      expect(DECK_IDS.has(b), `${e.label} b=${b}`).toBe(true);
      expect(a).not.toBe(b);
      expect(a).toBeLessThan(b); // 오름차순 정렬 보장
    }
  });

  it("조합 키에 중복이 없다", () => {
    const keys = TAROT_COMBO_LIST.map((e) => comboPairKey(e.cards[0], e.cards[1]));
    expect(new Set(keys).size).toBe(keys.length);
    expect(Object.keys(TAROT_COMBOS).length).toBe(keys.length);
  });

  it("label·signal이 비어 있지 않다", () => {
    for (const e of TAROT_COMBO_LIST) {
      expect(e.label.length, e.label).toBeGreaterThan(2);
      expect(e.signal.length, e.label).toBeGreaterThan(10);
    }
  });
});

describe("조합 감지기 detectCardCombos", () => {
  it("KB에 있는 쌍이 스프레드에 함께 있으면 감지한다 (정·역 무관)", () => {
    // 연인(6) + 컵 2(37) 조합
    const cards = [drawById(6, 1), drawById(37, 2, true)];
    const found = detectCardCombos(cards);
    expect(found).toHaveLength(1);
    expect(found[0].entry.cards).toEqual([6, 37]);
  });

  it("KB에 없는 쌍은 감지하지 않는다", () => {
    // 임의의 비조합 쌍(바보0 + 소드4=53)은 KB에 없음
    const cards = [drawById(0, 1), drawById(53, 2)];
    expect(detectCardCombos(cards)).toHaveLength(0);
  });

  it("여러 조합이 있으면 모두, 자리 순서대로 감지한다", () => {
    // 6+37(연인+컵2)와 13+16(죽음+탑) 두 조합이 모두 존재하도록 배치
    const cards = [drawById(6, 1), drawById(13, 2), drawById(37, 3), drawById(16, 4)];
    const found = detectCardCombos(cards);
    const keys = found.map((f) => comboPairKey(f.entry.cards[0], f.entry.cards[1]));
    expect(keys).toContain("6+37");
    expect(keys).toContain("13+16");
    expect(found.length).toBeGreaterThanOrEqual(2);
  });

  it("카드가 1장뿐이면 조합이 없다", () => {
    expect(detectCardCombos([drawById(6, 1)])).toHaveLength(0);
  });
});

describe("조합 서술 안전성", () => {
  it("공포·단정 표현을 쓰지 않는다 (참고용 톤)", () => {
    const forbidden = ["반드시", "절대", "무조건", "죽을", "이혼한다", "확실히", "틀림없"];
    for (const e of TAROT_COMBO_LIST) {
      const text = `${e.label} ${e.signal}`;
      for (const term of forbidden) {
        expect(text.includes(term), `${e.label}: '${term}'`).toBe(false);
      }
    }
  });
});
