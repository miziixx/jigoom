import { useState } from "react";
import { FEEDBACK_TAGS, RATING_LABEL } from "../lib/feedback";
import { useReadingStore } from "../store/useReadingStore";
import type { FeedbackRating, ReadingSession } from "../types";

/** 리딩 결과에 대한 피드백 수집 — 다음 리딩의 스타일 개인화에 쓰인다 */
export default function FeedbackBar({ session }: { session: ReadingSession }) {
  const submitFeedback = useReadingStore((s) => s.submitFeedback);
  const isSessionSaved = useReadingStore((s) => s.savedSessions.some((savedSession) => savedSession.id === session.id));
  const [rating, setRating] = useState<FeedbackRating | null>(session.feedback?.rating ?? null);
  const [tags, setTags] = useState<string[]>(session.feedback?.tags ?? []);
  const [saved, setSaved] = useState(session.feedback !== undefined);

  function toggleTag(id: string) {
    setSaved(false);
    setTags((prev) => (prev.includes(id) ? prev.filter((t) => t !== id) : [...prev, id]));
  }

  function pickRating(r: FeedbackRating) {
    setSaved(false);
    setRating(r);
  }

  function handleSave() {
    if (!rating) return;
    submitFeedback(session.id, rating, tags);
    setSaved(true);
  }

  if (!isSessionSaved) {
    return (
      <div className="card feedback-bar">
        <h4>이번 리딩, 어땠나요?</h4>
        <p className="field-hint">피드백을 남기려면 먼저 리딩을 이 기기에 저장해야 합니다.</p>
      </div>
    );
  }

  return (
    <div className="card feedback-bar">
      <h4>이번 리딩, 어땠나요?</h4>
      <p className="field-hint">피드백은 이 기기에만 저장되며, 원하시면 다음 리딩의 설명 방식에 반영할 수 있습니다.</p>
      <div className="field-row">
        {(Object.keys(RATING_LABEL) as FeedbackRating[]).map((r) => (
          <label key={r}>
            <input type="radio" name="feedback-rating" checked={rating === r} onChange={() => pickRating(r)} />
            {RATING_LABEL[r]}
          </label>
        ))}
      </div>
      <div className="field-row">
        {FEEDBACK_TAGS.map((tag) => (
          <label key={tag.id}>
            <input type="checkbox" checked={tags.includes(tag.id)} onChange={() => toggleTag(tag.id)} />
            {tag.label}
          </label>
        ))}
      </div>
      <button className="btn btn--secondary" onClick={handleSave} disabled={!rating || saved}>
        {saved ? "피드백 저장됨 ✓" : "피드백 남기기"}
      </button>
    </div>
  );
}
