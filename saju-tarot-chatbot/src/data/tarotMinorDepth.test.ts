import { describe, expect, it } from "vitest";
import { MINOR_DEPTH, minorDepthOf } from "./tarotMinorDepth.js";
import { describeMinorDepth } from "../lib/tarotSymbolism.js";
import { TAROT_DECK } from "./tarotDeck.js";

/**
 * 타로 마이너 심화 KB 완결성·안전성 audit (엔진 업그레이드 T-3a/b).
 * T-3a 시점: 완드(22~35)+컵(36~49) 28장. T-3b에서 소드·펜타클 추가 후 56장 전수로 확장.
 */

const MINOR_CARDS = TAROT_DECK.filter((c) => c.arcana === "minor");
const WANDS_CUPS = MINOR_CARDS.filter((c) => c.id >= 22 && c.id <= 49);

describe("마이너 심화 KB — 공통 안전성·구조", () => {
  it("모든 엔트리가 scene·shadow·advice를 비지 않게 채운다", () => {
    for (const [id, d] of Object.entries(MINOR_DEPTH)) {
      expect(d.scene.length, id).toBeGreaterThan(8);
      expect(d.shadow.length, id).toBeGreaterThan(6);
      expect(d.advice.length, id).toBeGreaterThan(6);
    }
  });

  it("공포·단정 표현을 쓰지 않는다 (참고용 톤)", () => {
    const forbidden = ["반드시", "절대", "무조건", "죽을", "이혼한다", "확실히", "틀림없"];
    for (const d of Object.values(MINOR_DEPTH)) {
      const text = `${d.scene} ${d.shadow} ${d.advice}`;
      for (const term of forbidden) expect(text.includes(term), term).toBe(false);
    }
  });

  it("메이저(0~21)는 심화가 없다 (describeMinorDepth null)", () => {
    const major = TAROT_DECK.find((c) => c.arcana === "major")!;
    expect(describeMinorDepth(major)).toBeNull();
    expect(minorDepthOf(major.id)).toBeUndefined();
  });
});

describe("마이너 심화 KB — 완드·컵 28장 (T-3a)", () => {
  it("완드(22~35)+컵(36~49) 28장이 모두 심화로 매핑된다", () => {
    expect(WANDS_CUPS).toHaveLength(28);
    for (const card of WANDS_CUPS) {
      expect(describeMinorDepth(card), card.name).not.toBeNull();
    }
  });
});

describe("마이너 심화 KB — 마이너 56장 전수 완결성 (T-3b)", () => {
  it("MINOR_DEPTH가 마이너 56장 id(22~77)와 정확히 일치한다 (허수·누락 0)", () => {
    const deckMinorIds = new Set(MINOR_CARDS.map((c) => c.id));
    const kbIds = new Set(Object.keys(MINOR_DEPTH).map(Number));
    expect(kbIds).toEqual(deckMinorIds);
    expect(MINOR_CARDS).toHaveLength(56);
    expect(Object.keys(MINOR_DEPTH)).toHaveLength(56);
  });

  it("덱의 모든 마이너 카드가 describeMinorDepth로 매핑되고, 코트도 포함한다", () => {
    for (const card of MINOR_CARDS) {
      expect(describeMinorDepth(card), card.name).not.toBeNull();
    }
    // 코트 카드(예: King of Pentacles id 77)도 심화가 있다
    const king = MINOR_CARDS.find((c) => c.id === 77)!;
    expect(describeMinorDepth(king)).not.toBeNull();
  });
});
