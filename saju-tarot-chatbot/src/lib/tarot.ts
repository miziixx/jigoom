import { TAROT_DECK } from "../data/tarotDeck";
import type { DrawnTarotCard } from "../types";

export type SpreadId = "one" | "ppf" | "soa" | "five" | "ab" | "month" | "relation" | "celtic";
export type ShuffleId = "classic" | "cut" | "riffle" | "intuitive";

export interface SpreadDefinition {
  id: SpreadId;
  label: string;
  shortLabel?: string;
  desc?: string;
  /** 각 자리(포지션)의 의미 — 카드 조합 해석의 근거가 된다 */
  positions: string[];
  /** 이 배열만의 해석 방법 안내 (프롬프트에 전달) */
  note?: string;
}

export const SPREADS: Record<SpreadId, SpreadDefinition> = {
  one: {
    id: "one",
    label: "한 장으로 핵심만",
    shortLabel: "핵심 1장",
    desc: "지금 가장 먼저 봐야 할 메시지만 빠르게 확인해요.",
    positions: ["핵심 메시지"],
  },
  ppf: {
    id: "ppf",
    label: "지금 흐름 보기",
    shortLabel: "흐름 3장",
    desc: "왜 이렇게 됐는지, 지금 어떤지, 가까운 흐름을 봅니다.",
    positions: ["이 일이 생긴 배경", "현재 상황", "가까운 흐름"],
  },
  soa: {
    id: "soa",
    label: "문제와 해결책 보기",
    shortLabel: "해결 3장",
    desc: "지금 막힌 이유와 실제로 할 수 있는 행동을 봅니다.",
    positions: ["현재 상황", "막히는 지점", "현실 조언"],
    note: "장애물 카드가 나쁜 카드가 아니라 '풀어야 할 과제'라는 관점으로 읽고, 조언 카드를 현실 행동으로 번역하는 데 비중을 둬라.",
  },
  five: {
    id: "five",
    label: "상황을 깊게 보기",
    shortLabel: "정밀 5장",
    desc: "상황, 방해 요소, 주변 흐름, 전개까지 조금 더 자세히 봅니다.",
    positions: ["현재 상황", "막히는 지점", "현실 조언", "주변/환경의 흐름", "가능성 높은 전개"],
  },
  ab: {
    id: "ab",
    label: "두 선택지 비교",
    shortLabel: "선택 비교",
    desc: "A와 B 중 어느 쪽이 나에게 더 현실적인지 비교해요.",
    positions: ["현재 상황 (공통)", "A를 고르면 — 흐름", "A를 고르면 — 예상 전개", "B를 고르면 — 흐름", "B를 고르면 — 예상 전개"],
    note: "질문에서 선택지 A와 B가 각각 무엇인지 먼저 정리한 뒤, A열(2·3번)과 B열(4·5번)을 나란히 비교해라. 어느 쪽이 '어떤 조건에서, 어떤 사람에게' 유리한지로 결론을 내고, 한쪽을 단정적으로 강요하지 마라. 질문에 선택지가 명확히 없으면 사용자에게 A/B가 무엇인지 되물어라.",
  },
  month: {
    id: "month",
    label: "한 달 흐름 보기",
    shortLabel: "한 달 5장",
    desc: "이번 달의 전체 분위기와 주차별 흐름을 봅니다.",
    positions: ["이번 달 전체 기조", "1주차", "2주차", "3주차", "4주차"],
    note: "전체 기조 카드를 축으로 주차별 카드를 연결해, 한 달의 리듬(시작-전개-조심할 구간-마무리)으로 해석해라. 주차별로 '이 주에 하면 좋은 것 1가지'를 붙여라.",
  },
  relation: {
    id: "relation",
    label: "관계 속마음과 흐름",
    shortLabel: "관계 5장",
    desc: "나와 상대의 온도차, 관계의 막힌 지점, 앞으로의 행동을 봅니다.",
    positions: ["나의 마음/태도", "상대의 마음/태도", "관계의 현재 상태", "관계의 막힌 지점", "흐름과 조언"],
    note: "'상대의 마음' 카드는 확정된 사실이 아니라 카드가 비추는 경향으로 다뤄라. 나와 상대 카드를 대비시켜 온도차와 역학을 짚고, 장애물 카드는 누구의 잘못이 아니라 관계 구조의 과제로 해석해라. 마지막 조언 카드는 관계에서 사용자가 실제로 할 수 있는 행동으로 번역해라. 이별/재회/결혼을 단정하지 마라.",
  },
  celtic: {
    id: "celtic",
    label: "깊은 정밀 리딩",
    shortLabel: "정밀 10장",
    desc: "중요한 고민을 여러 층위로 깊게 봅니다. 시간이 조금 더 걸릴 수 있어요.",
    positions: [
      "현재 상황",
      "가로막는 것/교차하는 힘",
      "뿌리/무의식의 바탕",
      "지나가는 과거",
      "의식적인 목표/드러난 것",
      "가까운 미래",
      "나 자신의 태도",
      "주변 환경/타인의 영향",
      "희망과 두려움",
      "최종 전개",
    ],
  },
};

