import type { FiveElementBalance } from "../../types";
import { ELEMENT_GLOSS, ELEMENT_LABEL, ELEMENT_ORDER } from "./elementMeta";

const CX = 140;
const CY = 126;
const R = 76;

function vertex(index: number, radius: number) {
  const angle = ((-90 + index * 72) * Math.PI) / 180;
  return { x: CX + radius * Math.cos(angle), y: CY + radius * Math.sin(angle) };
}

function polygonPoints(radius: number) {
  return ELEMENT_ORDER.map((_, i) => {
    const v = vertex(i, radius);
    return `${v.x.toFixed(1)},${v.y.toFixed(1)}`;
  }).join(" ");
}

/** 꼭짓점별 라벨 배치(위/오른위/오른아래/왼아래/왼위). 색만으로 구분하지 않도록 이름+수치+풀이를 항상 붙인다. */
const LABEL_POS: Array<{ anchor: "middle" | "start" | "end"; dx: number; nameDy: number; glossDy: number }> = [
  { anchor: "middle", dx: 0, nameDy: -16, glossDy: -5 },
  { anchor: "start", dx: 12, nameDy: 2, glossDy: 14 },
  { anchor: "start", dx: 10, nameDy: 8, glossDy: 20 },
  { anchor: "end", dx: -10, nameDy: 8, glossDy: 20 },
  { anchor: "end", dx: -12, nameDy: 2, glossDy: 14 },
];

export default function ElementRadarChart({
  fiveElements,
  caption,
}: {
  fiveElements?: FiveElementBalance | null;
  /** 차트 아래 한 줄 해석. 생략하면 최강/최약 오행 문장을 자동 생성한다("설명 없는 숫자" 방지). */
  caption?: string | null;
}) {
  if (!fiveElements) return null;

  const values = ELEMENT_ORDER.map((k) => fiveElements[k]);
  const max = Math.max(1, ...values);
  const strongest = ELEMENT_ORDER.reduce((a, b) => (fiveElements[b] > fiveElements[a] ? b : a));
  const weakest = ELEMENT_ORDER.reduce((a, b) => (fiveElements[b] < fiveElements[a] ? b : a));
  const autoCaption =
    fiveElements[strongest] === fiveElements[weakest]
      ? "다섯 기운이 고르게 퍼져 있어 어느 한쪽으로 치우치지 않은 분포예요."
      : `${ELEMENT_LABEL[strongest]}(${ELEMENT_GLOSS[strongest]}) 기운이 가장 강하고, ${ELEMENT_LABEL[weakest]}(${ELEMENT_GLOSS[weakest]}) 기운이 가장 옅어요.`;

  const summaryText = ELEMENT_ORDER.map((k) => `${ELEMENT_LABEL[k]} ${fiveElements[k]}`).join(", ");

  return (
    <figure className="viz-radar">
      <svg viewBox="0 0 280 218" role="img" aria-label={`오행 분포 차트: ${summaryText}`}>
        {[1 / 3, 2 / 3, 1].map((f) => (
          <polygon key={f} className="viz-radar__grid" points={polygonPoints(R * f)} />
        ))}
        {ELEMENT_ORDER.map((k, i) => {
          const v = vertex(i, R);
          return <line key={k} className="viz-radar__spoke" x1={CX} y1={CY} x2={v.x.toFixed(1)} y2={v.y.toFixed(1)} />;
        })}
        <polygon
          className="viz-radar__area"
          points={ELEMENT_ORDER.map((k, i) => {
            const v = vertex(i, (fiveElements[k] / max) * R);
            return `${v.x.toFixed(1)},${v.y.toFixed(1)}`;
          }).join(" ")}
        />
        {ELEMENT_ORDER.map((k, i) => {
          const v = vertex(i, (fiveElements[k] / max) * R);
          return <circle key={k} className={`viz-radar__dot viz-radar__dot--${k}`} cx={v.x.toFixed(1)} cy={v.y.toFixed(1)} r={4} />;
        })}
        {ELEMENT_ORDER.map((k, i) => {
          const v = vertex(i, R);
          const pos = LABEL_POS[i];
          return (
            <g key={k}>
              <text className="viz-radar__name" x={(v.x + pos.dx).toFixed(1)} y={(v.y + pos.nameDy).toFixed(1)} textAnchor={pos.anchor}>
                {ELEMENT_LABEL[k]} {fiveElements[k]}
              </text>
              <text className="viz-radar__gloss" x={(v.x + pos.dx).toFixed(1)} y={(v.y + pos.glossDy).toFixed(1)} textAnchor={pos.anchor}>
                {ELEMENT_GLOSS[k]}
              </text>
            </g>
          );
        })}
      </svg>
      <figcaption className="viz-caption">{caption ?? autoCaption}</figcaption>
    </figure>
  );
}
