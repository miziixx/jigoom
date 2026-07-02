import { useState, type FormEvent } from "react";
import type { BirthInfo, CalendarType, Gender } from "../types";

interface Props {
  submitLabel: string;
  onSubmit: (birthInfo: BirthInfo, question: string) => void;
  loading: boolean;
}

const HOURS = Array.from({ length: 24 }, (_, h) => h);

export default function BirthInfoForm({ submitLabel, onSubmit, loading }: Props) {
  const [calendarType, setCalendarType] = useState<CalendarType>("solar");
  const [year, setYear] = useState("");
  const [month, setMonth] = useState("");
  const [day, setDay] = useState("");
  const [hour, setHour] = useState<string>("unknown");
  const [gender, setGender] = useState<Gender>("female");
  const [question, setQuestion] = useState("");

  const canSubmit = year !== "" && month !== "" && day !== "" && !loading;

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
    onSubmit(birthInfo, question);
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
        <span className="field-hint">모르면 시주를 제외하고 해석합니다.</span>
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
