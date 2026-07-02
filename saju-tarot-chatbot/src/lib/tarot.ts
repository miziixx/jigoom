import { TAROT_DECK } from "../data/tarotDeck";
import type { DrawnTarotCard } from "../types";

export type SpreadId = "one" | "ppf" | "soa" | "five" | "ab" | "month" | "celtic";

export interface SpreadDefinition {
  id: SpreadId;
  label: string;
  /** 각 자리(포지션)의 의미 — 카드 조합 해석의 근거가 된다 */
  positions: string[];
  /** 이 배열만의 해석 방법 안내 (프롬프트에 전달) */
  note?: string;
}

export const SPREADS: Record<SpreadId, SpreadDefinition> = {
  one: {
    id: "one",
    label: "1장 (오늘의 카드)",
    positions: ["핵심 메시지"],
  },
  ppf: {
    id: "ppf",
    label: "3장 (과거·현재·미래)",
    positions: ["과거/원인", "현재 상황", "가까운 흐름"],
  },
  soa: {
    id: "soa",
    label: "3장 (상황·장애물·조언)",
    positions: ["현재 상황", "장애물/과제", "조언"],
    note: "장애물 카드가 나쁜 카드가 아니라 '풀어야 할 과제'라는 관점으로 읽고, 조언 카드를 현실 행동으로 번역하는 데 비중을 둬라.",
  },
  five: {
    id: "five",
    label: "5장 (상황·장애물·조언·주변·전개)",
    positions: ["현재 상황", "장애물/과제", "조언", "주변/환경의 흐름", "가능성 높은 전개"],
  },
  ab: {
    id: "ab",
    label: "5장 (선택지 A/B 비교)",
    positions: ["현재 상황 (공통)", "A를 고르면 — 흐름", "A를 고르면 — 예상 전개", "B를 고르면 — 흐름", "B를 고르면 — 예상 전개"],
    note: "질문에서 선택지 A와 B가 각각 무엇인지 먼저 정리한 뒤, A열(2·3번)과 B열(4·5번)을 나란히 비교해라. 어느 쪽이 '어떤 조건에서, 어떤 사람에게' 유리한지로 결론을 내고, 한쪽을 단정적으로 강요하지 마라. 질문에 선택지가 명확히 없으면 사용자에게 A/B가 무엇인지 되물어라.",
  },
  month: {
    id: "month",
    label: "5장 (한 달 흐름)",
    positions: ["이번 달 전체 기조", "1주차", "2주차", "3주차", "4주차"],
    note: "전체 기조 카드를 축으로 주차별 카드를 연결해, 한 달의 리듬(시작-전개-조심할 구간-마무리)으로 해석해라. 주차별로 '이 주에 하면 좋은 것 1가지'를 붙여라.",
  },
  celtic: {
    id: "celtic",
    label: "10장 (켈틱 크로스)",
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

/** 스프레드의 카드 수만큼 중복 없이 무작위로 뽑고, 각 카드는 50% 확률로 역방향이 된다 */
export function drawSpread(spreadId: SpreadId): DrawnTarotCard[] {
  const spread = SPREADS[spreadId];
  const shuffled = [...TAROT_DECK].sort(() => Math.random() - 0.5);
  return shuffled.slice(0, spread.positions.length).map((card, index) => ({
    card,
    reversed: Math.random() < 0.5,
    position: index + 1,
    positionLabel: spread.positions[index],
  }));
}
