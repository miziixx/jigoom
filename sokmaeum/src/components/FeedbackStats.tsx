import { FEEDBACK_TAGS, RATING_LABEL } from "../lib/feedback";
import type { FeedbackRating, ReadingSession } from "../types";

const TAG_LABEL = new Map<string, string>(FEEDBACK_TAGS.map((t) => [t.id, t.label]));

/** 저장된 리딩들의 피드백 통계 — 어떤 리딩이 잘 맞는다고 느끼는지 한눈에 보여준다 */
export default function FeedbackStats({ sessions }: { sessions: ReadingSession[] }) {
  const feedbacks = sessions.filter((s) => s.feedback);
  if (feedbacks.length === 0) return null;

  const ratingCount = new Map<FeedbackRating, number>();
  const tagCount = new Map<string, number>();
  for (const s of feedbacks) {
    const f = s.feedback!;
    ratingCount.set(f.rating, (ratingCount.get(f.rating) ?? 0) + 1);
    for (const tag of f.tags ?? []) tagCount.set(tag, (tagCount.get(tag) ?? 0) + 1);
  }

  const topTags = [...tagCount.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, 3)
    .map(([id, count]) => `${TAG_LABEL.get(id) ?? id} ${count}회`);

  return (
    <div className="card feedback-stats">
      <h4>내 피드백 통계</h4>
      <p>
        리딩 {sessions.length}건 중 {feedbacks.length}건에 피드백을 남겼습니다.
      </p>
      <div className="feedback-stats__bars">
        {(Object.keys(RATING_LABEL) as FeedbackRating[]).map((rating) => {
          const count = ratingCount.get(rating) ?? 0;
          const pct = Math.round((count / feedbacks.length) * 100);
          return (
            <div key={rating} className="feedback-stats__row">
              <span className="feedback-stats__label">{RATING_LABEL[rating]}</span>
              <span className="feedback-stats__track">
                <span className="feedback-stats__fill" style={{ width: `${pct}%` }} />
              </span>
              <span className="feedback-stats__count">{count}</span>
            </div>
          );
        })}
      </div>
      {topTags.length > 0 && <p className="field-hint">자주 남긴 의견: {topTags.join(" · ")}</p>}
    </div>
  );
}
