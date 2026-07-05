import { useState, type FormEvent } from "react";
import ContextPicker from "./ContextPicker";
import { SHUFFLES, SHUFFLE_IDS, SPREADS, SPREAD_IDS, type ShuffleId, type SpreadId } from "../lib/tarot";
import type { ReadingContext } from "../types";

interface Props {
  submitLabel: string;
  onSubmit: (question: string, spreadId: SpreadId, shuffleId: ShuffleId, pickedSlots: number[], context: ReadingContext) => void;
  loading: boolean;
}

export default function TarotSpreadPicker({ submitLabel, onSubmit, loading }: Props) {
  const [question, setQuestion] = useState("");
  const [spreadId, setSpreadId] = useState<SpreadId>("ppf");
  const [shuffleId, setShuffleId] = useState<ShuffleId>("classic");
  const [pickMode, setPickMode] = useState<"auto" | "manual">("auto");
  const [pickedSlots, setPickedSlots] = useState<number[]>([]);
  const [context, setContext] = useState<ReadingContext>({});
  const needCount = SPREADS[spreadId].positions.length;
  const readyToSubmit = question.trim() && (pickMode === "auto" || pickedSlots.length === needCount);

  function changeSpread(next: SpreadId) {
    setSpreadId(next);
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
    onSubmit(question, spreadId, shuffleId, pickMode === "manual" ? pickedSlots : [], context);
  }

  return (
    <form className="card form" onSubmit={handleSubmit}>
      <div className="field-row field-row--column">
        <span className="field-label">질문</span>
        <textarea
          placeholder={
            spreadId === "ab"
              ? "예: A) 지금 회사에 남기 vs B) 이직하기 — 어느 쪽이 나을까요?"
              : "예: 지금 이 관계, 계속 이어가도 될까요?"
          }
          value={question}
          onChange={(e) => setQuestion(e.target.value)}
          rows={3}
          required
        />
      </div>

      <details className="consultation-panel optional-settings-panel">
        <summary>
          <span>카드 뽑기 방식을 직접 정하고 싶을 때</span>
          <small>그냥 두면 질문에 맞춰 기본 3장 리딩으로 봅니다.</small>
        </summary>

        <div className="field-row field-row--column">
          <span className="field-label">스프레드</span>
          <div className="spread-choice-grid">
            {SPREAD_IDS.map((id) => (
              <button
                type="button"
                key={id}
                className={spreadId === id ? "spread-choice spread-choice--active" : "spread-choice"}
                onClick={() => changeSpread(id)}
              >
                {SPREADS[id].label}
              </button>
            ))}
          </div>
          {spreadId === "ab" && <span className="field-hint">질문에 선택지 A와 B를 함께 적어주세요.</span>}
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

      <ContextPicker value={context} onChange={setContext} />

      <button type="submit" className="btn btn--primary" disabled={loading || !readyToSubmit}>
        {loading ? "카드를 해석하는 중..." : submitLabel}
      </button>
    </form>
  );
}
