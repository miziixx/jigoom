export type RatingLevel = "good" | "mid" | "caution";

const RATING_META: Record<RatingLevel, { word: string; dots: number }> = {
  good: { word: "좋음", dots: 3 },
  mid: { word: "보통", dots: 2 },
  caution: { word: "주의", dots: 1 },
};

/**
 * 좋음/보통/주의 픽토그래프. 색만으로 구분하지 않도록 단어를 항상 함께 보여주고,
 * 주의는 점 대신 경고 삼각형을 써서 모양으로도 구분되게 한다.
 */
export default function RatingCell({ rating, word }: { rating: RatingLevel; word?: string }) {
  const meta = RATING_META[rating];
  return (
    <span className={`rating-cell rating-cell--${rating}`}>
      {rating === "caution" ? (
        <svg className="rating-cell__mark" viewBox="0 0 20 20" aria-hidden="true" focusable="false">
          <path d="M10 3.8L17.4 16H2.6z" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinejoin="round" />
          <path d="M10 8.6v3.4" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
          <circle cx="10" cy="14" r="0.7" fill="currentColor" />
        </svg>
      ) : (
        <svg className="rating-cell__dots" viewBox="0 0 30 10" aria-hidden="true" focusable="false">
          {[0, 1, 2].map((i) => (
            <circle
              key={i}
              className={i < meta.dots ? "rating-cell__dot--on" : "rating-cell__dot--off"}
              cx={5 + i * 10}
              cy="5"
              r="3.2"
            />
          ))}
        </svg>
      )}
      <b>{word ?? meta.word}</b>
    </span>
  );
}
