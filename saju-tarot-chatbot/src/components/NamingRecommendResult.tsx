import type { ScoredRecommendedName } from "../lib/naming";

const LEVEL_KEY: Record<string, string> = {
  좋음: "good",
  보통: "ok",
  주의: "warn",
  순조로움: "good",
  무난함: "ok",
  "다소 부딪힘": "warn",
};

function levelClass(level: string): string {
  return `naming-badge naming-badge--${LEVEL_KEY[level] ?? "ok"}`;
}

function scoreTone(score: number): string {
  if (score >= 85) return "good";
  if (score >= 70) return "ok";
  return "warn";
}

export default function NamingRecommendResult({
  direction,
  candidates,
  topCount = 5,
}: {
  direction?: string | null;
  candidates: ScoredRecommendedName[];
  topCount?: number;
}) {
  if (candidates.length === 0) return null;
  const top = candidates.slice(0, topCount);

  return (
    <>
      {direction && (
        <section className="card naming-interpretation">
          <h4 className="naming-section-title">이름을 이렇게 골랐어요</h4>
          <p>{direction}</p>
        </section>
      )}

      <section className="card naming-scoretable">
        <h4 className="naming-section-title">추천 이름 {candidates.length}개 · 점수표</h4>
        <p className="field-hint">
          점수는 사주 보완 적합도와 발음(소리) 조화를 시스템이 계산한 값이에요(100점 만점). 길흉 예언이 아니라 비교용
          지표입니다.
        </p>
        <div className="naming-scoretable__scroll">
          <table className="naming-scoretable__table">
            <thead>
              <tr>
                <th>#</th>
                <th>이름</th>
                <th>한자</th>
                <th>점수</th>
                <th>사주 보완</th>
                <th>소리</th>
              </tr>
            </thead>
            <tbody>
              {candidates.map((c) => (
                <tr key={c.fullName}>
                  <td>{c.rank}</td>
                  <td>
                    <b>{c.fullName}</b>
                  </td>
                  <td>{c.hanja ?? "—"}</td>
                  <td>
                    <span className={`naming-score naming-score--${scoreTone(c.displayScore)}`}>{c.displayScore}</span>
                  </td>
                  <td>{c.evaluation.fit.level}</td>
                  <td>{c.evaluation.sound.harmony}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section className="card naming-topcards">
        <h4 className="naming-section-title">TOP {top.length} 상세 분석</h4>
        <div className="naming-comparison__grid">
          {top.map((c) => (
            <article key={c.fullName} className={c.rank === 1 ? "naming-candidate naming-candidate--best" : "naming-candidate"}>
              <div className="naming-candidate__top">
                <b>
                  {c.rank}. {c.fullName}
                  {c.hanja ? ` (${c.hanja})` : ""}
                </b>
                <span className={`naming-score naming-score--${scoreTone(c.displayScore)}`}>{c.displayScore}점</span>
              </div>
              {c.hanjaMeaning && <p className="naming-candidate__meaning">{c.hanjaMeaning}</p>}
              <dl>
                <div>
                  <dt>사주 보완</dt>
                  <dd>
                    <span className={levelClass(c.evaluation.fit.level)}>{c.evaluation.fit.level}</span> ·{" "}
                    {c.evaluation.fit.neededLabel} 기운
                  </dd>
                </div>
                <div>
                  <dt>소리 흐름</dt>
                  <dd>{c.evaluation.sound.harmony}</dd>
                </div>
              </dl>
              {c.sound && <p className="naming-candidate__note">🔊 {c.sound}</p>}
              {c.image && <p className="naming-candidate__note">💬 {c.image}</p>}
              <p className="naming-candidate__note field-hint">{c.evaluation.fit.note}</p>
            </article>
          ))}
        </div>
      </section>
    </>
  );
}
