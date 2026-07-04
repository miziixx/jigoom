import { useState } from "react";
import Gauge from "../components/Gauge";
import { computeCompatibility } from "../lib/saju";
import type { BirthInfo, CalendarType, CompatibilityResult, Gender } from "../types";

const HOURS = Array.from({ length: 24 }, (_, h) => h);

interface PersonInput {
  calendarType: CalendarType;
  year: string;
  month: string;
  day: string;
  hour: string;
  isLeapMonth: boolean;
  gender: Gender;
}

const EMPTY: PersonInput = {
  calendarType: "solar",
  year: "",
  month: "",
  day: "",
  hour: "unknown",
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
    minute: 0,
    isLeapMonth: p.calendarType === "lunar" ? p.isLeapMonth : undefined,
    gender: p.gender,
  };
}

function MiniBirthForm({ title, value, onChange }: { title: string; value: PersonInput; onChange: (p: PersonInput) => void }) {
  const set = (patch: Partial<PersonInput>) => onChange({ ...value, ...patch });
  return (
    <div className="card mini-birth">
      <h3 className="card-title">{title}</h3>
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
        <select value={value.hour} onChange={(e) => set({ hour: e.target.value })}>
          <option value="unknown">모름</option>
          {HOURS.map((h) => (
            <option key={h} value={h}>
              {h}시
            </option>
          ))}
        </select>
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
  const [result, setResult] = useState<CompatibilityResult | null>(null);
  const [error, setError] = useState<string | null>(null);

  const filled = (p: PersonInput) => p.year !== "" && p.month !== "" && p.day !== "";
  const canSubmit = filled(personA) && filled(personB);

  function handleCompute() {
    setError(null);
    try {
      setResult(computeCompatibility(toBirthInfo(personA), toBirthInfo(personB)));
    } catch {
      setError("궁합 계산에 실패했어요. 생년월일을 다시 확인해 주세요.");
    }
  }

  return (
    <section className="page">
      <h2 className="page-title">궁합 보기</h2>
      <p className="page-desc">두 사람의 사주 원국을 계산해 일간 관계·지지 인연(합충)·오행 보완을 종합한 궁합 점수를 보여드려요. (참고용)</p>

      <div className="compat-forms">
        <MiniBirthForm title="첫 번째 사람" value={personA} onChange={setPersonA} />
        <MiniBirthForm title="두 번째 사람" value={personB} onChange={setPersonB} />
      </div>

      <button className="btn btn--primary" onClick={handleCompute} disabled={!canSubmit}>
        궁합 보기
      </button>
      {error && <p className="error-text">{error}</p>}

      {result && (
        <div className="compat-result">
          <div className="card compat-score-card">
            <div>
              <span className="compat-score-card__eyebrow">관계 종합</span>
              <h3 className="compat-score-card__title">{result.score >= 75 ? "끌림과 보완이 강한 관계" : result.score >= 55 ? "맞는 부분과 조율할 부분이 함께 있는 관계" : "속도와 기준을 맞춰야 하는 관계"}</h3>
              <p className="compat-summary">{result.summary}</p>
            </div>
            <div className="compat-score">
              <span className="compat-score__num">{result.score}</span>
              <span className="compat-score__unit">점</span>
            </div>
          </div>

          {result.people && (
            <div className="compat-people-grid">
              {result.people.map((p) => (
                <div className="card compat-person" key={p.label}>
                  <h3 className="card-title">{p.label}</h3>
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
              ))}
            </div>
          )}

          {result.highlights && (
            <section className="card">
              <h3 className="card-title">관계 핵심 카드</h3>
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

          <div className="card">
            <h3 className="card-title">세부 흐름</h3>
            <div className="gauge-list">
              {result.breakdown.map((b) => (
                <Gauge key={b.label} label={b.label} score={b.score} comment={b.note} />
              ))}
            </div>
          </div>

          <div className="card">
            <h3 className="card-title">근거</h3>
            <p className="reading-body">
              <b>두 사람의 기질</b> — {result.dayMasterRelation}
            </p>
            <p className="reading-body">
              <b>함께 있을 때 흐름</b> — {result.branchRelations.length > 0 ? result.branchRelations.join(", ") : "크게 부딪히거나 붙는 부분 없이 무난해요"}
            </p>
            <p className="reading-body">
              <b>서로 채워주는 부분</b> — {result.elementComplement}
            </p>
          </div>

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
        </div>
      )}

      <p className="fortune-disclaimer">
        본 궁합은 결정론적 계산에 기반한 참고용입니다. 관계의 실제 모습은 두 사람의 노력과 선택에 달려 있어요.
      </p>
    </section>
  );
}
