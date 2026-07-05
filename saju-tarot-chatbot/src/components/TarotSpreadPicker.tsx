import { useMemo, useState, type FormEvent } from "react";
import { SHUFFLES, SHUFFLE_IDS, SPREADS, SPREAD_IDS, type ShuffleId, type SpreadId } from "../lib/tarot";
import type { ReadingContext } from "../types";

interface Props {
  submitLabel: string;
  onSubmit: (question: string, spreadId: SpreadId, shuffleId: ShuffleId, pickedSlots: number[], context: ReadingContext) => void;
  loading: boolean;
}

function recommendedSpreadFor(question: string): SpreadId {
  const compact = question.replace(/\s+/g, "");
  if (/연애|관계|상대|마음|속마음|재회|이별|결혼|좋아|연락/.test(compact)) return "relation";
  if (/A\)|B\)|A\.|B\.|비교|선택|둘중|둘 중|어느|퇴사|이직|고백|시작|그만|계속|정리|말까|할까/.test(question)) return "ab";
  if (/이번달|한달|월간|흐름|7월|8월|9월|10월|11월|12월/.test(compact)) return "month";
  if (/왜|문제|막히|답답|해결|어떻게|조언/.test(compact)) return "soa";
  if (/자세|깊게|정밀|복잡|중요/.test(compact)) return "five";
  return "ppf";
}

export default function TarotSpreadPicker({ submitLabel, onSubmit, loading }: Props) {
  const [question, setQuestion] = useState("");
  const [spreadId, setSpreadId] = useState<SpreadId>("ppf");
  const [manualSpread, setManualSpread] = useState(false);
  const [shuffleId, setShuffleId] = useState<ShuffleId>("classic");
  const [pickMode, setPickMode] = useState<"auto" | "manual">("auto");
  const [pickedSlots, setPickedSlots] = useState<number[]>([]);
  const recommendedSpread = useMemo(() => recommendedSpreadFor(question), [question]);
  const activeSpreadId = manualSpread ? spreadId : recommendedSpread;
  const activeSpread = SPREADS[activeSpreadId];
  const needCount = activeSpread.positions.length;
  const readyToSubmit = question.trim() && (pickMode === "auto" || pickedSlots.length === needCount);

  function changeSpread(next: SpreadId) {
    setSpreadId(next);
    setManualSpread(true);
    setPickedSlots([]);
  }

  function useRecommendedSpread() {
    setManualSpread(false);
    setPickedSlots([]);
  }

  function toggleSlot(slot: number) {
    setPickedSlots((prev) => {
      if (prev.includes(slot)) return prev.filter((item) => item !== slot);
      if (prev.length >= needCount) return prev;
      return [...prev, slot];
    });
  }

  function handleSubmit(e: FormEvent) {
    e.preventDefault();
    if (loading) return;
    const context: ReadingContext = {};
    onSubmit(question, activeSpreadId, shuffleId, pickMode === "manual" ? pickedSlots : [], context);
  }

  return (
    <form className="card form" onSubmit={handleSubmit}>
      <div className="field-row field-row--column">
        <span className="field-label">질문</span>
        <textarea
          placeholder={
            activeSpreadId === "ab"
              ? "예: A) 지금 회사에 남기 vs B) 이직하기 — 어느 쪽이 나을까요?"
              : "예: 지금 이 관계, 계속 이어가도 될까요?"
          }
          value={question}
          onChange={(e) => setQuestion(e.target.value)}
          rows={3}
          required
        />
      </div>

      <section className="tarot-recommended-spread">
        <span className="feature-badge">질문 기준 추천 배열</span>
        <div>
          <h3>{activeSpread.label}</h3>
          <p>{activeSpread.desc}</p>
          <div className="tarot-position-preview">
            {activeSpread.positions.map((position, index) => (
              <span key={position}>
                {index + 1}. {position}
              </span>
            ))}
          </div>
        </div>
        {manualSpread && (
          <button type="button" className="btn btn--ghost" onClick={useRecommendedSpread}>
            질문 기준 추천으로 되돌리기
          </button>
        )}
      </section>

      <details className="consultation-panel optional-settings-panel">
        <summary>
          <span>다른 배열이나 뽑기 방식을 고르고 싶을 때</span>
          <small>그냥 두면 질문에 맞는 배열로 자동 선택합니다.</small>
        </summary>

        <div className="field-row field-row--column">
          <span className="field-label">카드 배열</span>
          <div className="spread-choice-grid">
            {SPREAD_IDS.map((id) => (
              <button
                type="button"
                key={id}
                className={activeSpreadId === id ? "spread-choice spread-choice--active" : "spread-choice"}
                onClick={() => changeSpread(id)}
              >
                <b>{SPREADS[id].shortLabel ?? SPREADS[id].label}</b>
                <span>{SPREADS[id].desc}</span>
              </button>
            ))}
          </div>
          {activeSpreadId === "ab" && <span className="field-hint">질문에 선택지 A와 B를 함께 적어주세요.</span>}
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
              <div className="tarot-pick-board" aria-label={`카드 ${needCount}장 선택`}>
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
                {needCount}장 중 {pickedSlots.length}장을 골랐어요. 고른 순서대로 스프레드 자리에 놓입니다.
              </span>
            </>
          )}
        </div>
      </details>

      <button type="submit" className="btn btn--primary" disabled={loading || !readyToSubmit}>
        {loading ? "카드를 해석하는 중..." : submitLabel}
      </button>
    </form>
  );
}
