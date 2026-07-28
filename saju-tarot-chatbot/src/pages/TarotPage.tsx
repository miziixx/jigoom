import { useState } from "react";
import TarotSpreadPicker from "../components/TarotSpreadPicker";
import TarotShuffleStage from "../components/TarotShuffleStage";
import TarotPickBoard from "../components/TarotPickBoard";
import TarotRevealStage from "../components/TarotRevealStage";
import LoadingNotice from "../components/LoadingNotice";
import ReadingResult from "../components/ReadingResult";
import ChatFollowUp from "../components/ChatFollowUp";
import ReadingActions from "../components/ReadingActions";
import FeedbackBar from "../components/FeedbackBar";
import KeywordCloud from "../components/KeywordCloud";
import { useReadingStore } from "../store/useReadingStore";
import { drawSpread, SHUFFLES, SPREADS, type ShuffleId, type SpreadId } from "../lib/tarot";
import type { DrawnTarotCard, ReadingContext } from "../types";

type Stage = "ask" | "shuffle" | "pick" | "reveal" | "reading";

interface Draft {
  question: string;
  spreadId: SpreadId;
  shuffleId: ShuffleId;
  context: ReadingContext;
}

/**
 * 타로 여정 상태 머신: ask → shuffle → pick → reveal → reading.
 * 카드는 pick 단계에서 고른 순서(slots)로 drawSpread를 통해 확정되며,
 * reveal에서 공개된 그 카드가 그대로 startReading에 전달된다(랜덤 재추첨 없음).
 */
export default function TarotPage() {
  const { currentSession, loading, error, startReading, sendFollowUp, clearCurrentSession } = useReadingStore();
  const alreadyHasReading = currentSession?.type === "tarot";
  const [stage, setStage] = useState<Stage>(alreadyHasReading ? "reading" : "ask");
  const [draft, setDraft] = useState<Draft | null>(null);
  const [drawn, setDrawn] = useState<DrawnTarotCard[]>([]);

  function handleAsk(question: string, spreadId: SpreadId, shuffleId: ShuffleId, context: ReadingContext) {
    setDraft({ question, spreadId, shuffleId, context });
    setStage("shuffle");
  }

  function handlePicked(pickedSlots: number[]) {
    if (!draft) return;
    setDrawn(drawSpread(draft.spreadId, draft.shuffleId, pickedSlots));
    setStage("reveal");
  }

  function handleRevealDone() {
    if (!draft || drawn.length === 0) return;
    const pickNote = `직접 고르기: 사용자가 펼쳐진 카드 중 ${drawn.length}장을 고른 순서대로 배치했습니다.`;
    const spreadNote = [SPREADS[draft.spreadId].note, SHUFFLES[draft.shuffleId].note, pickNote]
      .filter(Boolean)
      .join("\n");
    startReading({ type: "tarot", question: draft.question, context: draft.context, tarotCards: drawn, spreadNote });
    setStage("reading");
  }

  function reset() {
    clearCurrentSession();
    setDraft(null);
    setDrawn([]);
    setStage("ask");
  }

  const needCount = draft ? SPREADS[draft.spreadId].positions.length : 0;

  return (
    <section className="page">
      <h2 className="page-title">타로 보기</h2>
      <p className="page-desc">질문을 떠올리고, 직접 카드를 섞고 골라 뽑은 카드로 해석해드립니다.</p>

      {stage === "ask" && <TarotSpreadPicker submitLabel="카드 뽑기 시작" onSubmit={handleAsk} loading={loading} />}

      {stage === "shuffle" && draft && (
        <TarotShuffleStage shuffleId={draft.shuffleId} onStop={() => setStage("pick")} />
      )}

      {stage === "pick" && draft && <TarotPickBoard needCount={needCount} onComplete={handlePicked} />}

      {stage === "reveal" && <TarotRevealStage cards={drawn} onDone={handleRevealDone} />}

      {error && stage !== "reading" && <p className="error-text">{error}</p>}

      {stage === "reading" && currentSession && (
        <>
          <ReadingResult session={currentSession} loading={loading} />
          <ReadingActions session={currentSession} />
          <FeedbackBar session={currentSession} />
          <KeywordCloud session={currentSession} />
          <ChatFollowUp session={currentSession} onSend={sendFollowUp} loading={loading} />
          {error && <p className="error-text">{error}</p>}
          <button className="btn btn--ghost" onClick={reset}>
            새로 보기
          </button>
        </>
      )}

      {stage === "reading" && !currentSession && loading && <LoadingNotice />}
    </section>
  );
}
