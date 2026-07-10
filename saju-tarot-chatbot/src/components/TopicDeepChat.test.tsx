import { describe, expect, it } from "vitest";
import { renderToStaticMarkup } from "react-dom/server";
import TopicDeepChat from "./TopicDeepChat";
import { computeSajuChart, computeLuckCycles } from "../lib/saju.js";
import type { BirthInfo } from "../types";

const birth: BirthInfo = { calendarType: "solar", year: 1990, month: 12, day: 23, hour: 8, minute: 0, gender: "female" };
const chart = computeSajuChart(birth);
const luck = computeLuckCycles(birth, new Date("2026-07-03T03:00:00Z"));

/**
 * TopicDeepChat은 마운트 시 useEffect로 첫 요청을 스스로 시작한다(후속 질문 상태까지 로컬로
 * 관리하기 위한 설계, BasicReadingSection.tsx 참고). renderToStaticMarkup은 effect를 실행하지
 * 않으므로(React SSR 규칙) 여기서 확인 가능한 건 "요청 시작 전 초기 렌더"뿐이다 — 요청 이후
 * 상태(말풍선 도착·후속 질문 UI)는 Playwright 브라우저 검증으로 확인한다.
 */
describe("TopicDeepChat (토픽 심화 + 후속 질문, A-3·토픽 템플릿 확장)", () => {
  it("초기 렌더에서는 생성 중 배지와 타이핑 인디케이터만 보여준다(아직 요청 전)", () => {
    const html = renderToStaticMarkup(
      <TopicDeepChat topic="love" sajuChart={chart} luckCycles={luck} gender="female" type="saju" />,
    );
    expect(html).toContain("연애운 심화");
    expect(html).toContain("생성 중");
    expect(html).toContain("topic-deep-bubble--typing");
    expect(html).not.toContain("이어서 질문");
    expect(html).not.toContain("chat-input-row");
  });

  it("토픽 라벨(한국어)이 5개 모두 올바르다", () => {
    const cases: [string, string][] = [
      ["love", "연애운"],
      ["money", "재물운"],
      ["career", "직업운"],
      ["health", "건강운"],
      ["year", "올해운"],
    ];
    for (const [topic, label] of cases) {
      const html = renderToStaticMarkup(
        // @ts-expect-error 테스트용 리터럴 순회
        <TopicDeepChat topic={topic} sajuChart={chart} luckCycles={luck} gender="female" type="saju" />,
      );
      expect(html).toContain(`${label} 심화`);
    }
  });
});
