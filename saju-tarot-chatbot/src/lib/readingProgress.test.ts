import { describe, expect, it } from "vitest";
import { buildReadingProgress } from "./readingProgress.js";

describe("리딩 진행률 계산", () => {
  it("아직 아무 섹션도 없으면 0%", () => {
    const p = buildReadingProgress("saju", false, "");
    expect(p.completed).toBe(0);
    expect(p.percent).toBe(0);
    expect(p.currentTitle).toBe("첫 점괘");
  });

  it("saju: 중간까지 등장하면 그만큼 진행률이 오른다", () => {
    const reply = ["# 첫 점괘", "지금은 정리할 때입니다.", "", "# 분야별 요약", "- 직업·재물: 평가 보통 — ..."].join("\n");
    const p = buildReadingProgress("saju", false, reply);
    expect(p.completed).toBe(2);
    expect(p.total).toBe(11);
    expect(p.currentTitle).toBe("타고난 성격과 기질");
  });

  it("질문이 있으면 질문 중심 핵심을 목록에 끼워 넣는다", () => {
    const reply = ["# 첫 점괘", "...", "", "# 질문 중심 핵심", "..."].join("\n");
    const p = buildReadingProgress("saju", true, reply);
    expect(p.completed).toBe(2);
    expect(p.currentTitle).toBe("분야별 요약");
  });

  it("조건부 섹션이 스킵돼도 뒤 섹션이 나오면 진행률이 따라간다", () => {
    const reply = ["# 첫 점괘", "...", "", "# 분야별 요약", "..."].join("\n");
    const p = buildReadingProgress("saju", true, reply);
    // '질문 중심 핵심'은 안 나왔지만 '분야별 요약'(질문 포함 목록에서 index 2)까지는 나온 것으로 본다
    expect(p.completed).toBe(3);
  });

  it("모든 섹션이 등장하면 100%, currentTitle은 null", () => {
    const reply = ["# 첫 점괘", "# 카드가 그리는 흐름", "# 지금 해야 할 것과 피해야 할 것", "# 마지막 점괘"].join("\n");
    const p = buildReadingProgress("tarot", false, reply);
    expect(p.percent).toBe(100);
    expect(p.currentTitle).toBeNull();
  });

  it("today 타입은 헤더에 괄호가 붙어도 접두어 일치로 감지한다", () => {
    const reply = ["# 첫 점괘", "# 올해의 흐름 (오늘·이번 주 중심)", "여기까지"].join("\n");
    const p = buildReadingProgress("today", false, reply);
    expect(p.completed).toBe(2);
    expect(p.currentTitle).toBe("지금 해야 할 것과 피해야 할 것");
  });
});
