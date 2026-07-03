export interface GaugeDef {
  label: string;
  score: number;
  comment?: string;
  /** "auto"(기본) = 점수가 높을수록 좋은 지표(초록/보라/주황). "neutral" = 좋고 나쁨이 없는 지표(신강/신약 등, 단일 색상) */
  tone?: "auto" | "neutral";
}

export function band(score: number): "high" | "mid" | "low" {
  if (score >= 62) return "high";
  if (score >= 45) return "mid";
  return "low";
}

export default function Gauge({ label, score, comment, tone = "auto" }: GaugeDef) {
  const fillClass = tone === "neutral" ? "gauge__fill--neutral" : `gauge__fill--${band(score)}`;
  return (
    <div className="gauge">
      <div className="gauge__head">
        <span className="gauge__label">{label}</span>
        <span className="gauge__score">{score}</span>
      </div>
      <div className="gauge__track">
        <span className={`gauge__fill ${fillClass}`} style={{ width: `${score}%` }} />
      </div>
      {comment && <p className="gauge__comment">{comment}</p>}
    </div>
  );
}
