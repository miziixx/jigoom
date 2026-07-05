import TarotSpreadPicker from "../components/TarotSpreadPicker";
import LoadingNotice from "../components/LoadingNotice";
import ReadingResult from "../components/ReadingResult";
import ChatFollowUp from "../components/ChatFollowUp";
import ReadingActions from "../components/ReadingActions";
import FeedbackBar from "../components/FeedbackBar";
import KeywordCloud from "../components/KeywordCloud";
import { useReadingStore } from "../store/useReadingStore";
import { drawSpread, SHUFFLES, SPREADS, type ShuffleId, type SpreadId } from "../lib/tarot";
import type { ReadingContext } from "../types";

export default function TarotPage() {
  const { currentSession, loading, error, startReading, sendFollowUp, clearCurrentSession } = useReadingStore();
  const showResult = currentSession?.type === "tarot";

  function handleSubmit(question: string, spreadId: SpreadId, shuffleId: ShuffleId, pickedSlots: number[], context: ReadingContext) {
    const tarotCards = drawSpread(spreadId, shuffleId, pickedSlots);
    const pickNote = pickedSlots.length
      ? `직접 고르기: 사용자가 펼쳐진 카드 중 ${pickedSlots.length}장을 고른 순서대로 배치했습니다.`
      : "";
    const spreadNote = [SPREADS[spreadId].note, SHUFFLES[shuffleId].note, pickNote].filter(Boolean).join("\n");
    startReading({ type: "tarot", question, context, tarotCards, spreadNote });
  }

  return (
    <section className="page">
      <h2 className="page-title">타로 보기</h2>
      <p className="page-desc">질문을 입력하고 카드를 뽑으면, 카드 조합과 질문 맥락을 근거로 해석해드립니다.</p>

      {!showResult && <TarotSpreadPicker submitLabel="카드 뽑기" onSubmit={handleSubmit} loading={loading} />}
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
