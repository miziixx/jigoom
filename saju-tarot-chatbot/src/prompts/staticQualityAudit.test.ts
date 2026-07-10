import { describe, expect, it } from "vitest";
import { buildReadingUserMessage } from "./systemPrompt.js";
import { TAROT_DECK } from "../data/tarotDeck.js";
import { computeLuckCycles, computeSajuChart } from "../lib/saju.js";
import type { BirthInfo, DrawnTarotCard, TarotCardDefinition } from "../types/index.js";

function card(id: number): TarotCardDefinition {
  const found = TAROT_DECK.find((c) => c.id === id);
  if (!found) throw new Error(`Missing tarot card id ${id}`);
  return found;
}

function drawn(ids: number[]): DrawnTarotCard[] {
  return ids.map((id, index) => ({
    card: card(id),
    reversed: false,
    position: index + 1,
    positionLabel: ["현재", "막히는 지점", "조언", "가까운 흐름", "최종 전개"][index] ?? `${index + 1}번째`,
  }));
}

const birth: BirthInfo = {
  calendarType: "solar",
  year: 1972,
  month: 1,
  day: 30,
  hour: 6,
  minute: 0,
  gender: "male",
};

function advancedSajuMessage() {
  const sajuChart = computeSajuChart(birth);
  const luckCycles = computeLuckCycles(birth, new Date("2026-07-03T03:00:00Z"), {
    yongElements: sajuChart.yongshin?.supportive,
    avoidElements: sajuChart.yongshin?.unfavorable,
  });
  return buildReadingUserMessage({
    type: "saju",
    question: "올해 일과 돈 흐름이 궁금해요",
    gender: birth.gender,
    sajuChart,
    luckCycles,
    context: { depth: "advanced" },
  });
}

describe("정적 리딩 품질 감사 — 고급 사주 앵커", () => {
  it("고급 리딩은 상세 원자료를 받되 JudgmentPack 앵커로 결론 방향을 고정한다", () => {
    const msg = advancedSajuMessage();

    expect(msg).toContain("[검증된 판단 — JudgmentPack 앵커]");
    expect(msg).toContain("원자료로 더 깊고 촘촘하게 해석하되");
    expect(msg).toContain("결론 자체를 뒤집는 데 쓰지 마라");
    expect(msg).toContain("[상세 계산 근거 — 사주 원국]");
    expect(msg).toContain("[상세 계산 근거 — 대운/세운/월운/일진]");
    expect(msg).toContain("[분야별 사건 신호 — 계산됨]");
    expect(msg).not.toContain("[JudgmentPack — 계산됨]");
  });

  it("고급 리딩도 금지 표현과 고위험 결론 금지 레일을 함께 받는다", () => {
    const msg = advancedSajuMessage();

    expect(msg).toContain("공통 금지 표현");
    expect(msg).toContain("지금 퇴사하세요|회사를 그만두세요");
    expect(msg).toContain("큰돈을 벌게 됩니다|투자하세요");
    expect(msg).toContain("반드시 결혼합니다|무조건 재회");
    expect(msg).toContain("암입니다|질병입니다|병에 걸립니다");
  });
});

describe("정적 리딩 품질 감사 — 강한 타로 조합 안전장치", () => {
  it("죽음+탑+소드10 조합은 공포 예언이 아니라 참고용 전환 신호와 행동 조언 재료로 전달된다", () => {
    const msg = buildReadingUserMessage({
      type: "tarot",
      question: "이 일을 계속 붙잡아도 될까요?",
      tarotCards: drawn([13, 16, 59]),
    });

    expect(msg).toContain("타로 리딩 — 질문 집중");
    expect(msg).toContain("카드 조합 신호(참고용)");
    expect(msg).toContain("죽음+탑");
    expect(msg).toContain("한 국면이 끝나고 판이 크게 바뀌는 강한 전환");
    expect(msg).toContain("탑+소드 10");
    expect(msg).toContain("바닥은 새 시작의 전조");
    expect(msg).toContain("단정하지 말고 선택 기준으로 제시");
    expect(msg).toContain("# 지금 해야 할 것과 피해야 할 것");
  });

  it("소드3+소드9 같은 불안 조합도 상처·걱정을 단정하지 않고 행동으로 풀 재료를 준다", () => {
    const msg = buildReadingUserMessage({
      type: "tarot",
      question: "상대 마음 때문에 불안해요",
      tarotCards: drawn([52, 58, 55]),
    });

    expect(msg).toContain("소드 3+소드 9");
    expect(msg).toContain("번민이 깊어지기 쉬운 편");
    expect(msg).toContain("현실 장면");
    expect(msg).toContain("그늘/조심");
    expect(msg).toContain("조언");
    expect(msg).toContain("고위험 판단");
  });

  it("타로 고급도 사주 생애 섹션을 만들지 말고 카드 근거에만 머물도록 제한한다", () => {
    const msg = buildReadingUserMessage({
      type: "tarot",
      question: "이직할지 남을지 고민돼요",
      tarotCards: drawn([1, 50, 64, 66, 11]),
      context: { depth: "advanced" },
    });

    expect(msg).toContain("타로 고급 — 더 깊게, 여전히 카드에만 근거");
    expect(msg).toContain("사주 원국이 없으므로 생애 전반·연간 운세·월별 흐름 같은 사주 섹션은 여전히 만들지 마라");
    expect(msg).toContain("# 흐름을 가르는 지점");
    expect(msg).not.toContain("상세 계산 근거 — 사주 원국");
  });
});

describe("정적 리딩 품질 감사 — 토픽 심화 domain 제한", () => {
  it.each([
    ["love", "연애운"],
    ["money", "재물운"],
    ["career", "직업운"],
    ["health", "건강운"],
    ["year", "올해운"],
  ] as const)("topicDeep %s는 해당 domain 판단만 쓰도록 제한한다", (topic, label) => {
    const sajuChart = computeSajuChart(birth);
    const luckCycles = computeLuckCycles(birth, new Date("2026-07-03T03:00:00Z"), {
      yongElements: sajuChart.yongshin?.supportive,
      avoidElements: sajuChart.yongshin?.unfavorable,
    });
    const msg = buildReadingUserMessage({
      type: "saju",
      question: "자세히 보고 싶어요",
      gender: birth.gender,
      sajuChart,
      luckCycles,
      context: { analysisMode: "topicDeep", topic },
    });

    expect(msg).toContain(`[토픽 심화 — ${label}`);
    expect(msg).toContain(`domain이 "${topic}"인 항목만 근거로 쓴다`);
    expect(msg).toContain("다른 domain");
    expect(msg).toContain("새 판단을 만들지 않는다");
    expect(msg).toContain("# 한 줄 결론\n# 지금 흐름\n# 조심할 것\n# 시기\n# 행동");
    expect(msg).not.toContain("평생사주 기본 리포트");
  });
});
