import { useState, type FormEvent } from "react";
import ContextPicker from "./ContextPicker";
import { SPREADS, SPREAD_IDS, type SpreadId } from "../lib/tarot";
import type { ReadingContext } from "../types";

interface Props {
  submitLabel: string;
  onSubmit: (question: string, spreadId: SpreadId, context: ReadingContext) => void;
  loading: boolean;
}

export default function TarotSpreadPicker({ submitLabel, onSubmit, loading }: Props) {
  const [question, setQuestion] = useState("");
  const [spreadId, setSpreadId] = useState<SpreadId>("ppf");
  const [context, setContext] = useState<ReadingContext>({});

  function handleSubmit(e: FormEvent) {
    e.preventDefault();
    if (loading) return;
    onSubmit(question, spreadId, context);
  }

  return (
    <form className="card form" onSubmit={handleSubmit}>
      <div className="field-row field-row--column">
        <span className="field-label">질문</span>
        <textarea
          placeholder={
            spreadId === "ab"
              ? "예: A) 지금 회사에 남기 vs B) 이직하기 — 어느 쪽이 나을까요?"
              : "예: 지금 이 관계, 계속 이어가도 될까요?"
          }
          value={question}
          onChange={(e) => setQuestion(e.target.value)}
          rows={3}
          required
        />
      </div>

      <div className="field-row field-row--column">
        <span className="field-label">스프레드</span>
        <div className="spread-options">
          {SPREAD_IDS.map((id) => (
            <label key={id}>
              <input type="radio" name="spread" checked={spreadId === id} onChange={() => setSpreadId(id)} />
              {SPREADS[id].label}
            </label>
          ))}
        </div>
        {spreadId === "ab" && <span className="field-hint">질문에 선택지 A와 B를 함께 적어주세요.</span>}
      </div>

      <ContextPicker value={context} onChange={setContext} />

      <button type="submit" className="btn btn--primary" disabled={loading || !question.trim()}>
        {loading ? "카드를 해석하는 중..." : submitLabel}
      </button>
    </form>
  );
}
