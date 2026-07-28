import { useEffect, useRef, useState } from "react";
import { streamReading } from "../lib/readingApi";
import { parseSections, stripMarkdown } from "../lib/readingText";
import type { ChatMessage, DrawnTarotCard, Gender, LuckCycles, ReadingType, SajuChart, TopicDeepTopic } from "../types";

export const TOPIC_LABEL: Record<TopicDeepTopic, string> = {
  love: "연애운",
  money: "재물운",
  career: "직업운",
  health: "건강운",
  year: "올해운",
};

/** systemPrompt.ts의 buildTopicDeepInstruction과 섹션 개수를 맞춘다 — 몇 개 도착했는지 판단하는 기준. */
const EXPECTED_SECTIONS = 5;
const MAX_FOLLOW_UP = 5;

/** 토픽 5종 템플릿 확장: 시안 ②의 후속 질문 칩 — 토픽마다 다른 질문을 제안한다. */
const FOLLOW_UP_CHIPS: Record<TopicDeepTopic, string[]> = {
  love: ["올해 연애 시기 더 자세히", "지금 만나는 사람이랑은 어떨까요?"],
  money: ["돈이 새는 구멍 더 자세히", "지금 투자해도 괜찮을까요?"],
  career: ["이직 타이밍 더 자세히", "지금 회사에서 버텨야 할까요?"],
  health: ["요즘 컨디션 더 자세히", "어떤 습관부터 바꾸면 좋을까요?"],
  year: ["하반기 흐름 더 자세히", "지금 조심해야 할 시기는 언제인가요?"],
};

function followUpModeFor(question: string): "concise" | "deep" {
  return /자세히|깊게|상세|구체적으로|길게/.test(question) ? "deep" : "concise";
}

/**
 * 토픽 심화 결과를 말풍선으로 점진 공개하고(A-3, 시안 ②), 이어서 후속 질문(최대 5회)까지 받는다
 * (토픽 5종 템플릿 확장 — 재기획안 §5 "이어서 질문 5회까지 무료" 재현).
 *
 * 전역 세션(store)을 쓰지 않는다 — 클릭한 자리에서 인라인으로 뜨는 결과라, 지금 보고 있는 전체
 * 리딩을 잃지 않기 위한 A-2의 결정을 그대로 잇는다. 대화 기록은 이 컴포넌트 로컬 상태로만 관리한다.
 */
export default function TopicDeepChat({
  topic,
  sajuChart,
  luckCycles,
  gender,
  type,
  tarotCards,
}: {
  topic: TopicDeepTopic;
  sajuChart?: SajuChart;
  luckCycles?: LuckCycles;
  gender?: Gender;
  type: ReadingType;
  tarotCards?: DrawnTarotCard[];
}) {
  // messages[0]=최초 요청에 실제로 보낸 프롬프트(meta.userMessage), [1]=첫 답변, 이후 후속 Q&A.
  // 빈 배열이면 아직 첫 요청이 끝나지 않은 것이다.
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [firstReplyText, setFirstReplyText] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [followUpInput, setFollowUpInput] = useState("");
  const startedRef = useRef(false);

  useEffect(() => {
    if (startedRef.current) return;
    startedRef.current = true;

    async function startInitial() {
      try {
        const result = await streamReading(
          {
            type: type === "combo" ? "combo" : "saju",
            question: "",
            gender,
            sajuChart,
            luckCycles,
            tarotCards: type === "combo" ? tarotCards : undefined,
            context: { analysisMode: "topicDeep", topic },
          },
          { onText: (accumulated) => setFirstReplyText(accumulated) },
        );
        setMessages([
          { role: "user", content: result.meta?.userMessage ?? "" },
          { role: "assistant", content: result.reply },
        ]);
      } catch (err) {
        setError(err instanceof Error ? err.message : "토픽 심화를 불러오지 못했습니다.");
      } finally {
        setLoading(false);
      }
    }
    void startInitial();
    // topic/sajuChart는 부모가 key={topic}으로 마운트를 새로 하므로 최초 1회만 실행한다.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const followUpTurns = messages.slice(2);
  const usedFollowUps = followUpTurns.filter((m) => m.role === "user").length;
  const reachedLimit = usedFollowUps >= MAX_FOLLOW_UP;
  const hasFirstReply = messages.length > 0;

  async function sendFollowUp(question: string) {
    const trimmed = question.trim();
    if (!trimmed || loading || reachedLimit || !hasFirstReply) return;
    const history = [...messages, { role: "user" as const, content: trimmed }];
    setMessages(history);
    setLoading(true);
    setError(null);
    try {
      const result = await streamReading(
        { type: "followup", history, followUpMode: followUpModeFor(trimmed) },
        { onText: (accumulated) => setMessages([...history, { role: "assistant", content: accumulated }]) },
      );
      setMessages([...history, { role: "assistant", content: result.reply }]);
    } catch (err) {
      setError(err instanceof Error ? err.message : "후속 질문에 실패했어요.");
    } finally {
      setLoading(false);
    }
  }

  const sections = firstReplyText.trim() ? parseSections(firstReplyText) : [];
  const showTypingIndicator = !hasFirstReply && loading && sections.length < EXPECTED_SECTIONS;

  return (
    <section className="card topic-deep-chat">
      <div className="section-heading-row">
        <h3 className="card-title">{TOPIC_LABEL[topic]} 심화</h3>
        <span className="feature-badge">{!hasFirstReply && loading ? "생성 중" : "완료"}</span>
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

      {followUpTurns.length > 0 && (
        <div className="chat-thread topic-deep-chat__followups">
          {followUpTurns.map((m, i) => (
            <div className={m.role === "user" ? "chat-bubble chat-bubble--user" : "chat-bubble chat-bubble--assistant"} key={i}>
              {stripMarkdown(m.content)}
            </div>
          ))}
        </div>
      )}
      {loading && hasFirstReply && (
        <div className="chat-thread topic-deep-chat__followups">
          <div className="chat-bubble chat-bubble--assistant topic-deep-chat__followup-typing">답을 쓰는 중…</div>
        </div>
      )}

      {hasFirstReply && (
        <>
          {!reachedLimit && (
            <div className="chat-suggestion-row" aria-label="토픽 후속 질문 예시">
              {FOLLOW_UP_CHIPS[topic].map((chip) => (
                <button
                  key={chip}
                  type="button"
                  className="topic-deep-chip"
                  disabled={loading}
                  onClick={() => void sendFollowUp(chip)}
                >
                  {chip}
                </button>
              ))}
            </div>
          )}
          <p className="topic-deep-chat__note">
            {reachedLimit ? "이 토픽의 후속 질문 5개를 모두 사용했어요." : `이어서 질문 ${MAX_FOLLOW_UP - usedFollowUps}회까지 무료`}
          </p>
          {!reachedLimit && (
            <form
              className="chat-input-row"
              onSubmit={(e) => {
                e.preventDefault();
                const q = followUpInput.trim();
                if (!q) return;
                setFollowUpInput("");
                void sendFollowUp(q);
              }}
            >
              <input
                type="text"
                placeholder="궁금한 점을 더 물어보세요"
                value={followUpInput}
                onChange={(e) => setFollowUpInput(e.target.value)}
                disabled={loading}
              />
              <button type="submit" className="btn btn--secondary" disabled={loading || !followUpInput.trim()}>
                {loading ? "..." : "보내기"}
              </button>
            </form>
          )}
        </>
      )}
    </section>
  );
}
