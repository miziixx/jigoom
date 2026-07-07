import { renderToStaticMarkup } from "react-dom/server";
import { MemoryRouter } from "react-router-dom";
import { describe, expect, it } from "vitest";
import ReadingResult from "../ReadingResult.js";
import { computeLuckCycles, computeSajuChart } from "../../lib/saju.js";
import { TAROT_DECK } from "../../data/tarotDeck.js";
import type { BirthInfo, DrawnTarotCard, ReadingSession, ReadingType } from "../../types/index.js";

const BIRTH: BirthInfo = {
  calendarType: "solar",
  year: 1992,
  month: 3,
  day: 15,
  hour: 10,
  minute: 0,
  gender: "female",
};

const MONTH_LINES = Array.from(
  { length: 12 },
  (_, i) => `${i + 1}월 | 키워드: 정리 | 기회: 계획 세우기 | 주의: 과로 | 조언: 우선순위 정하기`,
).join("\n");

const FLOW_REPLY = [
  "# 첫 점괘",
  "올해는 무리하게 넓히기보다 기반을 다지는 흐름입니다.",
  "",
  "# 분야별 요약",
  "- 직업·일: 평가 좋음 — 맡은 일이 성과로 이어져요.",
  "- 재물: 평가 보통 — 큰 지출만 조심하면 무난해요.",
  "",
  "# 올해의 흐름",
  "올해는 정리와 재정비의 해입니다.",
  MONTH_LINES,
  "",
  "# 지금 해야 할 것과 피해야 할 것",
  "[오늘 바로 할 수 있는 행동]",
  "- 지출 내역 정리하기",
  "",
  "# 마지막 점괘",
  "정리하면 다음 흐름이 열립니다.",
].join("\n");

function makeSession(type: ReadingType, reply: string, extra: Partial<ReadingSession> = {}): ReadingSession {
  return {
    id: `t-${type}`,
    type,
    createdAt: "2026-07-03T03:00:00.000Z",
    messages: [
      { role: "user", content: "..." },
      { role: "assistant", content: reply },
    ],
    ...extra,
  } as ReadingSession;
}

function render(session: ReadingSession) {
  return renderToStaticMarkup(
    <MemoryRouter>
      <ReadingResult session={session} />
    </MemoryRouter>,
  );
}

describe("리딩 타입별 템플릿 디스패처", () => {
  it("flow는 올해운세형 템플릿으로 렌더된다 (히어로·12개월 차트·월별 상세·CTA)", () => {
    const sajuChart = computeSajuChart(BIRTH);
    const luckCycles = computeLuckCycles(BIRTH, new Date(), { includeMonthlyFlow: true });
    const html = render(makeSession("flow", FLOW_REPLY, { birthInfo: BIRTH, sajuChart, luckCycles }));

    expect(html).toContain("올해운세");
    expect(html).toContain("yearly-hero");
    expect(html).toContain("1월~12월 흐름");
    expect(html).toContain("viz-flow"); // 12개월 곡선 차트
    expect(html).toContain("월별 상세");
    expect(html).toContain("지금 해야 할 것과 피해야 할 것");
    expect(html).toContain("reading-cta"); // 다음 리딩 CTA
    // 원국 스냅샷은 올해운세형에서도 항상 노출
    expect(html).toContain("내 사주 원국");
  });

  it("flow 스트리밍 초반(월별 형식 미완성)에도 깨지지 않고 폴백 렌더된다", () => {
    const partial = "# 첫 점괘\n올해는 기반을 다지는 흐름입니다.\n\n# 올해의 흐름\n올해는 정리의 해입니다. 1월";
    const html = render(makeSession("flow", partial, { birthInfo: BIRTH }));
    expect(html).toContain("yearly-hero");
    expect(html).toContain("올해의 흐름");
  });

  it("saju + 질문 있음 → 고민 상담 리딩 라벨 + 고민 파고들기 CTA", () => {
    const html = render(makeSession("saju", "# 첫 점괘\n방향을 잡을 때입니다.", { question: "이직해도 될까요?" }));
    expect(html).toContain("고민 상담 리딩");
    expect(html).not.toContain("평생사주 리포트");
    expect(html).toContain("이 고민, 더 파고들려면");
    expect(html).toContain('href="/combo"');
  });

  it("saju + 질문 없음 → 평생사주 리포트 라벨 + 심화 리포트 CTA", () => {
    const html = render(makeSession("saju", "# 첫 점괘\n차분히 쌓는 구조입니다."));
    expect(html).toContain("평생사주 리포트");
    expect(html).toContain("이어서 보면 좋은 리포트");
    expect(html).toContain("올해운세 자세히 보기");
  });

  it("평생사주형은 대운 인생 지도를 원국 아래에 승격하고 하단 패널에 중복하지 않는다", () => {
    const sajuChart = computeSajuChart(BIRTH);
    const luckCycles = computeLuckCycles(BIRTH, new Date(), { includeMonthlyFlow: true });
    const html = render(makeSession("saju", "# 첫 점괘\n차분히 쌓는 구조입니다.", { birthInfo: BIRTH, sajuChart, luckCycles }));
    expect(html).toContain("대운 인생 지도");
    expect(html).toContain("dayun-lifemap");
    // 승격 시 하단 기본 리포트의 대운 알약 타임라인(dayun-timeline)은 렌더하지 않는다
    expect(html).not.toContain("dayun-timeline");
    // 인생 지도는 한 번만
    expect(html.split("dayun-lifemap-card").length - 1).toBe(1);
  });

  it("AI 텍스트가 아직 없으면 CTA를 노출하지 않는다", () => {
    const html = render(makeSession("saju", ""));
    expect(html).not.toContain("이어서 보면 좋은 리포트");
  });

  it("tarot → 카드 근거 패널이 접힘 존 밖으로 승격된다", () => {
    const cards: DrawnTarotCard[] = [
      { position: 1, positionLabel: "현재", card: TAROT_DECK[0], reversed: false },
      { position: 2, positionLabel: "조언", card: TAROT_DECK[1], reversed: true },
    ];
    const html = render(makeSession("tarot", "# 첫 점괘\n흐름이 순방향이에요.", { tarotCards: cards }));
    expect(html).toContain("타로 카드 리딩");
    expect(html).toContain("tarot-facts-promoted");
    // 근거 존 내부 중복 렌더는 막는다 (뽑힌 카드와 근거 패널은 승격된 1곳만)
    expect(html.split("뽑힌 카드와 근거").length - 1).toBe(1);
  });
});
