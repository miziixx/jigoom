import BirthInfoForm from "../components/BirthInfoForm";
import LoadingNotice from "../components/LoadingNotice";
import ReadingResult from "../components/ReadingResult";
import ChatFollowUp from "../components/ChatFollowUp";
import ReadingActions from "../components/ReadingActions";
import FeedbackBar from "../components/FeedbackBar";
import KeywordCloud from "../components/KeywordCloud";
import { useReadingStore } from "../store/useReadingStore";
import type { BirthInfo, ReadingContext, ReadingFocus } from "../types";

export default function FlowPage() {
  const { currentSession, loading, error, startReading, sendFollowUp, clearCurrentSession } = useReadingStore();
  const showResult = currentSession?.type === "flow";

  function handleSubmit(
    birthInfo: BirthInfo,
    question: string,
    focus: ReadingFocus,
    context: ReadingContext,
    options?: { saveToHistory: boolean },
  ) {
    startReading({ type: "flow", question, focus, context, birthInfo, saveToHistory: options?.saveToHistory });
  }

  return (
    <section className="page">
      <h2 className="page-title">흐름 캘린더</h2>
      <p className="page-desc">
        올해 12개월 흐름을 절기 기준으로 계산해 캘린더처럼 먼저 보여드리고, 시도하기 쉬운 시기와 무리하면 손해가
        커지는 시기를 자세히 읽어드립니다. 큰 흐름 위에서 이번 달과 다음 달은 따로 깊게 짚습니다.
      </p>

      {!showResult && (
        <BirthInfoForm
          submitLabel="흐름 캘린더 보기"
          onSubmit={handleSubmit}
          loading={loading}
          showQuestionSection={false}
          expandOptionalSettings
        />
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
