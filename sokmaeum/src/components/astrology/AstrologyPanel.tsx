import type { AstrologyProfile } from "../../types";

function deg(n: number): string {
  return `${Math.floor(n)}도`;
}

export default function AstrologyPanel({ profile }: { profile: AstrologyProfile }) {
  const m = profile.modern;

  return (
    <div className="astro-panel">
      <div className="astro-head">
        <div>
          <h4>사주 × 점성술 3중 차트</h4>
          <p>{profile.locationLabel}</p>
        </div>
        <span className="astro-pill">{profile.timeKnown ? "시간 반영" : "시간 미상"}</span>
      </div>

      <div className="astro-grid">
        <section className="astro-system">
          <h5>현대</h5>
          <p className="astro-caption">마음, 관계, 욕구를 읽는 심리 차트</p>
          <div className="astro-chip-row">
            {[m.sun, m.moon, m.ascendant, m.venus, m.mars].filter(Boolean).map((p) => (
              <span className="astro-chip" key={p!.body}>
                <b>{p!.body}</b>
                {p!.sign} {deg(p!.degree)}
              </span>
            ))}
          </div>
        </section>

        <section className="astro-system">
          <h5>고전</h5>
          <p className="astro-caption">현실 사건, 하우스, 행성의 힘을 보는 전통 차트</p>
          <div className="astro-chip-row">
            <span className="astro-chip">
              <b>섹트</b>
              {profile.classical.sect === "day" ? "데이 차트" : profile.classical.sect === "night" ? "나이트 차트" : "시간 필요"}
            </span>
            {profile.classical.placements.slice(0, 4).map((p) => (
              <span className="astro-chip" key={p.body}>
                <b>{p.body}</b>
                {p.sign} · {p.dignity}
              </span>
            ))}
          </div>
        </section>

        <section className="astro-system">
          <h5>베딕</h5>
          <p className="astro-caption">시데리얼 별자리와 달의 나크샤트라로 보는 마음의 리듬</p>
          <div className="astro-chip-row">
            {profile.vedic.lagna && (
              <span className="astro-chip">
                <b>라그나</b>
                {profile.vedic.lagna.sign}
              </span>
            )}
            <span className="astro-chip">
              <b>달</b>
              {profile.vedic.moon.sign} · {profile.vedic.moon.nakshatra} {profile.vedic.moon.pada}파다
            </span>
            <span className="astro-chip">
              <b>태양</b>
              {profile.vedic.sun.sign}
            </span>
            <span className="astro-chip">
              <b>라후</b>
              {profile.vedic.rahu.sign}
            </span>
            <span className="astro-chip">
              <b>케투</b>
              {profile.vedic.ketu.sign}
            </span>
            <span className="astro-chip">
              <b>다샤</b>
              {profile.vedic.dasha.currentMahaDasha}
            </span>
          </div>
        </section>
      </div>

      <details className="astro-more">
        <summary>점성술 근거 보기</summary>
        <ul>
          {profile.notes.map((note) => (
            <li key={note}>{note}</li>
          ))}
        </ul>
        <p>{profile.accuracyNote}</p>
        <p>{profile.vedic.ayanamsa}</p>
        <p>
          Vimshottari: 출생 나크샤트라 주재성 {profile.vedic.dasha.birthNakshatraLord}, 현재{" "}
          {profile.vedic.dasha.currentMahaDasha} 마하다샤 ({profile.vedic.dasha.currentMahaDashaStart}~
          {profile.vedic.dasha.currentMahaDashaEnd})
        </p>
      </details>
    </div>
  );
}
