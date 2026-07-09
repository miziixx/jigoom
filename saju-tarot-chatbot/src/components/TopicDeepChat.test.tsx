import { describe, expect, it } from "vitest";
import { renderToStaticMarkup } from "react-dom/server";
import TopicDeepChat from "./TopicDeepChat";

const FULL_TEXT =
  "# 한 줄 결론\n올해 연애는 기다리기보다 고르는 쪽이에요.\n\n" +
  "# 지금 흐름\n관계 자리가 움직이기 시작했어요.\n\n" +
  "# 조심할 것\n속도가 빠른 끌림은 한 번 더 확인하세요.\n\n" +
  "# 시기\n가을 무렵 신호가 더 뚜렷해질 수 있어요.\n\n" +
  "# 행동\n먼저 연락해보고, 대화 패턴을 기록해보세요.";

describe("TopicDeepChat (토픽 심화 말풍선 점진 공개, A-3·시안 ②)", () => {
  it("완성된 텍스트는 5개 섹션을 모두 말풍선으로, 타이핑 인디케이터 없이 보여준다", () => {
    const html = renderToStaticMarkup(<TopicDeepChat topic="love" text={FULL_TEXT} loading={false} error={null} />);
    for (const tag of ["한 줄 결론", "지금 흐름", "조심할 것", "시기", "행동"]) {
      expect(html).toContain(tag);
    }
    expect(html).toContain("완료");
    expect(html).not.toContain("topic-deep-bubble--typing");
  });

  it("스트리밍 도중(섹션 일부만 도착)에는 도착한 만큼만 보여주고 타이핑 인디케이터를 더한다", () => {
    const partial = "# 한 줄 결론\n올해 연애는 기다리기보다 고르는 쪽이에요.\n\n# 지금 흐름\n관계 자리가 움직이";
    const html = renderToStaticMarkup(<TopicDeepChat topic="love" text={partial} loading={true} error={null} />);
    expect(html).toContain("한 줄 결론");
    expect(html).toContain("지금 흐름");
    expect(html).not.toContain("조심할 것");
    expect(html).toContain("생성 중");
    expect(html).toContain("topic-deep-bubble--typing");
  });

  it("텍스트가 아직 하나도 없으면 타이핑 인디케이터만 보여준다", () => {
    const html = renderToStaticMarkup(<TopicDeepChat topic="money" text="" loading={true} error={null} />);
    expect(html).toContain("topic-deep-bubble--typing");
    expect(html).not.toContain("한 줄 결론");
  });

  it("5개 섹션이 다 도착하면 loading이어도 타이핑 인디케이터를 더 보여주지 않는다", () => {
    const html = renderToStaticMarkup(<TopicDeepChat topic="career" text={FULL_TEXT} loading={true} error={null} />);
    expect(html).not.toContain("topic-deep-bubble--typing");
  });

  it("에러가 있으면 에러 문구를 보여준다", () => {
    const html = renderToStaticMarkup(<TopicDeepChat topic="health" text="" loading={false} error="네트워크 오류" />);
    expect(html).toContain("네트워크 오류");
  });

  it("토픽 라벨(한국어)이 제목에 들어간다", () => {
    const html = renderToStaticMarkup(<TopicDeepChat topic="year" text="" loading={false} error={null} />);
    expect(html).toContain("올해운 심화");
  });
});