export const SPREAD_IDS = Object.keys(SPREADS) as SpreadId[];

export const SHUFFLES: Record<ShuffleId, { label: string; desc: string; note: string }> = {
  classic: {
    label: "기본 셔플",
    desc: "전체 덱을 고르게 섞어 뽑아요",
    note: "기본 셔플: 덱 전체를 고르게 섞은 뒤 순서대로 뽑은 카드입니다.",
  },
  cut: {
    label: "컷 셔플",
    desc: "덱을 나누고 다시 합쳐 흐름을 봐요",
    note: "컷 셔플: 덱을 몇 번 나누고 다시 합친 뒤 뽑은 카드입니다. 흐름의 전환과 분기점을 함께 봅니다.",
  },
  riffle: {
    label: "리플 셔플",
    desc: "두 묶음이 섞이는 관계 흐름에 좋아요",
    note: "리플 셔플: 두 묶음의 카드가 서로 섞이도록 뽑은 카드입니다. 서로 다른 조건이나 사람의 영향이 섞이는 질문에 맞춰 봅니다.",
  },
  intuitive: {
    label: "손끝으로 고르기",
    desc: "펼친 카드 중 끌리는 카드를 고르는 느낌",
    note: "손끝으로 고르기: 펼친 덱에서 끌리는 카드를 집듯이 간격을 두고 뽑은 카드입니다. 질문자의 직감과 현재 마음의 초점을 함께 봅니다.",
  },
};

export const SHUFFLE_IDS = Object.keys(SHUFFLES) as ShuffleId[];

function randomShuffle<T>(items: T[]): T[] {
  const next = [...items];
  for (let i = next.length - 1; i > 0; i -= 1) {
    const j = Math.floor(Math.random() * (i + 1));
    [next[i], next[j]] = [next[j], next[i]];
  }
  return next;
}

function cutShuffle<T>(items: T[]): T[] {
  let next = randomShuffle(items);
  for (let i = 0; i < 3; i += 1) {
    const cut = 8 + Math.floor(Math.random() * (next.length - 16));
    next = [...next.slice(cut), ...next.slice(0, cut)];
  }
  return next;
}

function riffleShuffle<T>(items: T[]): T[] {
  const deck = randomShuffle(items);
  const middle = Math.floor(deck.length / 2) + Math.floor(Math.random() * 7) - 3;
  const left = deck.slice(0, middle);
  const right = deck.slice(middle);
  const result: T[] = [];

  while (left.length || right.length) {
    const takeLeft = !right.length || (left.length > 0 && Math.random() < 0.52);
    const source = takeLeft ? left : right;
    const count = Math.min(source.length, 1 + Math.floor(Math.random() * 3));
    result.push(...source.splice(0, count));
  }

  return result;
}

function intuitivePick<T>(items: T[], count: number): T[] {
  const deck = randomShuffle(items);
  const picked: T[] = [];
  const used = new Set<number>();
  let cursor = Math.floor(Math.random() * deck.length);

  while (picked.length < count && used.size < deck.length) {
    cursor = (cursor + 3 + Math.floor(Math.random() * 11)) % deck.length;
    if (used.has(cursor)) continue;
    used.add(cursor);
    picked.push(deck[cursor]);
  }

  return picked;
}

function cardsForShuffle(shuffleId: ShuffleId, count: number) {
  if (shuffleId === "intuitive") return intuitivePick(TAROT_DECK, count);
  if (shuffleId === "cut") return cutShuffle(TAROT_DECK).slice(0, count);
  if (shuffleId === "riffle") return riffleShuffle(TAROT_DECK).slice(0, count);
  return randomShuffle(TAROT_DECK).slice(0, count);
}

function cardsFromPickedSlots(shuffleId: ShuffleId, pickedSlots: number[], count: number) {
  const deck =
    shuffleId === "cut"
      ? cutShuffle(TAROT_DECK)
      : shuffleId === "riffle"
        ? riffleShuffle(TAROT_DECK)
        : randomShuffle(TAROT_DECK);
  const used = new Set<number>();
  const cards = pickedSlots
    .map((slot) => Math.abs(slot) % deck.length)
    .filter((slot) => {
      if (used.has(slot)) return false;
      used.add(slot);
      return true;
    })
    .map((slot) => deck[slot]);

  if (cards.length >= count) return cards.slice(0, count);

  for (const card of deck) {
    if (cards.includes(card)) continue;
    cards.push(card);
    if (cards.length >= count) break;
  }

  return cards;
}

/** 스프레드의 카드 수만큼 중복 없이 무작위로 뽑고, 각 카드는 50% 확률로 역방향이 된다 */
export function drawSpread(spreadId: SpreadId, shuffleId: ShuffleId = "classic", pickedSlots: number[] = []): DrawnTarotCard[] {
  const spread = SPREADS[spreadId];
  const count = spread.positions.length;
  const cards = pickedSlots.length ? cardsFromPickedSlots(shuffleId, pickedSlots, count) : cardsForShuffle(shuffleId, count);
  return cards.map((card, index) => ({
    card,
    reversed: Math.random() < 0.5,
    position: index + 1,
    positionLabel: spread.positions[index],
  }));
}
