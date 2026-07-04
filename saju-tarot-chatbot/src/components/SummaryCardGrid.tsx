import type { ReadingDashboard } from "../lib/readingDashboard";

/**
 * 결과 최상단 요약 히어로. 한 줄 결론 + 강점 + 주의점 + 지금 필요한 행동을 카드 그리드로.
 * 첫 화면에서 스크롤 없이 "나에 대한 핵심"을 잡게 하는 게 목적.
 */
export default function SummaryCardGrid({
  conclusion,
  keywords,
  dashboard,
}: {
  conclusion?: string | null;
  keywords?: string[];
  dashboard: ReadingDashboard;
}) {
  const hasCards = dashboard.strengths.length > 0 || dashboard.cautions.length > 0 || dashboard.needNow;
  if (!conclusion && !hasCards) return null;

  return (
    <section className="card summary-hero">
      {conclusion && (
        <div className="summary-hero__conclusion">
          <span className="summary-hero__tag">한 줄 결론</span>
          <p>{conclusion}</p>
        </div>
      )}

      {keywords && keywords.length > 0 && (
        <div className="summary-hero__chips">
          {keywords.map((k) => (
            <span className="summary-hero__chip" key={k}>
              {k}
            </span>
          ))}
        </div>
      )}

      <div className="summary-hero__grid">
        {dashboard.strengths.length > 0 && (
          <article className="summary-tile summary-tile--strength">
            <b>강점</b>
            <ul>
              {dashboard.strengths.map((s) => (
                <li key={s}>{s}</li>
              ))}
            </ul>
          </article>
        )}
        {dashboard.cautions.length > 0 && (
          <article className="summary-tile summary-tile--caution">
            <b>주의점</b>
            <ul>
              {dashboard.cautions.map((c) => (
                <li key={c}>{c}</li>
              ))}
            </ul>
          </article>
        )}
        {dashboard.needNow && (
          <article className="summary-tile summary-tile--now">
            <b>지금 필요한 것</b>
            <p>{dashboard.needNow}</p>
          </article>
        )}
      </div>
      <p className="summary-hero__note">아래에 자세한 해석과 계산 근거가 이어집니다.</p>
    </section>
  );
}
