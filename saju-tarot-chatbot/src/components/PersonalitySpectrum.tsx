import type { SpectrumAxis } from "../lib/readingDashboard";

/**
 * 기질 스펙트럼: 직관↔분석 등 4축을 슬라이더로 보여준다.
 * 각 축 아래 한 줄 해석(치우친 쪽)을 붙인다. (시각 요소 1개 = 메시지 1개)
 */
export default function PersonalitySpectrum({ spectrum }: { spectrum: SpectrumAxis[] }) {
  if (!spectrum || spectrum.length === 0) return null;
  return (
    <section className="card spectrum">
      <div className="section-heading-row">
        <h3 className="card-title">기질 스펙트럼</h3>
        <span className="feature-badge">심리 언어</span>
      </div>
      <p className="spectrum__intro">사주 구조를 성격 언어로 옮긴 상대 경향이에요. 좋고 나쁨이 아니라 방향입니다.</p>
      <div className="spectrum__list">
        {spectrum.map((axis) => (
          <div className="spectrum__row" key={axis.key}>
            <div className="spectrum__labels">
              <span className={axis.position <= 40 ? "spectrum__side spectrum__side--active" : "spectrum__side"}>
                {axis.leftLabel}
              </span>
              <span className={axis.position >= 60 ? "spectrum__side spectrum__side--active" : "spectrum__side"}>
                {axis.rightLabel}
              </span>
            </div>
            <div className="spectrum__track">
              <span className="spectrum__dot" style={{ left: `${axis.position}%` }} />
            </div>
            <p className="spectrum__note">{axis.note}</p>
          </div>
        ))}
      </div>
    </section>
  );
}
