import { describe, it, expect } from "vitest";
import { selectSpread, drawForQuestion, buildTarotEvidenceText, describeDrawnCardsShort } from "./tarotReading.js";
import { SPREADS } from "../src/lib/tarot.js";

describe("selectSpread", () => {
  it("관계/연애 질문은 relation 스프레드를 고른다", () => {
    expect(selectSpread("이번 연애 어떻게 흘러갈까?")).toBe("relation");
    expect(selectSpread("그 사람 마음이 궁금해")).toBe("relation");
    expect(selectSpread("재회할 수 있을까")).toBe("relation");
  });

  it("두 선택지 비교 질문은 ab 스프레드를 고른다", () => {
    expect(selectSpread("이직할까 말까?")).toBe("ab");
    expect(selectSpread("A랑 B 둘 중 뭐가 나아?")).toBe("ab");
  });

  it("한 달 흐름 질문은 month 스프레드를 고른다", () => {
    expect(selectSpread("이번 달 흐름 봐줘")).toBe("month");
  });

  it("깊게/정밀 요청은 celtic 스프레드를 고른다", () => {
    expect(selectSpread("이거 진짜 중요한데 제대로 깊게 봐줘")).toBe("celtic");
    expect(selectSpread("켈틱크로스로 봐줘")).toBe("celtic");
  });

  it("한 장만/간단히는 one 스프레드를 고른다", () => {
    expect(selectSpread("카드 한 장만 뽑아줘")).toBe("one");
    expect(selectSpread("핵심만 빨리 봐줘")).toBe("one");
  });

  it("문제/해결 질문은 soa 스프레드를 고른다", () => {
    expect(selectSpread("일이 자꾸 막히는데 어떻게 해야 풀릴까")).toBe("soa");
  });

  it("애매한 질문은 기본 흐름(ppf)으로 간다", () => {
    expect(selectSpread("요즘 어때")).toBe("ppf");
  });
});

describe("drawForQuestion", () => {
  it("스프레드 자리 수만큼 카드를 뽑는다", () => {
    const { spreadId, cards } = drawForQuestion("이번 연애 봐줘");
    expect(cards.length).toBe(SPREADS[spreadId].positions.length);
    // 각 카드는 자리 라벨과 방향 정보를 가진다
    for (const c of cards) {
      expect(c.positionLabel).toBeTruthy();
      expect(typeof c.reversed).toBe("boolean");
    }
  });

  it("spreadOverride를 주면 그 배열로 강제한다", () => {
    const { spreadId, cards } = drawForQuestion("아무거나", "celtic");
    expect(spreadId).toBe("celtic");
    expect(cards.length).toBe(10);
  });
});

describe("buildTarotEvidenceText", () => {
  it("뽑힌 카드·진단·원소 조합·질문을 모두 담는다", () => {
    const { spreadId, cards } = drawForQuestion("이직할까 말까", "ppf");
    const text = buildTarotEvidenceText(spreadId, cards, "이직할까 말까");
    expect(text).toContain("[타로 계산 데이터");
    expect(text).toContain("[뽑힌 카드]");
    expect(text).toContain("[타로 조합 진단]");
    expect(text).toContain("엘리멘탈 디그니티");
    expect(text).toContain("이직할까 말까");
  });
});

describe("describeDrawnCardsShort", () => {
  it("스프레드 이름과 카드 목록을 보여준다", () => {
    const { spreadId, cards } = drawForQuestion("한 장만", "one");
    const short = describeDrawnCardsShort(spreadId, cards);
    expect(short).toContain(SPREADS.one.label);
    expect(short).toContain(cards[0].card.name);
  });
});
