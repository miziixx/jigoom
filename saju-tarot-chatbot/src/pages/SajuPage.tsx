import BirthInfoForm from "../components/BirthInfoForm";
import LoadingNotice from "../components/LoadingNotice";
import ReadingResult from "../components/ReadingResult";
import ChatFollowUp from "../components/ChatFollowUp";
import ReadingActions from "../components/ReadingActions";
import FeedbackBar from "../components/FeedbackBar";
import KeywordCloud from "../components/KeywordCloud";
import { useReadingStore } from "../store/useReadingStore";
import type { BirthInfo, ReadingContext, ReadingFocus } from "../types";

export default function SajuPage() {
  const { currentSession, loading, error, startReading, sendFollowUp, clearCurrentSession } = useReadingStore();
  const showResult = currentSession?.type === "saju";

  function handleSubmit(
    birthInfo: BirthInfo,
    question: string,
    focus: ReadingFocus,
    context: ReadingContext,
    options?: { saveToHistory: boolean },
  ) {
    startReading({ type: "saju", question, focus, context, birthInfo, saveToHistory: options?.saveToHistory });
  }

  return (
    <section className="page">
      <h2 className="page-title">사주 보기</h2>
      <p className="page-desc">생년월일시를 입력하면 실제 만세력 계산으로 사주 원국을 뽑고, 근거를 밝히며 해석해드립니다.</p>

      {!showResult && <BirthInfoForm submitLabel="사주 보기" onSubmit={handleSubmit} loading={loading} />}
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
