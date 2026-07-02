import { useState, type FormEvent } from "react";
import { SPREAD_LABEL, type SpreadSize } from "../lib/tarot";

interface Props {
  submitLabel: string;
  onSubmit: (question: string, count: SpreadSize) => void;
  loading: boolean;
}

const SPREAD_SIZES: SpreadSize[] = [1, 3, 5];

export default function TarotSpreadPicker({ submitLabel, onSubmit, loading }: Props) {
  const [question, setQuestion] = useState("");
  const [count, setCount] = useState<SpreadSize>(3);

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
        {SPREAD_SIZES.map((size) => (
          <label key={size}>
            <input type="radio" name="count" checked={count === size} onChange={() => setCount(size)} />
            {SPREAD_LABEL[size]}
          </label>
        ))}
      </div>

      <button type="submit" className="btn btn--primary" disabled={loading || !question.trim()}>
        {loading ? "카드를 해석하는 중..." : submitLabel}
      </button>
    </form>
  );
}
