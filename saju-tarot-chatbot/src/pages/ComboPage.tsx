import { useState, type FormEvent } from "react";
import { Link } from "react-router-dom";
import DepthChoice from "../components/DepthChoice";
import LoadingNotice from "../components/LoadingNotice";
import ReadingResult from "../components/ReadingResult";
import ChatFollowUp from "../components/ChatFollowUp";
import ReadingActions from "../components/ReadingActions";
import FeedbackBar from "../components/FeedbackBar";
import KeywordCloud from "../components/KeywordCloud";
import { useReadingStore } from "../store/useReadingStore";
import { drawSpread, SHUFFLES, SHUFFLE_IDS, SPREADS, type ShuffleId, type SpreadId } from "../lib/tarot";
import { BIRTH_PLACES } from "../data/birthPlaces";
import { clearProfile, loadProfile, saveProfile } from "../lib/profile";
import type { AnswerDepth, BirthInfo, CalendarType, Gender, LateNightZiMode, ReadingContext, ReadingFocus } from "../types";

const HOURS = Array.from({ length: 24 }, (_, h) => h);
const DEFAULT_READING_FOCUS: ReadingFocus = "general";

// 통합 리딩에서 고를 수 있는 스프레드 (긴 배열은 통합 프롬프트가 과해져 제외)
const COMBO_SPREADS: SpreadId[] = ["one", "ppf", "soa", "five"];

