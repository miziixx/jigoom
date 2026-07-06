import { band, type GaugeDef } from "../Gauge";

const R = 40;
const CIRC = 2 * Math.PI * R;
/** 270° 아크 */
const SPAN = 0.75;

/**
 * 기존 가로 바 Gauge의 아크(도넛) 버전. props는 GaugeDef와 호환되어 드롭인 교체 가능.
 * tierLabel을 주면 숫자 대신 생활 언어 라벨을 중앙에 보여준다("설명 없는 숫자" 방지).
 */
export default function ArcGauge({
  label,
  score,
  comment,
  tone = "auto",
  tierLabel,
  size = "md",
  unit = "점",
}: GaugeDef & { size?: "sm" | "md" | "lg"; unit?: string }) {
  const clamped = Math.max(0, Math.min(100, Math.round(score)));
  const fillClass = tone === "neutral" ? "viz-arc__fill--neutral" : `viz-arc__fill--${band(clamped)}`;
  const track = CIRC * SPAN;
  const fill = (track * clamped) / 100;

  return (
    <div className={`viz-arc viz-arc--${size}`}>
      <svg viewBox="0 0 100 90" role="img" aria-label={`${label}: ${tierLabel ?? `${clamped}${unit}`}`}>
        <g transform="rotate(135 50 50)">
          <circle className="viz-arc__track" cx="50" cy="50" r={R} strokeDasharray={`${track} ${CIRC}`} />
          <circle className={`viz-arc__fill ${fillClass}`} cx="50" cy="50" r={R} strokeDasharray={`${fill} ${CIRC}`} />
        </g>
        {tierLabel ? (
          <text className="viz-arc__value viz-arc__value--word" x="50" y="54">
            {tierLabel}
          </text>
        ) : (
          <>
            <text className="viz-arc__value" x="50" y="52">
              {clamped}
            </text>
            <text className="viz-arc__unit" x="50" y="63">
              {unit}
            </text>
          </>
        )}
      </svg>
      <span className="viz-arc__label">{label}</span>
      {comment && <p className="viz-arc__comment">{comment}</p>}
    </div>
  );
}
