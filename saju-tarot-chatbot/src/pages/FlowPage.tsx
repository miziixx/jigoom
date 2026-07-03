import BirthInfoForm from "../components/BirthInfoForm";
import LoadingNotice from "../components/LoadingNotice";
import ReadingResult from "../components/ReadingResult";
import ChatFollowUp from "../components/ChatFollowUp";
import ReadingActions from "../components/ReadingActions";
import FeedbackBar from "../components/FeedbackBar";
import { useReadingStore } from "../store/useReadingStore";
import type { BirthInfo, ReadingContext, ReadingFocus } from "../types";

export default function FlowPage() {
  const { currentSession, loading, error, startReading, sendFollowUp, clearCurrentSession } = useReadingStore();
  const showResult = currentSession?.type === "flow";

  function handleSubmit(birthInfo: BirthInfo, question: string, focus: ReadingFocus, context: ReadingContext) {
    startReading({ type: "flow", question, focus, context, birthInfo });
  }

  return (
    <section className="page">
      <h2 className="page-title">월간·연간 운 흐름</h2>
      <p className="page-desc">
        올해 12개월의 월운을 절기 기준으로 모두 계산해, 시도하기 쉬운 시기와 무리하면 손해가 커지는 시기를 흐름으로
        읽어드립니다. 대운·세운이라는 큰 배경 위에서 이번 달과 다음 달은 따로 자세히 짚습니다.
      </p>

      {!showResult && <BirthInfoForm submitLabel="올해 흐름 보기" onSubmit={handleSubmit} loading={loading} />}
      {!showResult && loading && <LoadingNotice />}
      {error && !showResult && <p className="error-text">{error}</p>}

      {showResult && currentSession && (
        <>
          <ReadingResult session={currentSession} loading={loading} />
          <ReadingActions session={currentSession} />
          <FeedbackBar session={currentSession} />
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
