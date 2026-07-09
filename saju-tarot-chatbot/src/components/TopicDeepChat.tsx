import { parseSections, stripMarkdown } from "../lib/readingText";
import type { TopicDeepTopic } from "../types";

export const TOPIC_LABEL: Record<TopicDeepTopic, string> = {
  love: "연애운",
  money: "재물운",
  career: "직업운",
  health: "건강운",
  year: "올해운",
};

/** systemPrompt.ts의 buildTopicDeepInstruction과 섹션 개수를 맞춘다 — 몇 개 도착했는지 판단하는 기준. */
const EXPECTED_SECTIONS = 5;

/**
 * 토픽 심화(topicDeep) 결과를 말풍선으로 점진 공개한다 (재기획안 A-3, 시안 ②).
 * "# 제목" 섹션이 스트리밍으로 도착하는 순서 그대로 말풍선을 쌓고, 아직 안 온 섹션 자리에는
 * 타이핑 인디케이터를 보여준다. 별도 폴링 없이 accumulated 텍스트를 그대로 다시 파싱하면 되므로
 * (parseSections는 매 렌더마다 결정론적으로 같은 결과를 낸다) 상태를 따로 추적하지 않는다.
 */
export default function TopicDeepChat({
  topic,
  text,
  loading,
  error,
}: {
  topic: TopicDeepTopic;
  text: string;
  loading: boolean;
  error: string | null;
}) {
  const sections = text.trim() ? parseSections(text) : [];
  const showTypingIndicator = loading && sections.length < EXPECTED_SECTIONS;

  return (
    <section className="card topic-deep-chat">
      <div className="section-heading-row">
        <h3 className="card-title">{TOPIC_LABEL[topic]} 심화</h3>
        <span className="feature-badge">{loading ? "생성 중" : "완료"}</span>
      </div>
      {error && <p className="error-text">{error}</p>}
      <div className="topic-deep-chat__list">
        {sections.map((section) => (
          <div className="topic-deep-msg" key={section.title}>
            <span className="topic-deep-avatar">🔮</span>
            <div className="topic-deep-bubble">
              <span className="topic-deep-bubble__tag">{section.title}</span>
              <p>{stripMarkdown(section.body)}</p>
            </div>
          </div>
        ))}
        {showTypingIndicator && (
          <div className="topic-deep-msg">
            <span className="topic-deep-avatar">🔮</span>
            <div className="topic-deep-bubble topic-deep-bubble--typing">
              <span className="topic-deep-typing">
                <i />
                <i />
                <i />
              </span>
            </div>
          </div>
        )}
      </div>
    </section>
  );
}
