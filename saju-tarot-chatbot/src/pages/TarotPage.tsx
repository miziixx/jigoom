import TarotSpreadPicker from "../components/TarotSpreadPicker";
import ReadingResult from "../components/ReadingResult";
import ChatFollowUp from "../components/ChatFollowUp";
import ReadingActions from "../components/ReadingActions";
import { useReadingStore } from "../store/useReadingStore";
import { drawCards, type SpreadSize } from "../lib/tarot";

export default function TarotPage() {
  const { currentSession, loading, error, startReading, sendFollowUp, clearCurrentSession } = useReadingStore();
  const showResult = currentSession?.type === "tarot";

  function handleSubmit(question: string, count: SpreadSize) {
    const tarotCards = drawCards(count);
    startReading({ type: "tarot", question, tarotCards });
  }

  return (
    <section className="page">
      <h2 className="page-title">타로 보기</h2>
      <p className="page-desc">질문을 입력하고 카드를 뽑으면, 카드 조합과 질문 맥락을 근거로 해석해드립니다.</p>

      {!showResult && <TarotSpreadPicker submitLabel="카드 뽑기" onSubmit={handleSubmit} loading={loading} />}
      {error && !showResult && <p className="error-text">{error}</p>}

      {showResult && currentSession && (
        <>
          <ReadingResult session={currentSession} />
          <ReadingActions session={currentSession} />
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
