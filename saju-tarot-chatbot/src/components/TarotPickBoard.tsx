import { useState } from "react";

interface Props {
  needCount: number;
  onComplete: (pickedSlots: number[]) => void;
}

const FAN_SIZE = 18;

/**
 * 부채꼴로 펼쳐진 카드 뒷면 중 needCount장을 사용자가 직접 고른다.
 * 고른 순서(pickedSlots)는 drawSpread에 그대로 넘겨져 스프레드 자리에 매핑된다.
 * "내가 이 카드를 뽑았다"는 인과적 소유감이 이 단계의 핵심 가치.
 */
export default function TarotPickBoard({ needCount, onComplete }: Props) {
  const [picked, setPicked] = useState<number[]>([]);
  const done = picked.length === needCount;

  function toggle(slot: number) {
    setPicked((prev) => {
      if (prev.includes(slot)) return prev.filter((s) => s !== slot);
      if (prev.length >= needCount) return prev;
      return [...prev, slot];
    });
  }

  return (
    <section className="card tarot-stage tarot-pick-stage" aria-label={`카드 ${needCount}장 고르기`}>
      <div className="tarot-stage__head">
        <span className="feature-badge">카드 고르기</span>
        <h3 className="card-title">끌리는 카드를 {needCount}장 골라요</h3>
        <p className="tarot-stage__desc">
          {picked.length}/{needCount}장 선택 — 고른 순서대로 자리에 놓입니다.
        </p>
      </div>

      <div className="tarot-fan" role="group" aria-label="펼쳐진 카드">
        {Array.from({ length: FAN_SIZE }, (_, slot) => {
          const order = picked.indexOf(slot);
          const isPicked = order >= 0;
          const angle = (slot - (FAN_SIZE - 1) / 2) * 4;
          return (
            <button
              key={slot}
              type="button"
              className={isPicked ? "tarot-fan-card tarot-fan-card--picked" : "tarot-fan-card"}
              style={{ ["--angle" as string]: `${angle}deg` }}
              onClick={() => toggle(slot)}
              aria-pressed={isPicked}
              aria-label={isPicked ? `${order + 1}번째로 고른 카드` : "카드 고르기"}
            >
              <span className="tarot-fan-card__face">{isPicked ? order + 1 : ""}</span>
            </button>
          );
        })}
      </div>

      <button
        type="button"
        className="btn btn--primary"
        onClick={() => onComplete(picked)}
        disabled={!done}
      >
        {done ? "카드 펼치기" : `${needCount - picked.length}장 더 고르기`}
      </button>
    </section>
  );
}
