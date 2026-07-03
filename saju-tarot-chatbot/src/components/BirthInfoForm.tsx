import { useState, type FormEvent } from "react";
import ContextPicker from "./ContextPicker";
import FocusPicker from "./FocusPicker";
import { BIRTH_PLACES } from "../data/birthPlaces";
import type { BirthInfo, CalendarType, Gender, LateNightZiMode, ReadingContext, ReadingFocus } from "../types";

interface Props {
  submitLabel: string;
  onSubmit: (birthInfo: BirthInfo, question: string, focus: ReadingFocus, context: ReadingContext) => void;
  loading: boolean;
  /** 오늘의 흐름 등 포커스 선택이 무의미한 리딩에서는 숨긴다 */
  showFocus?: boolean;
}

const HOURS = Array.from({ length: 24 }, (_, h) => h);

export default function BirthInfoForm({ submitLabel, onSubmit, loading, showFocus = true }: Props) {
  const [calendarType, setCalendarType] = useState<CalendarType>("solar");
  const [displayName, setDisplayName] = useState("");
  const [year, setYear] = useState("");
  const [month, setMonth] = useState("");
  const [day, setDay] = useState("");
  const [hour, setHour] = useState<string>("unknown");
  const [minute, setMinute] = useState("");
  const [isLeapMonth, setIsLeapMonth] = useState(false);
  const [lateNightZi, setLateNightZi] = useState<LateNightZiMode>("late");
  const [birthPlace, setBirthPlace] = useState("none");
  const [gender, setGender] = useState<Gender>("female");
  const [question, setQuestion] = useState("");
  const [focus, setFocus] = useState<ReadingFocus>("general");
  const [context, setContext] = useState<ReadingContext>({});

  const canSubmit = year !== "" && month !== "" && day !== "" && !loading;

  function handleSubmit(e: FormEvent) {
    e.preventDefault();
    if (!canSubmit) return;
    const hourNum = hour === "unknown" ? null : Number(hour);
    const birthInfo: BirthInfo = {
      displayName: displayName.trim() || undefined,
      calendarType,
      year: Number(year),
      month: Number(month),
      day: Number(day),
      hour: hourNum,
      minute: minute === "" ? 0 : Number(minute),
      isLeapMonth: calendarType === "lunar" ? isLeapMonth : undefined,
      lateNightZi: hourNum === 23 ? lateNightZi : undefined,
      birthPlace,
      gender,
    };
    // 출생 시간을 모르면 정확도 응답과 무관하게 "모름"으로 고정한다
    const finalContext: ReadingContext =
      hour === "unknown" ? { ...context, timeAccuracy: "unknown" } : context;
    onSubmit(birthInfo, question, focus, finalContext);
  }

  return (
    <form className="card form" onSubmit={handleSubmit}>
      <div className="field-row">
        <label className="radio-group">
          <span className="field-label">달력</span>
          <span>
            <label>
              <input
                type="radio"
                name="calendarType"
                checked={calendarType === "solar"}
                onChange={() => setCalendarType("solar")}
              />
              양력
            </label>
            <label>
              <input
                type="radio"
                name="calendarType"
                checked={calendarType === "lunar"}
                onChange={() => setCalendarType("lunar")}
              />
              음력
            </label>
          </span>
        </label>
      </div>

      <div className="field-row">
        <span className="field-label">이름</span>
        <input type="text" placeholder="선택" value={displayName} onChange={(e) => setDisplayName(e.target.value)} />
        <span className="field-hint">결과지와 저장 파일에만 표시됩니다.</span>
      </div>

      <div className="field-row">
        <span className="field-label">생년월일</span>
        <input type="number" placeholder="년" value={year} onChange={(e) => setYear(e.target.value)} required />
        <input type="number" placeholder="월" min={1} max={12} value={month} onChange={(e) => setMonth(e.target.value)} required />
        <input type="number" placeholder="일" min={1} max={31} value={day} onChange={(e) => setDay(e.target.value)} required />
      </div>

      {calendarType === "lunar" && (
        <div className="field-row">
          <span className="field-label">윤달</span>
          <label className="checkbox-label">
            <input type="checkbox" checked={isLeapMonth} onChange={(e) => setIsLeapMonth(e.target.checked)} />
            이 달은 음력 윤달이에요
          </label>
          <span className="field-hint">해당 연도에 윤달이 있을 때만 체크하세요.</span>
        </div>
      )}

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
        <span className="field-hint">모르면 시주를 제외하고 해석합니다.</span>
      </div>

      {hour === "23" && (
        <div className="field-row">
          <span className="field-label">자시 처리</span>
          <select value={lateNightZi} onChange={(e) => setLateNightZi(e.target.value as LateNightZiMode)}>
            <option value="late">야자시 (당일 일주 유지)</option>
            <option value="early">조자시 (다음 날 일주로)</option>
          </select>
          <span className="field-hint">23~24시 출생은 관법에 따라 일주가 달라질 수 있어요. 보통 야자시(기본).</span>
        </div>
      )}

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
        <span className="field-hint">진태양시(경도) 보정에 사용합니다. 서머타임은 자동 반영.</span>
      </div>

      <div className="field-row">
        <span className="field-label">성별</span>
        <label>
          <input type="radio" name="gender" checked={gender === "female"} onChange={() => setGender("female")} />
          여성
        </label>
        <label>
          <input type="radio" name="gender" checked={gender === "male"} onChange={() => setGender("male")} />
          남성
        </label>
      </div>

      {showFocus && <FocusPicker value={focus} onChange={setFocus} />}

      <ContextPicker value={context} onChange={setContext} showTimeAccuracy={hour !== "unknown"} />

      <div className="field-row field-row--column">
        <span className="field-label">궁금한 점 (선택)</span>
        <textarea
          placeholder="예: 요즘 직장에서 방향을 못 잡겠어요. 어떻게 하면 좋을까요?"
          value={question}
          onChange={(e) => setQuestion(e.target.value)}
          rows={3}
        />
      </div>

      <button type="submit" className="btn btn--primary" disabled={!canSubmit}>
        {loading ? "리딩 생성 중..." : submitLabel}
      </button>
    </form>
  );
}
