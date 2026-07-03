import { useState, type FormEvent } from "react";
import type { ReadingSession } from "../types";

interface Props {
  session: ReadingSession;
  onSend: (question: string) => void;
  loading: boolean;
}

export default function ChatFollowUp({ session, onSend, loading }: Props) {
  const [question, setQuestion] = useState("");
  const followUpMessages = session.messages.slice(2);

  function handleSubmit(e: FormEvent) {
    e.preventDefault();
    if (!question.trim() || loading) return;
    onSend(question.trim());
    setQuestion("");
  }

  return (
    <div className="card chat-followup">
      <h4>더 물어보기</h4>
      {followUpMessages.length > 0 && (
        <div className="chat-thread">
          {followUpMessages.map((m, i) => (
            <div key={i} className={m.role === "user" ? "chat-bubble chat-bubble--user" : "chat-bubble chat-bubble--assistant"}>
              {m.content}
            </div>
          ))}
        </div>
      )}
      <form onSubmit={handleSubmit} className="chat-input-row">
        <input
          type="text"
          placeholder="이 리딩에 대해 더 궁금한 점을 물어보세요"
          value={question}
          onChange={(e) => setQuestion(e.target.value)}
          disabled={loading}
        />
        <button type="submit" className="btn btn--secondary" disabled={loading || !question.trim()}>
          {loading ? "..." : "보내기"}
        </button>
      </form>
    </div>
  );
}
