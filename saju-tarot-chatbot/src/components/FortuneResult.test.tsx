import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import FortuneResult from "./FortuneResult.js";
import { computeFortuneEvidence } from "../lib/fortune.js";
import { buildFallbackFortune } from "../lib/fortuneFallback.js";
import type { BirthInfo, FortuneResult as FortuneResultType } from "../types/index.js";

function makeResult(birth: BirthInfo): FortuneResultType {
  const evidence = computeFortuneEvidence(birth, new Date("2026-07-03T03:00:00Z"));
  return { evidence, content: buildFallbackFortune(evidence), source: "fallback", createdAt: "2026-07-03T03:00:00.000Z" };
}

describe("FortuneResult 렌더링", () => {
  it("근거·점수·행운·상세 근거를 크래시 없이 그린다", () => {
    const html = renderToStaticMarkup(
      <FortuneResult result={makeResult({ calendarType: "solar", year: 1990, month: 12, day: 23, hour: 8, minute: 0, gender: "female" })} />,
    );
    const evidence = computeFortuneEvidence(
      { calendarType: "solar", year: 1990, month: 12, day: 23, hour: 8, minute: 0, gender: "female" },
      new Date("2026-07-03T03:00:00Z"),
    );
    const content = buildFallbackFortune(evidence);

    // 상단 헤더
    expect(html).toContain("2026-07-03");
    expect(html).toContain("일진 무인");
    // 게이지 6종
    for (const label of ["총운", "재물", "애정", "직장·학업", "건강", "대인관계"]) {
      expect(html).toContain(label);
    }
    // 전체 운세 문단 + 분야별 카드
    expect(html).toContain("오늘의 총운");
    expect(html).toContain(content.overall);
    expect(html).toContain("분야별 운세");
    for (const c of Object.values(content.categories)) {
      expect(html).toContain(c.comment);
    }
    // good_areas/caution_points 없이 카드 태그로만 good/caution 표시
    expect(html).not.toContain("잘 풀리는 영역");
    expect(html).not.toContain("오늘 체크할 포인트");
    // 행운 아이템 / 상세 근거 / 고지
    expect(html).toContain("오늘의 행운");
    expect(html).toContain("왜 이런 운세인가요?");
    expect(html).toContain("십성");
    expect(html).toContain("엔터테인먼트");
  });

  it("출생 시간을 몰라도(시주 제외) 렌더링된다", () => {
    const html = renderToStaticMarkup(
      <FortuneResult result={makeResult({ calendarType: "solar", year: 2001, month: 7, day: 7, hour: null, gender: "female" })} />,
    );
    expect(html).toContain("시주 제외");
    expect(html).toContain("분야별 운세");
  });
});
