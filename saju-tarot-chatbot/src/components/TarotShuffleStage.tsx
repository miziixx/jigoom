import { useEffect, useState } from "react";
import { SHUFFLES, type ShuffleId } from "../lib/tarot";

interface Props {
  shuffleId: ShuffleId;
  onStop: () => void;
}

/**
 * 카드 덱이 섞이는 시각적 연출. 실제 뽑기(drawSpread)는 pick 단계 이후에 일어나며,
 * 여기서는 "내가 직접 섞었다"는 의식적 소유감을 주는 것이 목적이다.
 * 애니메이션은 CSS 기반이고 prefers-reduced-motion에서는 정적으로 표시된다.
 */
export default function TarotShuffleStage({ shuffleId, onStop }: Props) {
  const [ready, setReady] = useState(false);
  const backs = Array.from({ length: 7 }, (_, i) => i);

  // 최소 셔플 시간(0.9s): 너무 빨리 멈추면 연출감이 사라진다.
  useEffect(() => {
    const t = setTimeout(() => setReady(true), 900);
    return () => clearTimeout(t);
  }, []);

  return (
    <section className="card tarot-stage tarot-shuffle-stage" aria-label="카드 셔플">
      <div className="tarot-stage__head">
        <span className="feature-badge">{SHUFFLES[shuffleId].label}</span>
        <h3 className="card-title">카드를 섞는 중</h3>
        <p className="tarot-stage__desc">마음속으로 질문을 떠올리며 잠시 카드를 섞어요.</p>
      </div>

      <div className="tarot-shuffle-deck" aria-hidden="true">
        {backs.map((i) => (
          <span key={i} className="tarot-shuffle-card" style={{ ["--i" as string]: i }} />
        ))}
      </div>

      <button
        type="button"
        className="btn btn--primary"
        onClick={onStop}
        disabled={!ready}
        aria-live="polite"
      >
        {ready ? "그만 섞기" : "섞는 중…"}
      </button>
    </section>
  );
}
