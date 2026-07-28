import type { SajuChart } from "../../types";
import { ELEMENT_META, ELEMENT_ORDER } from "./elementColors";

/** 오행 분포 가로 막대 그래프 + 음양 밸런스 바 */
export default function FiveElementsChart({ chart }: { chart: SajuChart }) {
  const fe = chart.fiveElements;
  const max = Math.max(1, ...ELEMENT_ORDER.map((k) => fe[k]));
  const total = ELEMENT_ORDER.reduce((s, k) => s + fe[k], 0) || 1;

  return (
    <div className="sv-elements">
      <div className="sv-bars">
        {ELEMENT_ORDER.map((k) => {
          const v = fe[k];
          const meta = ELEMENT_META[k];
          return (
            <div className="sv-bar-row" key={k}>
              <span className="sv-bar-label" style={{ color: meta.color }}>
                {meta.ko}
              </span>
              <div className="sv-bar-track">
                <div
                  className="sv-bar-fill"
                  style={{ width: `${(v / max) * 100}%`, background: meta.color }}
                />
              </div>
              <span className="sv-bar-count">{v}</span>
            </div>
          );
        })}
      </div>

      {chart.yinYang && (
        <div className="sv-yinyang" aria-label="음양 균형">
          <div
            className="sv-yy-yang"
            style={{ width: `${(chart.yinYang.yang / (chart.yinYang.yang + chart.yinYang.yin || 1)) * 100}%` }}
          >
            양 {chart.yinYang.yang}
          </div>
          <div className="sv-yy-yin">음 {chart.yinYang.yin}</div>
        </div>
      )}

      <p className="sv-caption">
        전체 {total}글자 기준 · 가장 강한 기운{" "}
        {ELEMENT_META[ELEMENT_ORDER.reduce((a, b) => (fe[a] >= fe[b] ? a : b))].ko}
        {ELEMENT_ORDER.some((k) => fe[k] === 0) && (
          <> · 비어 있는 기운 {ELEMENT_ORDER.filter((k) => fe[k] === 0).map((k) => ELEMENT_META[k].ko).join("·")}</>
        )}
      </p>
    </div>
  );
}
