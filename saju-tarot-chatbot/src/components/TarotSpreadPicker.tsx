import { useState, type FormEvent } from "react";

interface Props {
  submitLabel: string;
  onSubmit: (question: string, count: 1 | 3) => void;
  loading: boolean;
}

export default function TarotSpreadPicker({ submitLabel, onSubmit, loading }: Props) {
  const [question, setQuestion] = useState("");
  const [count, setCount] = useState<1 | 3>(3);

  function handleSubmit(e: FormEvent) {
    e.preventDefault();
    if (loading) return;
    onSubmit(question, count);
  }

  return (
    <form className="card form" onSubmit={handleSubmit}>
      <div className="field-row field-row--column">
        <span className="field-label">질문</span>
        <textarea
          placeholder="예: 지금 이 관계, 계속 이어가도 될까요?"
          value={question}
          onChange={(e) => setQuestion(e.target.value)}
          rows={3}
          required
        />
      </div>

      <div className="field-row">
        <span className="field-label">스프레드</span>
        <label>
          <input type="radio" name="count" checked={count === 1} onChange={() => setCount(1)} />1장 (오늘의 카드)
        </label>
        <label>
          <input type="radio" name="count" checked={count === 3} onChange={() => setCount(3)} />
          3장 (과거·현재·미래)
        </label>
      </div>

      <button type="submit" className="btn btn--primary" disabled={loading || !question.trim()}>
        {loading ? "카드를 해석하는 중..." : submitLabel}
      </button>
    </form>
  );
}
