import BirthInfoForm from "../components/BirthInfoForm";
import ReadingResult from "../components/ReadingResult";
import ChatFollowUp from "../components/ChatFollowUp";
import { useReadingStore } from "../store/useReadingStore";
import type { BirthInfo } from "../types";

export default function SajuPage() {
  const { currentSession, loading, error, startReading, sendFollowUp, clearCurrentSession } = useReadingStore();
  const showResult = currentSession?.type === "saju";

  function handleSubmit(birthInfo: BirthInfo, question: string) {
    startReading({ type: "saju", question, birthInfo });
  }

  return (
    <section className="page">
      <h2 className="page-title">사주 보기</h2>
      <p className="page-desc">생년월일시를 입력하면 실제 만세력 계산으로 사주 원국을 뽑고, 근거를 밝히며 해석해드립니다.</p>

      {!showResult && <BirthInfoForm submitLabel="사주 보기" onSubmit={handleSubmit} loading={loading} />}
      {error && !showResult && <p className="error-text">{error}</p>}

      {showResult && currentSession && (
        <>
          <ReadingResult session={currentSession} />
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
