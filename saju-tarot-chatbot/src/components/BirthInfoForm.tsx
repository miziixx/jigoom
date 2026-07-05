import { useState, type FormEvent } from "react";
import { Link } from "react-router-dom";
import { BIRTH_PLACES } from "../data/birthPlaces";
import { clearProfile, loadProfile, saveProfile } from "../lib/profile";
import type { BirthInfo, CalendarType, Gender, LateNightZiMode, ReadingContext, ReadingFocus } from "../types";

interface Props {
  submitLabel: string;
  onSubmit: (
    birthInfo: BirthInfo,
    question: string,
    focus: ReadingFocus,
    context: ReadingContext,
    options?: { saveToHistory: boolean },
  ) => void;
  loading: boolean;
  /** 오늘의 흐름 등 포커스 선택이 무의미한 리딩에서는 숨긴다 */
  showFocus?: boolean;
  /** 작명처럼 고민 질문 입력이 필요 없는 화면에서는 상담 섹션 전체를 숨긴다 */
  showQuestionSection?: boolean;
  /** 흐름 캘린더처럼 출생지/저장 설정을 바로 보여줘야 하는 화면에서만 접힘을 해제한다 */
  expandOptionalSettings?: boolean;
}

const DEFAULT_READING_FOCUS: ReadingFocus = "general";
const HOURS = Array.from({ length: 24 }, (_, h) => h);

