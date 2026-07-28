export interface GaugeDef {
  label: string;
  score: number;
  comment?: string;
  /** "auto"(기본) = 점수가 높을수록 좋은 지표(초록/보라/주황). "neutral" = 좋고 나쁨이 없는 지표(신강/신약 등, 단일 색상) */
  tone?: "auto" | "neutral";
  /** 숫자 대신 보여줄 상태 라벨(예: "잘 맞아요"). 지정하면 점수 숫자를 감추고 라벨을 노출한다. */
  tierLabel?: string;
}

export function band(score: number): "high" | "mid" | "low" {
  if (score >= 62) return "high";
  if (score >= 45) return "mid";
  return "low";
}

/** 점수를 생활 언어 상태 라벨로 바꾼다. "설명 없는 숫자"를 피하기 위한 공용 변환. */
export function tierWord(score: number): string {
  const b = band(score);
  return b === "high" ? "잘 맞아요" : b === "mid" ? "무난해요" : "조율이 필요해요";
}

export default function Gauge({ label, score, comment, tone = "auto", tierLabel }: GaugeDef) {
  const fillClass = tone === "neutral" ? "gauge__fill--neutral" : `gauge__fill--${band(score)}`;
  return (
    <div className="gauge">
      <div className="gauge__head">
        <span className="gauge__label">{label}</span>
        {tierLabel ? (
          <span className={`gauge__tier gauge__tier--${band(score)}`}>{tierLabel}</span>
        ) : (
          <span className="gauge__score">{score}</span>
        )}
      </div>
      <div className="gauge__track">
        <span className={`gauge__fill ${fillClass}`} style={{ width: `${score}%` }} />
      </div>
      {comment && <p className="gauge__comment">{comment}</p>}
    </div>
  );
}
