import { useEffect, useState } from "react";
import BirthInfoForm from "../components/BirthInfoForm";
import ChatFollowUp from "../components/ChatFollowUp";
import InterestPicker from "../features/mystic-reading/components/InterestPicker";
import MysticResultView from "../features/mystic-reading/components/MysticResultView";
import { useMysticStore } from "../store/useMysticStore";
import type { BirthInfo } from "../types";

export default function MysticPage() {
  const { interest, session, loading, error, init, setInterest, generate, regenerate, sendFollowUp, reset } =
    useMysticStore();
  const [pendingInterest, setPendingInterest] = useState(interest);

  useEffect(() => {
    init();
  }, [init]);

  function handleSubmit(b: BirthInfo) {
    setInterest(pendingInterest);
    void generate(b, pendingInterest);
  }

  const showForm = !session && !loading;

  return (
    <section className="page">
      <h2 className="page-title">속마음 리딩</h2>
      <p className="page-desc">
        생년월일시와 지금 마음이 가는 곳을 알려주시면, 사주 원국과 대운·세운·월운을 바탕으로 지금 당신의 속마음과 반복되는
        패턴을 조용히 읽어드립니다. 점을 치는 게 아니라, 당신의 흐름을 심리 언어로 옮기는 리딩입니다.
      </p>

      {loading && !session && <p className="page-desc">지금 당신의 흐름을 읽는 중…</p>}

      {showForm && (
        <>
          <InterestPicker value={pendingInterest} onChange={setPendingInterest} />
          <BirthInfoForm submitLabel="속마음 리딩 보기" onSubmit={(b) => handleSubmit(b)} loading={loading} showFocus={false} />
        </>
      )}

      {error && <p className="error-text">{error}</p>}

      {session?.mysticResult && (
        <>
          <MysticResultView
            result={session.mysticResult}
            readingId={session.id}
            hasHour={session.birthInfo?.hour !== null && session.birthInfo?.hour !== undefined}
          />

          <ChatFollowUp session={session} onSend={(q) => void sendFollowUp(q)} loading={loading} />

          <div className="reading-actions">
            <button className="btn btn--ghost" onClick={() => void regenerate()} disabled={loading}>
              {loading ? "생성 중…" : "다시 읽기"}
            </button>
            <button className="btn btn--ghost" onClick={reset}>
              새로 보기
            </button>
          </div>
        </>
      )}
    </section>
  );
}
