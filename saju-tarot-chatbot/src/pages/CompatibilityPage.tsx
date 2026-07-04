import { useState } from "react";
import Gauge, { tierWord } from "../components/Gauge";
import { BIRTH_PLACES } from "../data/birthPlaces";
import { computeCompatibility } from "../lib/saju";
import type { BirthInfo, CalendarType, CompatibilityRelationType, CompatibilityResult, Gender, LateNightZiMode } from "../types";

const HOURS = Array.from({ length: 24 }, (_, h) => h);

const RELATION_OPTIONS: Array<{ value: CompatibilityRelationType; label: string }> = [
  { value: "romantic", label: "연인·배우자" },
  { value: "parentChild", label: "부모·자식" },
  { value: "siblings", label: "형제·자매" },
  { value: "family", label: "가족" },
  { value: "bossEmployee", label: "사장·직원" },
  { value: "coworker", label: "동료·동업자" },
  { value: "friend", label: "친구" },
];

interface PersonInput {
  calendarType: CalendarType;
  year: string;
  month: string;
  day: string;
  hour: string;
  minute: string;
  lateNightZi: LateNightZiMode;
  birthPlace: string;
  isLeapMonth: boolean;
  gender: Gender;
}

const EMPTY: PersonInput = {
  calendarType: "solar",
  year: "",
  month: "",
  day: "",
  hour: "unknown",
  minute: "",
  lateNightZi: "late",
  birthPlace: "none",
  isLeapMonth: false,
  gender: "female",
};

function toBirthInfo(p: PersonInput): BirthInfo {
  return {
    calendarType: p.calendarType,
    year: Number(p.year),
    month: Number(p.month),
    day: Number(p.day),
    hour: p.hour === "unknown" ? null : Number(p.hour),
    minute: p.hour === "unknown" || p.minute === "" ? 0 : Number(p.minute),
    lateNightZi: p.hour === "23" ? p.lateNightZi : undefined,
    birthPlace: p.birthPlace,
    isLeapMonth: p.calendarType === "lunar" ? p.isLeapMonth : undefined,
    gender: p.gender,
  };
}

function MiniBirthForm({
  title,
  subtitle,
  role,
  value,
  onChange,
}: {
  title: string;
  subtitle: string;
  role: "me" | "partner";
  value: PersonInput;
  onChange: (p: PersonInput) => void;
}) {
  const set = (patch: Partial<PersonInput>) => onChange({ ...value, ...patch });
  return (
    <div className={`card mini-birth mini-birth--${role}`}>
      <div className="mini-birth__head">
        <span className={`compat-role-badge compat-role-badge--${role}`}>{title}</span>
        <p>{subtitle}</p>
      </div>
      <div className="field-row">
        <span className="field-label">달력</span>
        <label>
          <input type="radio" checked={value.calendarType === "solar"} onChange={() => set({ calendarType: "solar" })} /> 양력
        </label>
        <label>
          <input type="radio" checked={value.calendarType === "lunar"} onChange={() => set({ calendarType: "lunar" })} /> 음력
        </label>
      </div>
      <div className="field-row">
        <span className="field-label">생년월일</span>
        <input type="number" placeholder="년" value={value.year} onChange={(e) => set({ year: e.target.value })} />
        <input type="number" placeholder="월" min={1} max={12} value={value.month} onChange={(e) => set({ month: e.target.value })} />
        <input type="number" placeholder="일" min={1} max={31} value={value.day} onChange={(e) => set({ day: e.target.value })} />
      </div>
      {value.calendarType === "lunar" && (
        <div className="field-row">
          <span className="field-label">윤달</span>
          <label className="checkbox-label">
            <input type="checkbox" checked={value.isLeapMonth} onChange={(e) => set({ isLeapMonth: e.target.checked })} /> 윤달
          </label>
        </div>
      )}
      <div className="field-row">
        <span className="field-label">출생 시간</span>
        <select value={value.hour} onChange={(e) => set({ hour: e.target.value, minute: e.target.value === "unknown" ? "" : value.minute })}>
          <option value="unknown">모름</option>
          {HOURS.map((h) => (
            <option key={h} value={h}>
              {h}시
            </option>
          ))}
        </select>
        {value.hour !== "unknown" && (
          <input
            type="number"
            placeholder="분"
            min={0}
            max={59}
            value={value.minute}
            onChange={(e) => set({ minute: e.target.value })}
            aria-label="출생 분"
          />
        )}
        {value.hour === "unknown" ? (
          <span className="field-hint field-hint--accent">시간을 알면 시주까지 비교해 궁합 해석이 더 정확해집니다.</span>
        ) : (
          <span className="field-hint">분까지 정확할수록 좋아요. 애매하면 정각으로 두어도 됩니다.</span>
        )}
      </div>
      {value.hour === "23" && (
        <div className="field-row field-row--column">
          <span className="field-label">23:00 전후 기준</span>
          <select value={value.lateNightZi} onChange={(e) => set({ lateNightZi: e.target.value as LateNightZiMode })}>
            <option value="late">당일 기준 — 23:00~23:59도 입력한 날짜로 봄</option>
            <option value="early">다음날 기준 — 23:00~23:59부터 다음날로 봄</option>
          </select>
          <span className="field-hint field-hint--accent">23시대 출생은 만세력 기준에 따라 일주가 달라질 수 있어요.</span>
        </div>
      )}
      <div className="field-row">
        <span className="field-label">출생지</span>
        <select value={value.birthPlace} onChange={(e) => set({ birthPlace: e.target.value })}>
          <option value="none">보정 안 함</option>
          {Object.entries(BIRTH_PLACES).map(([key, place]) => (
            <option key={key} value={key}>
              {place.label}
            </option>
          ))}
        </select>
        <span className={`field-hint${value.birthPlace === "none" ? " field-hint--accent" : ""}`}>
          {value.birthPlace === "none"
            ? "출생지를 고르면 표준시·경도 차이를 반영해 시주 경계 판단이 더 정확해집니다."
            : "표준시·경도 차이를 반영합니다."}
        </span>
      </div>
      <div className="field-row">
        <span className="field-label">성별</span>
        <label>
          <input type="radio" checked={value.gender === "female"} onChange={() => set({ gender: "female" })} /> 여성
        </label>
        <label>
          <input type="radio" checked={value.gender === "male"} onChange={() => set({ gender: "male" })} /> 남성
        </label>
      </div>
    </div>
  );
}

