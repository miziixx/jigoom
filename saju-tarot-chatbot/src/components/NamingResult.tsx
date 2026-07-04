import { NAMING_MODE_LABEL, type NameEvaluation } from "../lib/naming";

const LEVEL_KEY: Record<string, string> = { 좋음: "good", 보통: "ok", 주의: "warn", 순조로움: "good", 무난함: "ok", "다소 부딪힘": "warn", 길: "good", 평: "ok", 흉: "warn" };

function levelClass(level: string): string {
  return `naming-badge naming-badge--${LEVEL_KEY[level] ?? "ok"}`;
}

export default function NamingResult({
  result,
  interpretation,
  interpretationLoading = false,
  interpretationError,
}: {
  result: NameEvaluation;
  interpretation?: string | null;
  interpretationLoading?: boolean;
  interpretationError?: string | null;
}) {
  const { name, sound, fit, suri, overall, headline } = result;

  return (
    <div className="naming-result">
      <section className="card naming-hero">
        <div className="naming-hero__top">
          <b className="naming-hero__name">{name}</b>
          <span className={levelClass(overall)}>종합 {overall}</span>
        </div>
        <div className="naming-chips naming-chips--compact">
          {result.purpose && <span>{NAMING_MODE_LABEL[result.purpose.mode]}</span>}
          <span>{result.schoolLabel}</span>
        </div>
        <p>{headline}</p>
      </section>

      <section className="card">
        <h4 className="naming-section-title">소리의 기운 (발음오행)</h4>
        <div className="naming-syllables">
          {sound.syllables.map((s, i) => (
            <span key={i} className="naming-syllable">
              <b>{s.syllable}</b>
              <small>{s.choseong} · {s.elementLabel}</small>
            </span>
          ))}
        </div>
        {sound.relations.length > 0 && (
          <ul className="naming-relations">
            {sound.relations.map((r, i) => (
              <li key={i} className={levelClass(r.relation)}>
                {r.from} → {r.to} : {r.relation}
              </li>
            ))}
          </ul>
        )}
        <p className="naming-note">
          <span className={levelClass(sound.harmony)}>{sound.harmony}</span> {sound.note}
        </p>
      </section>

      <section className="card">
        <h4 className="naming-section-title">내 사주와의 궁합</h4>
        <p className="naming-note">
          <span className={levelClass(fit.level)}>{fit.level}</span> {fit.note}
        </p>
        <div className="naming-chips">
          <span>보완하면 좋은 기운 {fit.neededLabel}</span>
          {fit.avoidLabel && <span>과하면 부담 {fit.avoidLabel}</span>}
        </div>
      </section>

      {suri && (
        <section className="card">
          <h4 className="naming-section-title">획수 수리 (참고)</h4>
          <ul className="naming-suri">
            {suri.levels.map((l) => (
              <li key={l.name}>
                <span>{l.name}</span>
                <b>{l.total}</b>
                <span className={levelClass(l.level)}>{l.level}</span>
              </li>
            ))}
          </ul>
          <p className="naming-note">{suri.summary}</p>
        </section>
      )}

      <section className="card naming-interpretation">
        <h4 className="naming-section-title">AI 이름 해석 리포트</h4>
        {interpretationLoading && (
          <p className="naming-note">계산 근거를 바탕으로 이름의 인상과 보완 포인트를 쉬운 문장으로 풀어쓰는 중입니다.</p>
        )}
        {interpretationError && <p className="error-text">{interpretationError}</p>}
        {interpretation && <pre className="naming-interpretation__text">{interpretation}</pre>}
        {!interpretationLoading && !interpretation && !interpretationError && (
          <p className="naming-note">위 계산 결과를 바탕으로 깊은 문장 해석을 불러올 수 있습니다.</p>
        )}
      </section>

      <p className="naming-disclaimer">
        이름 감정은 절대적인 길흉 예언이 아니라, 발음오행·사주 보완·수리 같은 전통 작명 관점을 계산해 균형을 보여주는
        참고 자료입니다. 어떤 이름도 "나쁜 이름"으로 단정하지 않습니다.
      </p>
    </div>
  );
}
