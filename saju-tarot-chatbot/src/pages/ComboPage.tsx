import { useState, type FormEvent } from "react";
import ReadingResult from "../components/ReadingResult";
import ChatFollowUp from "../components/ChatFollowUp";
import ReadingActions from "../components/ReadingActions";
import FeedbackBar from "../components/FeedbackBar";
import FocusPicker from "../components/FocusPicker";
import ContextPicker from "../components/ContextPicker";
import { useReadingStore } from "../store/useReadingStore";
import { drawSpread, SPREADS, type SpreadId } from "../lib/tarot";
import { BIRTH_PLACES } from "../data/birthPlaces";
import type { BirthInfo, CalendarType, Gender, ReadingContext, ReadingFocus } from "../types";

const HOURS = Array.from({ length: 24 }, (_, h) => h);

// 통합 리딩에서 고를 수 있는 스프레드 (긴 배열은 통합 프롬프트가 과해져 제외)
const COMBO_SPREADS: SpreadId[] = ["one", "ppf", "soa", "five"];

export default function ComboPage() {
  const { currentSession, loading, error, startReading, sendFollowUp, clearCurrentSession } = useReadingStore();
  const showResult = currentSession?.type === "combo";

  const [calendarType, setCalendarType] = useState<CalendarType>("solar");
  const [year, setYear] = useState("");
  const [month, setMonth] = useState("");
  const [day, setDay] = useState("");
  const [hour, setHour] = useState<string>("unknown");
  const [minute, setMinute] = useState("");
  const [birthPlace, setBirthPlace] = useState("none");
  const [gender, setGender] = useState<Gender>("female");
  const [question, setQuestion] = useState("");
  const [spreadId, setSpreadId] = useState<SpreadId>("ppf");
  const [focus, setFocus] = useState<ReadingFocus>("general");
  const [context, setContext] = useState<ReadingContext>({});

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
      minute: minute === "" ? 0 : Number(minute),
      birthPlace,
      gender,
    };
    const finalContext: ReadingContext =
      hour === "unknown" ? { ...context, timeAccuracy: "unknown" } : context;
    const tarotCards = drawSpread(spreadId);
    startReading({
      type: "combo",
      question,
      focus,
      context: finalContext,
      birthInfo,
      tarotCards,
      spreadNote: SPREADS[spreadId].note,
    });
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
            {hour !== "unknown" && (
              <input
                type="number"
                placeholder="분"
                min={0}
                max={59}
                value={minute}
                onChange={(e) => setMinute(e.target.value)}
                aria-label="출생 분"
              />
            )}
          </div>

          <div className="field-row">
            <span className="field-label">출생지</span>
            <select value={birthPlace} onChange={(e) => setBirthPlace(e.target.value)}>
              <option value="none">보정 안 함</option>
              {Object.entries(BIRTH_PLACES).map(([key, place]) => (
                <option key={key} value={key}>
                  {place.label}
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

          <ContextPicker value={context} onChange={setContext} showTimeAccuracy={hour !== "unknown"} />

          <div className="field-row">
            <span className="field-label">타로 스프레드</span>
            {COMBO_SPREADS.map((id) => (
              <label key={id}>
                <input type="radio" name="spread" checked={spreadId === id} onChange={() => setSpreadId(id)} />
                {SPREADS[id].label}
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
          <ReadingActions session={currentSession} />
          <FeedbackBar session={currentSession} />
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
