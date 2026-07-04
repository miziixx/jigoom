import { describe, expect, it } from "vitest";
import { computeLuckCycles, computeSajuChart } from "./saju.js";
import { buildReadingMarkdown } from "./exportMarkdown.js";
import type { BirthInfo, ReadingSession } from "../types/index.js";

describe("buildReadingMarkdown", () => {
  it("차별화 리포트 섹션을 저장 파일에 포함한다", () => {
    const birth: BirthInfo = { calendarType: "solar", year: 1990, month: 12, day: 23, hour: 8, minute: 0, gender: "female" };
    const session: ReadingSession = {
      id: "md1",
      type: "saju",
      createdAt: "2026-07-03T03:00:00.000Z",
      question: "올해 흐름",
      birthInfo: birth,
      sajuChart: computeSajuChart(birth),
      luckCycles: computeLuckCycles(birth, new Date("2026-07-03T03:00:00Z"), { includeMonthlyFlow: true }),
      messages: [
        { role: "user", content: "질문" },
        { role: "assistant", content: "# 첫 점괘\n흐름을 정리하세요." },
      ],
    };

    const markdown = buildReadingMarkdown(session);

    expect(markdown).toContain("## 내 반복 패턴 지도");
    expect(markdown).toContain("## 월별 실행 캘린더");
    expect(markdown).toContain("흐름을 정리하세요.");
  });
});
