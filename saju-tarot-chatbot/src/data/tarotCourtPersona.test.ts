import { describe, expect, it } from "vitest";
import { COURT_PERSONA, COURT_PERSONA_LIST, courtKey, type CourtRank, type CourtSuit } from "./tarotCourtPersona.js";
import { describeCourtPersona } from "../lib/tarotSymbolism.js";
import { TAROT_DECK } from "./tarotDeck.js";

/**
 * 타로 코트 페르소나 KB 완결성 audit (엔진 업그레이드 T-1).
 * "KB = 실제 코트 카드 16장 집합"을 자동 검증(허수·누락 없음) + 서술 안전성.
 */

const SUITS: CourtSuit[] = ["완드", "컵", "소드", "펜타클"];
const RANKS: CourtRank[] = ["Page", "Knight", "Queen", "King"];

/** 덱에서 코트 카드만: 이름이 Page/Knight/Queen/King of {suit} 형태 */
const COURT_CARDS = TAROT_DECK.filter((c) => /^(Page|Knight|Queen|King) of (Wands|Cups|Swords|Pentacles)/.test(c.name));

describe("코트 페르소나 KB 완결성", () => {
  it("정확히 16개 엔트리 (4슈트 × 4계급)", () => {
    expect(COURT_PERSONA_LIST).toHaveLength(16);
    expect(Object.keys(COURT_PERSONA)).toHaveLength(16);
  });

  it("4×4 조합 키가 빠짐없이 존재하고 중복이 없다", () => {
    const keys = new Set<string>();
    for (const suit of SUITS) {
      for (const rank of RANKS) {
        const key = courtKey(suit, rank);
        expect(COURT_PERSONA[key], key).toBeDefined();
        keys.add(key);
      }
    }
    expect(keys.size).toBe(16);
  });

  it("덱의 코트 카드 16장이 모두 페르소나로 매핑된다 (허수·누락 0)", () => {
    expect(COURT_CARDS).toHaveLength(16);
    for (const card of COURT_CARDS) {
      const persona = describeCourtPersona(card);
      expect(persona, card.name).not.toBeNull();
      // 카드 이름의 한글 명칭과 title 일치
      expect(card.name).toContain(persona!.title);
    }
  });

  it("코트가 아닌 카드(메이저·숫자 카드)는 null을 반환한다", () => {
    const major = TAROT_DECK.find((c) => c.arcana === "major")!;
    const ace = TAROT_DECK.find((c) => /^Ace of/.test(c.name))!;
    const ten = TAROT_DECK.find((c) => /^Ten of/.test(c.name))!;
    expect(describeCourtPersona(major)).toBeNull();
    expect(describeCourtPersona(ace)).toBeNull();
    expect(describeCourtPersona(ten)).toBeNull();
  });

  it("모든 엔트리가 4개 서술 필드를 비지 않게 채운다", () => {
    for (const e of COURT_PERSONA_LIST) {
      expect(e.persona.length, e.title).toBeGreaterThan(10);
      expect(e.maturity.length, e.title).toBeGreaterThan(10);
      expect(e.relationship.length, e.title).toBeGreaterThan(10);
      expect(e.reversedDistortion.length, e.title).toBeGreaterThan(10);
    }
  });
});

describe("코트 페르소나 서술 안전성", () => {
  it("공포·단정 표현을 쓰지 않는다 (참고용 톤)", () => {
    const forbidden = ["반드시", "절대", "무조건", "죽", "이혼", "질병", "확실히", "틀림없"];
    for (const e of COURT_PERSONA_LIST) {
      const text = [e.persona, e.maturity, e.relationship, e.reversedDistortion].join(" ");
      for (const term of forbidden) {
        expect(text.includes(term), `${e.title}: '${term}'`).toBe(false);
      }
    }
  });

  it("성숙 축이 계급별로 구분된다 (Page=시작, King=완성 계열 단어 포함)", () => {
    for (const suit of SUITS) {
      expect(COURT_PERSONA[courtKey(suit, "Page")].maturity).toContain("시작");
      expect(COURT_PERSONA[courtKey(suit, "King")].maturity).toContain("완성");
    }
  });
});
