import { conditionLevel } from "../lib/condition";

// 집 컨디션을 화분으로 시각화 (기획서 6장·25행 시각 시그니처).
// level 0(시든 잎) ~ 3(잎 무성 + 꽃)

const LEAF_COLOR: Record<number, string> = {
  0: "#a98b5a", // 시든
  1: "#9bbf6a",
  2: "#5aa55a",
  3: "#3b9b4f", // 무성
};

function Leaf({
  x,
  y,
  rot,
  color,
  scale = 1,
  flip = false,
}: {
  x: number;
  y: number;
  rot: number;
  color: string;
  scale?: number;
  flip?: boolean;
}) {
  return (
    <g transform={`translate(${x} ${y}) rotate(${rot}) scale(${flip ? -scale : scale} ${scale})`}>
      <path d="M0 0 C 14 -6 26 -2 34 8 C 22 12 8 10 0 0 Z" fill={color} />
    </g>
  );
}

export default function PlantGauge({ score }: { score: number }) {
  const { level, label, comment } = conditionLevel(score);
  const color = LEAF_COLOR[level];
  // 밀릴수록 잎이 처진다(아래로). level 높을수록 위로 뻗음.
  const droop = (3 - level) * 14;

  return (
    <div className="plant-gauge">
      <svg viewBox="0 0 160 170" width="150" height="160" role="img" aria-label={`집 컨디션 ${score}점`}>
        {/* 줄기 */}
        <rect x="77" y="70" width="6" height="58" rx="3" fill="#6b8f4e" />

        {/* 잎들 (level에 따라 개수/방향) */}
        <Leaf x={80} y={96} rot={-150 - droop} color={color} />
        <Leaf x={80} y={96} rot={30 + droop} color={color} flip />
        {level >= 1 && <Leaf x={80} y={80} rot={-160 - droop} color={color} scale={0.9} />}
        {level >= 2 && <Leaf x={80} y={80} rot={20 + droop} color={color} scale={0.9} flip />}
        {level >= 2 && <Leaf x={80} y={66} rot={-95} color={color} scale={0.8} />}

        {/* level 3: 꽃 */}
        {level >= 3 && (
          <g transform="translate(80 56)">
            {[0, 72, 144, 216, 288].map((a) => (
              <ellipse key={a} cx="0" cy="-9" rx="5" ry="9" fill="#f6b8cf" transform={`rotate(${a})`} />
            ))}
            <circle r="5" fill="#f4d35e" />
          </g>
        )}

        {/* 화분 */}
        <path d="M52 128 L108 128 L101 164 L59 164 Z" fill="#c8794b" />
        <rect x="48" y="120" width="64" height="12" rx="3" fill="#d98c5f" />
      </svg>

      <div className="plant-meta">
        <div className="plant-score">{score}</div>
        <div className="plant-label">{label}</div>
        <div className="plant-comment">{comment}</div>
      </div>
    </div>
  );
}
