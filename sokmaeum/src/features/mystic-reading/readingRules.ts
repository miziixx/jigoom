import type { ConcernCategory, ReadingInterest } from "../../types";

/** 관심사 선택값 → 어떤 섹션·고민 카테고리를 강조할지 규칙 */
export interface InterestWeighting {
  /** 말하지 않은 고민 후보에서 비중을 높일 카테고리 (앞쪽일수록 우선) */
  emphasizeConcerns: ConcernCategory[];
  /** 강조 섹션 키 */
  emphasizeSections: Array<"workAndMoney" | "relationshipReading" | "yearlyTurningPoints" | "currentState">;
  /** LLM 프롬프트에 넣을 한 줄 지시 */
  promptHint: string;
}

export const INTEREST_WEIGHTING: Record<ReadingInterest, InterestWeighting> = {
  work: {
    emphasizeConcerns: ["work", "money", "future", "selfWorth"],
    emphasizeSections: ["workAndMoney", "yearlyTurningPoints"],
    promptHint: "일/직업 고민이 중심이다. 돈과 일 리딩, 반복되는 일 패턴, 올해 일이 바뀌기 쉬운 시기를 특히 구체적으로 다뤄라.",
  },
  money: {
    emphasizeConcerns: ["money", "work", "future"],
    emphasizeSections: ["workAndMoney", "yearlyTurningPoints"],
    promptHint: "돈/재물 고민이 중심이다. 돈이 붙는 방식과 새는 구멍, 재물 관련 월운을 특히 구체적으로 다뤄라.",
  },
  love: {
    emphasizeConcerns: ["relationship", "emotion", "selfWorth"],
    emphasizeSections: ["relationshipReading", "currentState"],
    promptHint: "연애 고민이 중심이다. 관계에서 기대·상처·마음 닫는 순간, 다가가기 좋은/물러설 시기를 특히 구체적으로 다뤄라.",
  },
  marriage: {
    emphasizeConcerns: ["relationship", "future", "emotion"],
    emphasizeSections: ["relationshipReading", "yearlyTurningPoints"],
    promptHint: "결혼·장기 관계 고민이 중심이다. 관계의 숨은 권력구도와 반복되는 오해, 전환 가능 시기를 다루되 단정하지 마라.",
  },
  relationship: {
    emphasizeConcerns: ["relationship", "emotion", "selfWorth"],
    emphasizeSections: ["relationshipReading", "currentState"],
    promptHint: "인간관계 고민이 중심이다. 관계에서 반복되는 패턴과 거리 두는 방식을 현실 장면처럼 풀어라.",
  },
  family: {
    emphasizeConcerns: ["relationship", "emotion", "selfWorth"],
    emphasizeSections: ["relationshipReading", "currentState"],
    promptHint: "가족 관계 고민이 중심이다. 과거 감정의 영향과 반복되는 패턴을 조심스럽게 다뤄라.",
  },
  health: {
    emphasizeConcerns: ["health", "emotion", "future"],
    emphasizeSections: ["currentState"],
    promptHint: "건강/컨디션 고민이 중심이다. 몸과 마음의 흐름, 에너지가 새는 지점을 특히 구체적으로 다뤄라.",
  },
  future: {
    emphasizeConcerns: ["future", "selfWorth", "work"],
    emphasizeSections: ["currentState", "yearlyTurningPoints"],
    promptHint: "미래 불안이 중심이다. 지금 상태와 올해 전환점, 지금 해야 할/피해야 할 선택을 특히 구체적으로 다뤄라.",
  },
  selfWorth: {
    emphasizeConcerns: ["selfWorth", "emotion", "relationship"],
    emphasizeSections: ["currentState", "relationshipReading"],
    promptHint: "자존감 고민이 중심이다. 겉모습과 진짜 내면, 무너지는 지점을 현실 장면처럼 섬세하게 풀어라.",
  },
  all: {
    emphasizeConcerns: ["work", "money", "relationship", "emotion", "future"],
    emphasizeSections: ["currentState", "workAndMoney", "relationshipReading", "yearlyTurningPoints"],
    promptHint: "특정 주제로 좁히지 말고 전체를 균형 있게 다루되, 근거가 가장 강하게 가리키는 영역을 자연스럽게 앞세워라.",
  },
};

export const CONCERN_LABEL: Record<ConcernCategory, string> = {
  work: "일",
  money: "돈",
  relationship: "관계",
  health: "건강",
  emotion: "감정",
  future: "미래",
  selfWorth: "자존감",
};
