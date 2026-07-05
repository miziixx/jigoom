import { useState, type FormEvent } from "react";
import type { ReadingSession } from "../types";

const MAX_FOLLOW_UP_QUESTIONS = 5;
const FOLLOW_UP_EXAMPLES = [
  "예: 왜 관계에서 비슷한 패턴이 반복되는지 더 자세히 봐줘.",
  "예: 돈이 새는 습관과 이번 달 관리법을 구체적으로 알려줘.",
  "예: 지금 일에서 버틸지 바꿀지 판단 기준을 더 깊게 봐줘.",
];

interface Props {
  session: ReadingSession;
  onSend: (question: string) => void;
  loading: boolean;
}

export default function ChatFollowUp({ session, onSend, loading }: Props) {
  const [question, setQuestion] = useState("");
  const followUpMessages = session.messages.slice(2);
  const usedQuestions = followUpMessages.filter((m) => m.role === "user").length;
  const reachedLimit = usedQuestions >= MAX_FOLLOW_UP_QUESTIONS;

  function handleSubmit(e: FormEvent) {
    e.preventDefault();
    if (!question.trim() || loading || reachedLimit) return;
    onSend(question.trim());
    setQuestion("");
  }

  return (
    <div className="card chat-followup">
      <h4>더 물어보기 ({usedQuestions}/{MAX_FOLLOW_UP_QUESTIONS})</h4>
      <p className="chat-followup__intro">
        유료/정밀 리딩에서 본 연애운·금전운·직업운은 여기서 더 깊게 파고들 수 있어요. “자세히”, “깊게”라고
        물으면 답변이 더 촘촘해집니다.
      </p>
      {followUpMessages.length > 0 && (
        <div className="chat-thread">
          {followUpMessages.map((m, i) => (
            <div key={i} className={m.role === "user" ? "chat-bubble chat-bubble--user" : "chat-bubble chat-bubble--assistant"}>
              {m.content}
            </div>
          ))}
        </div>
      )}
      {!reachedLimit && (
        <div className="chat-suggestion-row" aria-label="깊게 물어보기 예시">
          {FOLLOW_UP_EXAMPLES.map((text) => (
            <span className="chat-suggestion" key={text}>
              {text}
            </span>
          ))}
        </div>
      )}
      <form onSubmit={handleSubmit} className="chat-input-row">
        <input
          type="text"
          placeholder={reachedLimit ? "후속 질문은 최대 5개까지 가능합니다" : "궁금한 점을 물어보세요. 먼저 짧게 답해드려요"}
          value={question}
          onChange={(e) => setQuestion(e.target.value)}
          disabled={loading || reachedLimit}
        />
        <button type="submit" className="btn btn--secondary" disabled={loading || reachedLimit || !question.trim()}>
          {loading ? "..." : "보내기"}
        </button>
      </form>
      {!reachedLimit && (
        <p className="chat-followup__hint">깊은 분석이 필요하면 질문에 “자세히” 또는 “깊게”라고 함께 적어주세요.</p>
      )}
      {reachedLimit && <p className="chat-followup__limit">이 리딩의 후속 질문 5개를 모두 사용했습니다. 새 질문은 새 리딩으로 시작해주세요.</p>}
    </div>
  );
}
