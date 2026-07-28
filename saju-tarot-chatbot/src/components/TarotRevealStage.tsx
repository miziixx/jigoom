import { useEffect, useRef, useState } from "react";
import { TarotCardVisual } from "./TarotFactsPanel";
import type { DrawnTarotCard } from "../types";

interface Props {
  cards: DrawnTarotCard[];
  onDone: () => void;
}

const REVEAL_INTERVAL = 700;

/**
 * 고른 카드를 자리별로 한 장씩 뒤집으며 공개한다. 공개가 끝나면 onDone으로 reading 단계에 진입한다.
 * prefers-reduced-motion이면 전부 즉시 공개한다.
 */
export default function TarotRevealStage({ cards, onDone }: Props) {
  const reduce =
    typeof window !== "undefined" &&
    window.matchMedia?.("(prefers-reduced-motion: reduce)").matches;
  const [revealed, setRevealed] = useState(reduce ? cards.length : 0);
  const doneRef = useRef(false);

  useEffect(() => {
    if (reduce) return;
    if (revealed >= cards.length) return;
    const t = setTimeout(() => setRevealed((n) => n + 1), REVEAL_INTERVAL);
    return () => clearTimeout(t);
  }, [revealed, cards.length, reduce]);

  const allRevealed = revealed >= cards.length;

  function revealRest() {
    setRevealed(cards.length);
  }

  function goReading() {
    if (doneRef.current) return;
    doneRef.current = true;
    onDone();
  }

  return (
    <section className="card tarot-stage tarot-reveal-stage" aria-label="카드 공개">
      <div className="tarot-stage__head">
        <span className="feature-badge">카드 공개</span>
        <h3 className="card-title">뽑은 카드</h3>
        <p className="tarot-stage__desc">자리별로 어떤 카드가 나왔는지 확인하세요.</p>
      </div>

      <div className="tarot-reveal-grid">
        {cards.map((c, i) => {
          const isUp = i < revealed;
          return (
            <div className="tarot-reveal-slot" key={`${c.position}-${c.card.id}`}>
              <span className="tarot-reveal-slot__label">
                {c.position}. {c.positionLabel ?? `${c.position}번째`}
              </span>
              <div className={isUp ? "tarot-flip tarot-flip--up" : "tarot-flip"} aria-hidden={!isUp}>
                <div className="tarot-flip__inner">
                  <div className="tarot-flip__back" />
                  <div className="tarot-flip__front">
                    <TarotCardVisual card={c.card} reversed={c.reversed} />
                  </div>
                </div>
              </div>
              <span className="tarot-reveal-slot__name">
                {isUp ? `${c.card.name}${c.reversed ? " (역)" : ""}` : "…"}
              </span>
            </div>
          );
        })}
      </div>

      <div className="tarot-reveal-actions">
        {!allRevealed && !reduce && (
          <button type="button" className="btn btn--ghost" onClick={revealRest}>
            한번에 공개
          </button>
        )}
        <button type="button" className="btn btn--primary" onClick={goReading} disabled={!allRevealed}>
          리딩 보기
        </button>
      </div>
    </section>
  );
}