export default function CompatibilityPage() {
  const [personA, setPersonA] = useState<PersonInput>({ ...EMPTY });
  const [personB, setPersonB] = useState<PersonInput>({ ...EMPTY, gender: "male" });
  const [relationType, setRelationType] = useState<CompatibilityRelationType>("romantic");
  const [result, setResult] = useState<CompatibilityResult | null>(null);
  const [error, setError] = useState<string | null>(null);

  const filled = (p: PersonInput) => p.year !== "" && p.month !== "" && p.day !== "";
  const canSubmit = filled(personA) && filled(personB);

  function handleCompute() {
    setError(null);
    try {
      setResult(computeCompatibility(toBirthInfo(personA), toBirthInfo(personB), relationType));
    } catch {
      setError("궁합 계산에 실패했어요. 생년월일을 다시 확인해 주세요.");
    }
  }

  return (
    <section className="page">
      <h2 className="page-title">궁합 보기</h2>
      <p className="page-desc">두 사람의 사주 원국을 계산해 일간 관계·지지 인연(합충)·오행 보완을 종합한 궁합 점수를 보여드려요. (참고용)</p>

      <section className="card compat-relation-picker">
        <h3 className="card-title">어떤 관계로 볼까요?</h3>
        <label className="compat-relation-select">
          <span>관계 유형</span>
          <select value={relationType} onChange={(e) => setRelationType(e.target.value as CompatibilityRelationType)}>
            {RELATION_OPTIONS.map((option) => (
              <option key={option.value} value={option.value}>
                {option.label}
              </option>
            ))}
          </select>
        </label>
      </section>

      <div className="compat-forms">
        <MiniBirthForm title="나" subtitle="내 생년월일시" role="me" value={personA} onChange={setPersonA} />
        <MiniBirthForm title="상대" subtitle="상대방 생년월일시" role="partner" value={personB} onChange={setPersonB} />
      </div>

      <button className="btn btn--primary" onClick={handleCompute} disabled={!canSubmit}>
        궁합 보기
      </button>
      {error && <p className="error-text">{error}</p>}

      {result && (
        <div className="compat-result">
          <div className="card compat-score-card">
            <div>
              <span className="compat-score-card__eyebrow">{result.relationLabel ?? "관계"} 종합</span>
              <h3 className="compat-score-card__title">
                {result.score >= 75 ? "잘 맞는 흐름이 강한 관계" : result.score >= 55 ? "맞는 부분과 조율할 부분이 함께 있는 관계" : "거리와 기준을 맞춰야 하는 관계"}
              </h3>
              <p className="compat-summary">{result.summary}</p>
            </div>
            <div className="compat-score">
              <span className="compat-score__num">{result.score}</span>
              <span className="compat-score__unit">점</span>
            </div>
          </div>

          {result.people && (
            <div className="compat-people-grid">
              {result.people.map((p) => {
                const role = p.label === "나" ? "me" : "partner";
                return (
                <div className={`card compat-person compat-person--${role}`} key={p.label}>
                  <span className={`compat-role-badge compat-role-badge--${role}`}>{p.label}</span>
                  <p className="compat-person__pillars">
                    {p.pillars.year} / {p.pillars.month} / {p.pillars.day}
                    {p.pillars.hour ? ` / ${p.pillars.hour}` : " / 시주 모름"}
                  </p>
                  <div className="compat-person__traits">
                    <span>나를 뜻하는 글자 {p.dayMaster}</span>
                    <span>강한 힘: {p.strongestElement}</span>
                    <span>보완점: {p.weakestElement}</span>
                  </div>
                </div>
                );
              })}
            </div>
          )}

          {result.repairReport && (
            <section className={`card compat-repair compat-repair--${result.repairReport.level}`}>
              <span className="compat-score-card__eyebrow">관계 보완 리포트</span>
              <h3 className="card-title">{result.repairReport.headline}</h3>
              <p className="reading-body">{result.repairReport.intro}</p>

              <div className="compat-section-block">
                <h4>왜 이런 흐름이 생기는지</h4>
                <ul className="compat-list">
                  {result.repairReport.whyItHappens.map((item) => (
                    <li key={item}>{item}</li>
                  ))}
                </ul>
              </div>

              <div className="compat-section-block">
                <h4>갈등이 커지는 순서와 회복법</h4>
                <div className="compat-step-grid">
                  {result.repairReport.conflictCycle.map((step) => (
                    <article className="compat-step-card" key={step.step}>
                      <span>{step.step}</span>
                      <p>{step.body}</p>
                      <b>{step.repair}</b>
                    </article>
                  ))}
                </div>
              </div>

              <div className="compat-section-block">
                <h4>나와 상대를 구분해서 맞추는 법</h4>
                <div className="compat-person-advice">
                  <article>
                    <span className="compat-role-badge compat-role-badge--me">나</span>
                    <ul className="compat-list">
                      {result.repairReport.byPerson.me.map((item) => (
                        <li key={item}>{item}</li>
                      ))}
                    </ul>
                  </article>
                  <article>
                    <span className="compat-role-badge compat-role-badge--partner">상대</span>
                    <ul className="compat-list">
                      {result.repairReport.byPerson.partner.map((item) => (
                        <li key={item}>{item}</li>
                      ))}
                    </ul>
                  </article>
                  <article>
                    <span className="compat-role-badge">둘이 같이</span>
                    <ul className="compat-list">
                      {result.repairReport.byPerson.together.map((item) => (
                        <li key={item}>{item}</li>
                      ))}
                    </ul>
                  </article>
                </div>
              </div>

              <div className="compat-section-block">
                <h4>실제로 이렇게 말해보세요</h4>
                <div className="compat-script-list">
                  {result.repairReport.scripts.map((script) => (
                    <p key={script}>{script}</p>
                  ))}
                </div>
              </div>

              <section className="compat-inline-panel">
                <h4>하지 않는 편이 좋은 반응</h4>
                <ul className="compat-list">
                  {result.repairReport.avoid.map((item) => (
                    <li key={item}>{item}</li>
                  ))}
                </ul>
              </section>
            </section>
          )}

          {result.highlights && (
            <section className="card">
              <h3 className="card-title">{result.relationLabel ?? "관계"} 핵심 카드</h3>
              <div className="compat-highlight-grid">
                {result.highlights.map((h) => (
                  <article className="compat-highlight" key={h.title}>
                    <span>{h.title}</span>
                    <p>{h.body}</p>
                    <b>{h.action}</b>
                  </article>
                ))}
              </div>
            </section>
          )}

          {result.partnerPalace && (
            <section className="card compat-feature-card">
              <span className="compat-score-card__eyebrow">{result.relationLabel ?? "관계"} 자리</span>
              <h3 className="card-title">{result.partnerPalace.title}</h3>
              <p className="reading-body">{result.partnerPalace.body}</p>
            </section>
          )}

          {result.roleChemistry && (
            <section className="card">
              <h3 className="card-title">서로에게 어떤 존재로 느껴지는지</h3>
              <div className="compat-advice-grid">
                {result.roleChemistry.map((role) => (
                  <article className="compat-highlight" key={role.title}>
                    <span>{role.title}</span>
                    <p>{role.body}</p>
                  </article>
                ))}
              </div>
            </section>
          )}

          {result.purposeFits && (
            <section className="card">
              <h3 className="card-title">관계 목적별 궁합</h3>
              <div className="compat-deep-list">
                {result.purposeFits.map((fit) => (
                  <article className="compat-deep-item" key={fit.label}>
                    <Gauge label={fit.label} score={fit.score} comment={fit.comment} tierLabel={tierWord(fit.score)} />
                    {fit.detail && <p>{fit.detail}</p>}
                    {fit.signal && (
                      <p className="compat-signal">
                        <b>이럴 때 드러나요</b> {fit.signal}
                      </p>
                    )}
                    {fit.actions && (
                      <ul className="compat-list">
                        {fit.actions.map((action) => (
                          <li key={action}>{action}</li>
                        ))}
                      </ul>
                    )}
                  </article>
                ))}
              </div>
            </section>
          )}

          <div className="card">
            <h3 className="card-title">세부 흐름</h3>
            <div className="compat-deep-list">
              {result.breakdown.map((b) => (
                <article className="compat-deep-item" key={b.label}>
                  <Gauge label={b.label} score={b.score} comment={b.note} tierLabel={tierWord(b.score)} />
                  {b.detail && <p>{b.detail}</p>}
                  {b.signal && (
                    <p className="compat-signal">
                      <b>이럴 때 드러나요</b> {b.signal}
                    </p>
                  )}
                  {b.actions && (
                    <ul className="compat-list">
                      {b.actions.map((action) => (
                        <li key={action}>{action}</li>
                      ))}
                    </ul>
                  )}
                </article>
              ))}
            </div>
          </div>

          {result.timing && (
            <section className="card">
              <h3 className="card-title">시기 흐름</h3>
              <div className="compat-advice-grid">
                {result.timing.map((t) => (
                  <article className="compat-highlight" key={t.label}>
                    <span>{t.label}</span>
                    <p>{t.body}</p>
                    <b>{t.evidence}</b>
                  </article>
                ))}
              </div>
            </section>
          )}

          {(result.cautionPoints || result.actionPlan) && (
            <div className="compat-advice-grid">
              {result.cautionPoints && (
                <section className="card">
                  <h3 className="card-title">조심할 반복 패턴</h3>
                  <ul className="compat-list">
                    {result.cautionPoints.map((item) => (
                      <li key={item}>{item}</li>
                    ))}
                  </ul>
                </section>
              )}
              {result.actionPlan && (
                <section className="card">
                  <h3 className="card-title">오래 가는 운영법</h3>
                  <ul className="compat-list">
                    {result.actionPlan.map((item) => (
                      <li key={item}>{item}</li>
                    ))}
                  </ul>
                </section>
              )}
            </div>
          )}

          {result.improvementTips && (
            <section className="card compat-feature-card">
              <h3 className="card-title">개선할 수 있는 방향</h3>
              <ul className="compat-list">
                {result.improvementTips.map((item) => (
                  <li key={item}>{item}</li>
                ))}
              </ul>
            </section>
          )}

          {result.expertEvidence && (
            <details className="card evidence-details">
              <summary>전문가 근거 보기</summary>
              <ul className="compat-list">
                {result.expertEvidence.map((item) => (
                  <li key={item}>{item}</li>
                ))}
              </ul>
            </details>
          )}
        </div>
      )}

      <p className="fortune-disclaimer">
        본 궁합은 결정론적 계산에 기반한 참고용입니다. 관계의 실제 모습은 두 사람의 노력과 선택에 달려 있어요.
      </p>
    </section>
  );
}