export default function BirthInfoForm({ submitLabel, onSubmit, loading, showQuestionSection = true, expandOptionalSettings = false }: Props) {
  const [savedBirth] = useState(() => loadProfile());
  const [calendarType, setCalendarType] = useState<CalendarType>(savedBirth?.calendarType ?? "solar");
  const [year, setYear] = useState(savedBirth ? String(savedBirth.year) : "");
  const [month, setMonth] = useState(savedBirth ? String(savedBirth.month) : "");
  const [day, setDay] = useState(savedBirth ? String(savedBirth.day) : "");
  const [hour, setHour] = useState<string>(savedBirth?.hour === null || savedBirth?.hour === undefined ? "unknown" : String(savedBirth.hour));
  const [minute, setMinute] = useState(savedBirth?.minute ? String(savedBirth.minute) : "");
  const [isLeapMonth, setIsLeapMonth] = useState(Boolean(savedBirth?.isLeapMonth));
  const [lateNightZi, setLateNightZi] = useState<LateNightZiMode>(savedBirth?.lateNightZi ?? "late");
  const [birthPlace, setBirthPlace] = useState(savedBirth?.birthPlace ?? "none");
  const [saveBirthChart, setSaveBirthChart] = useState(Boolean(savedBirth));
  const [gender, setGender] = useState<Gender>(savedBirth?.gender ?? "female");
  const [question, setQuestion] = useState("");

  const canSubmit = year !== "" && month !== "" && day !== "" && !loading;

  function handleSubmit(e: FormEvent) {
    e.preventDefault();
    if (!canSubmit) return;
    const hourNum = hour === "unknown" ? null : Number(hour);
    const birthInfo: BirthInfo = {
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
    if (saveBirthChart) saveProfile(birthInfo);
    else if (savedBirth) clearProfile();
    // 출생 시간을 모르면 정확도 응답과 무관하게 "모름"으로 고정한다
    const finalContext: ReadingContext = hour === "unknown" ? { timeAccuracy: "unknown" } : {};
    onSubmit(birthInfo, question, DEFAULT_READING_FOCUS, finalContext, { saveToHistory: saveBirthChart });
  }

  return (
    <form className="card form" onSubmit={handleSubmit}>
      <section className="form-section">
        <div className="form-section__head">
          <span>1</span>
          <div>
            <h3>기본 정보</h3>
            <p>원국 계산에 필요한 정보예요. 생년월일 원본은 AI에 보내지 않습니다.</p>
          </div>
        </div>

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
          {hour === "unknown" ? (
            <span className="field-hint field-hint--accent">
              시간을 알면 성격·연애·시기 해석이 훨씬 정확해집니다. 모르면 시주를 빼고 해석하니, 가능하면
              주민등록 초본이나 부모님께 한 번 확인해보세요.
            </span>
          ) : (
            <span className="field-hint">분까지 정확할수록 좋아요. 애매하면 정각으로 두어도 됩니다.</span>
          )}
        </div>

        {hour === "23" && (
          <div className="field-row field-row--column">
            <span className="field-label">23:00 전후 기준</span>
            <select value={lateNightZi} onChange={(e) => setLateNightZi(e.target.value as LateNightZiMode)}>
              <option value="late">당일 기준 — 23:00~23:59도 입력한 날짜로 봄</option>
              <option value="early">다음날 기준 — 23:00~23:59부터 다음날로 봄</option>
            </select>
            <span className="field-hint field-hint--accent">
              23:00~23:59 출생은 만세력 기준에 따라 일주가 달라질 수 있어요. 기본값은 당일 기준이며,
              결과에서 다음날 기준과의 차이를 함께 보여드립니다.
            </span>
          </div>
        )}

        <section className={expandOptionalSettings ? "consultation-panel optional-settings-panel optional-settings-panel--open" : undefined}>
          {expandOptionalSettings ? (
            <div className="optional-settings-panel__head">
              <span>선택 설정</span>
              <small>출생지를 알면 더 정밀하고, 몰라도 기본 해석은 가능합니다.</small>
            </div>
          ) : (
            <details className="consultation-panel optional-settings-panel">
              <summary>
                <span>선택 설정</span>
                <small>출생지를 알면 더 정밀하고, 몰라도 기본 해석은 가능합니다.</small>
              </summary>
              <OptionalSettingsFields
                birthPlace={birthPlace}
                setBirthPlace={setBirthPlace}
                saveBirthChart={saveBirthChart}
                setSaveBirthChart={setSaveBirthChart}
              />
            </details>
          )}

          {expandOptionalSettings && (
            <OptionalSettingsFields
              birthPlace={birthPlace}
              setBirthPlace={setBirthPlace}
              saveBirthChart={saveBirthChart}
              setSaveBirthChart={setSaveBirthChart}
            />
          )}
        </section>

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
      </section>

      {showQuestionSection && (
        <section className="form-section">
          <div className="form-section__head">
            <span>2</span>
            <div>
              <h3>지금 보고 싶은 것</h3>
              <p>전반 운세를 봐도 되고, 실제 고민을 적으면 판단 기준을 더 먼저 보여드려요.</p>
            </div>
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
        </section>
      )}

      <p className="privacy-note">
        리딩 기록은 자동 저장되지 않습니다. 생년월일 원본은 해석 문장 생성에 직접 보내지 않고, 계산된 사주 정보와 질문만 사용합니다.{" "}
        <Link to="/privacy">자세한 개인정보 안내</Link>
      </p>

      <button type="submit" className="btn btn--primary" disabled={!canSubmit}>
        {loading ? "리딩 생성 중..." : submitLabel}
      </button>
    </form>
  );
}

function OptionalSettingsFields({
  birthPlace,
  setBirthPlace,
  saveBirthChart,
  setSaveBirthChart,
}: {
  birthPlace: string;
  setBirthPlace: (value: string) => void;
  saveBirthChart: boolean;
  setSaveBirthChart: (value: boolean) => void;
}) {
  return (
    <>
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
        <span className={`field-hint${birthPlace === "none" ? " field-hint--accent" : ""}`}>
          {birthPlace === "none"
            ? "출생지를 고르면 시주 경계 판단이 더 정밀해집니다. 모르면 비워둬도 기본 해석은 가능합니다."
            : "표준시·경도 차이를 반영합니다. 1987~1988년 한국 서머타임은 자동 반영돼요."}
        </span>
      </div>

      <div className="field-row field-row--column save-chart-setting">
        <label className="checkbox-label">
          <input type="checkbox" checked={saveBirthChart} onChange={(e) => setSaveBirthChart(e.target.checked)} />
          이 사주 원국을 이 기기에 저장하기
        </label>
        <span className="field-hint">
          저장하면 기록 페이지에도 남고, 오늘 운세와 다음 사주 조회에서 다시 입력하지 않고 쓸 수 있어요. 서버가 아니라 이 브라우저에만 저장됩니다.
        </span>
      </div>
    </>
  );
}
