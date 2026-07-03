import BirthInfoForm from "../components/BirthInfoForm";
import LoadingNotice from "../components/LoadingNotice";
import ReadingResult from "../components/ReadingResult";
import ChatFollowUp from "../components/ChatFollowUp";
import ReadingActions from "../components/ReadingActions";
import FeedbackBar from "../components/FeedbackBar";
import { useReadingStore } from "../store/useReadingStore";
import type { BirthInfo, ReadingContext, ReadingFocus } from "../types";

export default function TodayPage() {
  const { currentSession, loading, error, startReading, sendFollowUp, clearCurrentSession } = useReadingStore();
  const showResult = currentSession?.type === "today";

  function handleSubmit(birthInfo: BirthInfo, question: string, _focus: ReadingFocus, context: ReadingContext) {
    startReading({ type: "today", question, context, birthInfo });
  }

  return (
    <section className="page">
      <h2 className="page-title">오늘의 흐름</h2>
      <p className="page-desc">
        오늘 일진과 이번 달 월운이 내 사주 원국과 맺는 관계를 계산해서, 오늘 하루를 잘 쓰는 법을 짧고 실용적으로
        알려드립니다.
      </p>

      {!showResult && <BirthInfoForm submitLabel="오늘의 흐름 보기" onSubmit={handleSubmit} loading={loading} showFocus={false} />}
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
