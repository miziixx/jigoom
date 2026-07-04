import type { LifeArea } from "../lib/readingDashboard";

/**
 * 인생영역 상대 경향 막대. 절대 진단 점수가 아니라 "상대 경향 + 라벨"이며,
 * 막대마다 한 줄 해석을 붙인다. (CLAUDE.md: 점수로 환원/정밀한 척 금지)
 */
export default function LifeAreaBars({ areas }: { areas: LifeArea[] }) {
  if (!areas || areas.length === 0) return null;
  return (
    <section className="card life-areas">
      <div className="section-heading-row">
        <h3 className="card-title">인생영역 한눈에</h3>
        <span className="feature-badge">상대 경향</span>
      </div>
      <p className="life-areas__intro">영역별로 어느 쪽 힘이 더 두드러지는지 보여주는 상대 막대예요. 절대 점수가 아닙니다.</p>
      <div className="life-areas__list">
        {areas.map((area) => (
          <div className="life-area" key={area.key}>
            <div className="life-area__head">
              <span className="life-area__label">{area.label}</span>
              <span className={`life-area__tone life-area__tone--${area.tone}`}>{area.toneLabel}</span>
            </div>
            <div className="life-area__track">
              <span className={`life-area__fill life-area__fill--${area.tone}`} style={{ width: `${area.level}%` }} />
            </div>
            <p className="life-area__note">{area.note}</p>
          </div>
        ))}
      </div>
    </section>
  );
}