export default function ComboPage() {
  const { currentSession, loading, error, startReading, sendFollowUp, clearCurrentSession } = useReadingStore();
  const showResult = currentSession?.type === "combo";

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
  const [spreadId, setSpreadId] = useState<SpreadId>("ppf");
  const [shuffleId, setShuffleId] = useState<ShuffleId>("classic");
  const [pickMode, setPickMode] = useState<"auto" | "manual">("auto");
  const [pickedSlots, setPickedSlots] = useState<number[]>([]);
  const [depth, setDepth] = useState<AnswerDepth | undefined>(undefined);

  const neededCards = SPREADS[spreadId].positions.length;
  const canSubmit =
    year !== "" &&
    month !== "" &&
    day !== "" &&
    question.trim() !== "" &&
    (pickMode === "auto" || pickedSlots.length === neededCards) &&
    !loading;

  function changeSpread(next: SpreadId) {
    setSpreadId(next);
    setPickedSlots([]);
  }

  function toggleSlot(slot: number) {
    setPickedSlots((prev) => {
      if (prev.includes(slot)) return prev.filter((item) => item !== slot);
      if (prev.length >= neededCards) return prev;
      return [...prev, slot];
    });
  }

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
      isLeapMonth: calendarType === "lunar" ? isLeapMonth : undefined,
      lateNightZi: hour === "23" ? lateNightZi : undefined,
      birthPlace,
      gender,
    };
    if (saveBirthChart) saveProfile(birthInfo);
    else if (savedBirth) clearProfile();
    const finalContext: ReadingContext = {
      ...(hour === "unknown" ? { timeAccuracy: "unknown" as const } : {}),
      ...(depth ? { depth } : {}),
    };
    const manualSlots = pickMode === "manual" ? pickedSlots : [];
    const tarotCards = drawSpread(spreadId, shuffleId, manualSlots);
    const pickNote = manualSlots.length
      ? `직접 고르기: 사용자가 펼쳐진 카드 중 ${manualSlots.length}장을 고른 순서대로 배치했습니다.`
      : "";
    const spreadNote = [SPREADS[spreadId].note, SHUFFLES[shuffleId].note, pickNote].filter(Boolean).join("\n");
    startReading({
      type: "combo",
      question,
      focus: DEFAULT_READING_FOCUS,
      context: finalContext,
      birthInfo,
      tarotCards,
      spreadNote,
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
          <section className="form-section">
            <div className="form-section__head">
              <span>1</span>
              <div>
                <h3>사주 정보</h3>
                <p>장기 흐름과 타고난 구조를 계산합니다. 생년월일 원본은 AI에 직접 보내지 않습니다.</p>
              </div>
            </div>

            <div className="field-row">
              <label className="radio-group">
                <span className="field-label">달력</span>
                <span>
                  <label>
                    <input
                      type="radio"
                      name="comboCalendarType"
                      checked={calendarType === "solar"}
                      onChange={() => setCalendarType("solar")}
                    />
                    양력
                  </label>
                  <label>
                    <input
                      type="radio"
                      name="comboCalendarType"
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
              <span className={`field-hint${hour === "unknown" ? " field-hint--accent" : ""}`}>
                {hour === "unknown"
                  ? "시간을 알면 성격·연애·시기 해석이 훨씬 정확해집니다. 모르면 시주를 빼고 해석합니다."
                  : "분까지 정확할수록 좋아요. 애매하면 정각으로 두어도 됩니다."}
              </span>
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

            <section className="consultation-panel optional-settings-panel optional-settings-panel--open">
              <div className="optional-settings-panel__head">
                <span>선택 설정</span>
                <small>출생지를 알면 더 정밀하고, 몰라도 기본 해석은 가능합니다.</small>
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
            </section>

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
          </section>

          <section className="form-section">
            <div className="form-section__head">
              <span>2</span>
              <div>
                <h3>지금 고민</h3>
                <p>사주는 큰 흐름, 타로는 지금 질문의 단기 흐름을 맡습니다.</p>
              </div>
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

            <DepthChoice value={depth} onChange={setDepth} />
          </section>

          <section className="form-section">
            <div className="form-section__head">
              <span>3</span>
              <div>
                <h3>타로 카드</h3>
                <p>카드 배열은 지금 질문의 가까운 분위기와 선택 신호를 봅니다.</p>
              </div>
            </div>

            <section className="consultation-panel optional-settings-panel optional-settings-panel--open">
              <div className="optional-settings-panel__head">
                <span>카드 뽑기 방식을 직접 정하고 싶을 때</span>
                <small>그냥 두면 기본 3장 리딩으로 사주와 함께 봅니다.</small>
              </div>

              <div className="field-row">
                <span className="field-label">스프레드</span>
                {COMBO_SPREADS.map((id) => (
                  <label key={id}>
                    <input type="radio" name="spread" checked={spreadId === id} onChange={() => changeSpread(id)} />
                    {SPREADS[id].label}
                  </label>
                ))}
              </div>

              <div className="field-row field-row--column">
                <span className="field-label">셔플 방식</span>
                <div className="shuffle-options">
                  {SHUFFLE_IDS.map((id) => (
                    <button
                      key={id}
                      type="button"
                      className={shuffleId === id ? "shuffle-card shuffle-card--active" : "shuffle-card"}
                      onClick={() => setShuffleId(id)}
                    >
                      <b>{SHUFFLES[id].label}</b>
                      <span>{SHUFFLES[id].desc}</span>
                    </button>
                  ))}
                </div>
              </div>

              <div className="field-row field-row--column">
                <span className="field-label">카드 선택 방식</span>
                <div className="segmented tarot-pick-toggle">
                  <button
                    type="button"
                    className={pickMode === "auto" ? "segmented__item segmented__item--active" : "segmented__item"}
                    onClick={() => setPickMode("auto")}
                  >
                    자동 뽑기
                  </button>
                  <button
                    type="button"
                    className={pickMode === "manual" ? "segmented__item segmented__item--active" : "segmented__item"}
                    onClick={() => setPickMode("manual")}
                  >
                    직접 고르기
                  </button>
                </div>
                {pickMode === "manual" && (
                  <>
                    <div className="tarot-pick-board" aria-label={`카드 ${neededCards}장 선택`}>
                      {Array.from({ length: 18 }, (_, slot) => {
                        const order = pickedSlots.indexOf(slot);
                        const picked = order >= 0;
                        return (
                          <button
                            key={slot}
                            type="button"
                            className={picked ? "tarot-pick-card tarot-pick-card--picked" : "tarot-pick-card"}
                            onClick={() => toggleSlot(slot)}
                            aria-pressed={picked}
                          >
                            <span>{picked ? order + 1 : "✦"}</span>
                          </button>
                        );
                      })}
                    </div>
                    <span className="field-hint">
                      {neededCards}장 중 {pickedSlots.length}장을 골랐어요. 고른 순서대로 통합 리딩에 반영됩니다.
                    </span>
                  </>
                )}
              </div>
            </section>
          </section>

          <p className="privacy-note">
            리딩 기록은 자동 저장되지 않습니다. 생년월일 원본은 해석 문장 생성에 직접 보내지 않고, 계산된 사주 정보와 질문만 사용합니다.{" "}
            <Link to="/privacy">자세한 개인정보 안내</Link>
          </p>

          <button type="submit" className="btn btn--primary" disabled={!canSubmit}>
            {loading ? "리딩 생성 중..." : "통합 리딩 보기"}
          </button>
        </form>
      )}
      {!showResult && loading && <LoadingNotice />}
      {error && !showResult && <p className="error-text">{error}</p>}

      {showResult && currentSession && (
        <>
          <ReadingResult session={currentSession} loading={loading} />
          <ReadingActions session={currentSession} />
          <FeedbackBar session={currentSession} />
          <KeywordCloud session={currentSession} />
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
