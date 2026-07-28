import { describe, expect, it } from "vitest";
import { renderToStaticMarkup } from "react-dom/server";
import ReportProgress from "./ReportProgress";

describe("ReportProgress (리포트 진행 화면, B-3·시안 ③)", () => {
  it("아직 아무 섹션도 도착하지 않았으면 전부 대기 상태로 보여준다", () => {
    const html = renderToStaticMarkup(
      <ReportProgress type="saju" hasQuestion={false} replyText="" depth="advanced" loading={true} />,
    );
    expect(html).toContain("리포트를 정성껏 뽑는 중이에요");
    expect(html).toContain("14개 섹션 중 0개 도착");
    expect(html).toContain("대기");
    expect(html).not.toContain("읽기 ›");
  });

  it("도착한 섹션은 앵커 링크(읽기 ›)로, 마지막 도착분은 쓰는 중으로 보여준다", () => {
    const reply = ["# 첫 점괘", "...", "", "# 분야별 요약", "..."].join("\n");
    const html = renderToStaticMarkup(
      <ReportProgress type="saju" hasQuestion={false} replyText={reply} loading={true} />,
    );
    expect(html).toContain('href="#reading-첫-점괘"');
    expect(html).toContain("읽기 ›");
    expect(html).toContain("쓰는 중…");
    expect(html).toContain("첫 점괘부터 읽기 시작 →");
  });

  it("스트림이 끝나면(loading=false) 마지막으로 도착한 섹션도 완료로 바뀐다", () => {
    const reply = ["# 첫 점괘", "..."].join("\n");
    const streaming = renderToStaticMarkup(
      <ReportProgress type="saju" hasQuestion={false} replyText={reply} loading={true} />,
    );
    const done = renderToStaticMarkup(
      <ReportProgress type="saju" hasQuestion={false} replyText={reply} loading={false} />,
    );
    expect(streaming).toContain("쓰는 중…");
    expect(done).not.toContain("쓰는 중…");
    expect(done).toContain("읽기 ›");
  });

  it("모든 섹션이 도착하면 스스로 접힌다(null)", () => {
    const reply = [
      "# 첫 점괘",
      "# 분야별 요약",
      "# 타고난 성격과 기질",
      "# 직업과 돈",
      "# 재물 흐름",
      "# 애정과 관계",
      "# 건강과 컨디션",
      "# 인생의 큰 흐름",
      "# 올해의 흐름",
      "# 지금 해야 할 것과 피해야 할 것",
      "# 마지막 점괘",
    ].join("\n\n");
    const html = renderToStaticMarkup(
      <ReportProgress type="saju" hasQuestion={false} replyText={reply} loading={false} />,
    );
    expect(html).toBe("");
  });

  it("advanced 깊이면 고급 전용 섹션도 목차에 나온다", () => {
    const html = renderToStaticMarkup(
      <ReportProgress type="saju" hasQuestion={false} replyText="" depth="advanced" loading={true} />,
    );
    expect(html).toContain("반복 패턴 정밀 진단");
    expect(html).toContain("선택과 시기 판단");
    expect(html).toContain("3개월 실행 전략");
  });
});
