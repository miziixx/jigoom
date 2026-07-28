import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import EvidenceConfidence from "./EvidenceConfidence.js";
import { computeLuckCycles, computeSajuChart } from "../lib/saju.js";
import type { BirthInfo, DrawnTarotCard, ReadingSession, TarotCardDefinition } from "../types/index.js";

const BASE_SESSION = {
  id: "t1",
  createdAt: "2026-07-05T03:00:00.000Z",
  question: "요즘 어떤가요",
  messages: [
    { role: "user" as const, content: "..." },
    { role: "assistant" as const, content: "..." },
  ],
};

function makeCard(id: number): TarotCardDefinition {
  return { id, name: `카드${id}`, arcana: "major", uprightMeaning: "-", reversedMeaning: "-" };
}

function drawnCards(count: number): DrawnTarotCard[] {
  return Array.from({ length: count }, (_, i) => ({ card: makeCard(i), reversed: false, position: i + 1 }));
}

describe("EvidenceConfidence", () => {
  it("카드 1장뿐인 타로 리딩은 참고 중심 등급이고 조사가 '카드를'로 붙는다", () => {
    const session: ReadingSession = { ...BASE_SESSION, type: "tarot", tarotCards: drawnCards(1) };
    const html = renderToStaticMarkup(<EvidenceConfidence session={session} />);
    expect(html).toContain("참고 중심");
    expect(html).toContain("카드를 바탕으로 해석합니다");
  });

  it("카드 수가 많은 스프레드일수록 신뢰도 점수가 올라간다", () => {
    const small: ReadingSession = { ...BASE_SESSION, type: "tarot", tarotCards: drawnCards(3) };
    const large: ReadingSession = { ...BASE_SESSION, type: "tarot", tarotCards: drawnCards(10) };
    const smallHtml = renderToStaticMarkup(<EvidenceConfidence session={small} />);
    const largeHtml = renderToStaticMarkup(<EvidenceConfidence session={large} />);
    const widthOf = (html: string) => Number(/width:\s*([\d.]+)%/.exec(html)?.[1]);
    expect(widthOf(largeHtml)).toBeGreaterThan(widthOf(smallHtml));
    expect(largeHtml).toContain("근거 보통");
  });

  it("사주 계산값과 대운·세운 흐름이 모두 있으면 근거 충분 등급이다", () => {
    const birthInfo: BirthInfo = { year: 1990, month: 5, day: 12, hour: 10, minute: 0, gender: "female", calendarType: "solar", isLeapMonth: false };
    const sajuChart = computeSajuChart(birthInfo);
    const luckCycles = computeLuckCycles(birthInfo, new Date("2026-07-05"));
    const session: ReadingSession = {
      ...BASE_SESSION,
      type: "combo",
      birthInfo,
      sajuChart,
      luckCycles,
      tarotCards: drawnCards(3),
    };
    const html = renderToStaticMarkup(<EvidenceConfidence session={session} />);
    expect(html).toContain("근거 충분");
    expect(html).toContain("사주 원국 계산값 · 대운·세운·월운 흐름 · 3장 스프레드 · 출생 시간을 바탕으로 해석합니다");
  });
});
