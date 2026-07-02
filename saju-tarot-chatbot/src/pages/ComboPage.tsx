import { useState, type FormEvent } from "react";
import ReadingResult from "../components/ReadingResult";
import ChatFollowUp from "../components/ChatFollowUp";
import FocusPicker from "../components/FocusPicker";
import { useReadingStore } from "../store/useReadingStore";
import { drawCards, SPREAD_LABEL, type SpreadSize } from "../lib/tarot";
import type { BirthInfo, CalendarType, Gender, ReadingFocus } from "../types";

const HOURS = Array.from({ length: 24 }, (_, h) => h);

export default function ComboPage() {
  const { currentSession, loading, error, startReading, sendFollowUp, clearCurrentSession } = useReadingStore();
  const showResult = currentSession?.type === "combo";

  const [calendarType, setCalendarType] = useState<CalendarType>("solar");
  const [year, setYear] = useState("");
  const [month, setMonth] = useState("");
  const [day, setDay] = useState("");
  const [hour, setHour] = useState<string>("unknown");
  const [gender, setGender] = useState<Gender>("female");
  const [question, setQuestion] = useState("");
  const [count, setCount] = useState<SpreadSize>(3);
  const [focus, setFocus] = useState<ReadingFocus>("general");

  const canSubmit = year !== "" && month !== "" && day !== "" && question.trim() !== "" && !loading;

  function handleSubmit(e: FormEvent) {
    e.preventDefault();
    if (!canSubmit) return;
    const birthInfo: BirthInfo = {
      calendarType,
      year: Number(year),
      month: Number(month),
      day: Number(day),
      hour: hour === "unknown" ? null : Number(hour),
      gender,
    };
    const tarotCards = drawCards(count);
    startReading({ type: "combo", question, focus, birthInfo, tarotCards });
  }

  return (
    <section className="page">
      <h2 className="page-title">사주 + 타로 통합 보기</h2>
      <p className="page-desc">
        사주는 타고난 성향과 장기 흐름을, 타로는 지금 이 질문에 대한 단기 흐름을 알려줍니다. 두 해석이 다른
        방향을 가리키면 각각 구분해서 설명해드립니다.
      </p>

      {!showResult && (
        <form className="card form" onSubmit={handleSubmit}>
          <div className="field-row">
            <span className="field-label">달력</span>
            <label>
              <input type="radio" checked={calendarType === "solar"} onChange={() => setCalendarType("solar")} />
              양력
            </label>
            <label>
              <input type="radio" checked={calendarType === "lunar"} onChange={() => setCalendarType("lunar")} />
              음력
            </label>
          </div>

          <div className="field-row">
            <span className="field-label">생년월일</span>
            <input type="number" placeholder="년" value={year} onChange={(e) => setYear(e.target.value)} required />
            <input type="number" placeholder="월" min={1} max={12} value={month} onChange={(e) => setMonth(e.target.value)} required />
            <input type="number" placeholder="일" min={1} max={31} value={day} onChange={(e) => setDay(e.target.value)} required />
          </div>

          <div className="field-row">
            <span className="field-label">출생 시간</span>
            <select value={hour} onChange={(e) => setHour(e.target.value)}>
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
              <input type="radio" checked={gender === "female"} onChange={() => setGender("female")} />
              여성
            </label>
            <label>
              <input type="radio" checked={gender === "male"} onChange={() => setGender("male")} />
              남성
            </label>
          </div>

          <div className="field-row field-row--column">
            <span className="field-label">질문</span>
            <textarea
              placeholder="예: 지금 이직을 고민 중인데, 지금이 맞는 시기일까요?"
              value={question}
              onChange={(e) => setQuestion(e.target.value)}
              rows={3}
              required
            />
          </div>

          <FocusPicker value={focus} onChange={setFocus} />

          <div className="field-row">
            <span className="field-label">타로 스프레드</span>
            {([1, 3, 5] as SpreadSize[]).map((size) => (
              <label key={size}>
                <input type="radio" name="spread" checked={count === size} onChange={() => setCount(size)} />
                {SPREAD_LABEL[size]}
              </label>
            ))}
          </div>

          <button type="submit" className="btn btn--primary" disabled={!canSubmit}>
            {loading ? "리딩 생성 중..." : "통합 리딩 보기"}
          </button>
        </form>
      )}
      {error && !showResult && <p className="error-text">{error}</p>}

      {showResult && currentSession && (
        <>
          <ReadingResult session={currentSession} />
          <ChatFollowUp session={currentSession} onSend={sendFollowUp} loading={loading} />
          {error && <p className="error-text">{error}</p>}
          <button className="btn btn--ghost" onClick={clearCurrentSession}>
            새로 보기
          </button>
        </>
      )}
    </section>
  );
}
