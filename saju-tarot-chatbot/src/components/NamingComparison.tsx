import type { NameComparison } from "../lib/naming";

const LEVEL_KEY: Record<string, string> = { 좋음: "good", 보통: "ok", 주의: "warn", 순조로움: "good", 무난함: "ok", "다소 부딪힘": "warn" };

function levelClass(level: string): string {
  return `naming-badge naming-badge--${LEVEL_KEY[level] ?? "ok"}`;
}

export default function NamingComparison({ comparison }: { comparison: NameComparison }) {
  return (
    <section className="card naming-comparison">
      <div className="naming-comparison__head">
        <div>
          <h4 className="naming-section-title">후보 이름 비교</h4>
          <p>{comparison.summary}</p>
        </div>
        <span className={levelClass(comparison.recommended.overall)}>추천 {comparison.recommended.name}</span>
      </div>

      <div className="naming-comparison__grid">
        {comparison.candidates.map((candidate, index) => (
          <article key={candidate.name} className={index === 0 ? "naming-candidate naming-candidate--best" : "naming-candidate"}>
            <div className="naming-candidate__top">
              <b>{index + 1}. {candidate.name}</b>
              <span className={levelClass(candidate.overall)}>{candidate.overall}</span>
            </div>
            <p>{candidate.headline}</p>
            <dl>
              <div>
                <dt>소리 흐름</dt>
                <dd>{candidate.sound.harmony}</dd>
              </div>
              <div>
                <dt>사주 보완</dt>
                <dd>{candidate.fit.level} · {candidate.fit.neededLabel}</dd>
              </div>
              <div>
                <dt>획수 참고</dt>
                <dd>{candidate.suri ? candidate.suri.summary : "미입력"}</dd>
              </div>
            </dl>
          </article>
        ))}
      </div>
    </section>
  );
}
