import { useEffect } from "react";
import BirthInfoForm from "../components/BirthInfoForm";
import FortuneResult from "../components/FortuneResult";
import { useFortuneStore } from "../store/useFortuneStore";
import type { BirthInfo } from "../types";

export default function FortunePage() {
  const { birthInfo, result, loading, error, init, setBirthAndGenerate, regenerate, resetBirth } = useFortuneStore();

  useEffect(() => {
    void init();
  }, [init]);

  const showForm = !result && !loading && !birthInfo;

  function handleSubmit(b: BirthInfo) {
    void setBirthAndGenerate(b);
  }

  return (
    <section className="page">
      <h2 className="page-title">오늘 운세</h2>
      <p className="page-desc">
        오늘의 흐름과 운세를 한곳에서 봅니다. 내 사주 원국과 오늘 일진의 관계를 룰 기반 엔진이 계산하고, 그 근거로
        하루의 기회·주의점·실행 행동을 카드로 정리해 드려요. 매일 자정(KST) 기준으로 갱신됩니다.
      </p>

      {loading && !result && <p className="page-desc">오늘의 운세를 불러오는 중…</p>}

      {showForm && (
        <>
          <p className="empty-state">
            아직 등록된 명식이 없어요. 생년월일시를 입력하면 매일 오늘의 운세를 바로 확인할 수 있어요.
          </p>
          <BirthInfoForm submitLabel="오늘의 운세 보기" onSubmit={(b) => handleSubmit(b)} loading={loading} showFocus={false} />
        </>
      )}

      {error && <p className="error-text">{error}</p>}

      {result && (
        <>
          <FortuneResult result={result} />
          <div className="reading-actions">
            <button className="btn btn--ghost" onClick={() => void regenerate()} disabled={loading}>
              {loading ? "생성 중…" : "다시 생성"}
            </button>
            <button className="btn btn--ghost" onClick={resetBirth}>
              다른 명식으로 보기
            </button>
          </div>
        </>
      )}
    </section>
  );
}
