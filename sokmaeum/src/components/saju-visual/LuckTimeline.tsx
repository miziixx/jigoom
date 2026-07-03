import type { LuckCycles } from "../../types";
import { colorOfChar } from "./elementColors";

/** 대운 흐름 가로 타임라인 (현재 대운 강조) + 현재 세운/월운 요약 */
export default function LuckTimeline({ luck }: { luck: LuckCycles }) {
  return (
    <div className="sv-luck">
      <div className="sv-luck-now">
        <span className="sv-luck-chip">
          현재 대운 <b>{luck.currentDaYun ?? "시작 전"}</b>
        </span>
        <span className="sv-luck-chip">
          올해({luck.year}) <b>{luck.yearGanZhi}</b>
        </span>
        <span className="sv-luck-chip">
          이번 달({luck.month}) <b>{luck.monthGanZhi}</b>
        </span>
      </div>

      <div className="sv-timeline">
        {luck.daYun.map((dy) => (
          <div className={dy.current ? "sv-tl-item sv-tl-item--now" : "sv-tl-item"} key={dy.startAge}>
            <span className="sv-tl-age">{dy.startAge}세</span>
            <span
              className="sv-tl-ganzhi"
              style={{ borderColor: colorOfChar(dy.ganZhi[0]), color: colorOfChar(dy.ganZhi[0]) }}
            >
              {dy.ganZhi}
            </span>
            {dy.current && <span className="sv-tl-star">지금</span>}
          </div>
        ))}
      </div>

      {luck.monthlyFlow && luck.monthlyFlow.length > 0 && (
        <div className="sv-month-flow">
          {luck.monthlyFlow.map((mf) => (
            <span
              key={mf.month}
              className={mf.interactions.length > 0 ? "sv-mf sv-mf--hit" : "sv-mf"}
              title={mf.interactions.join(", ") || "원국과 뚜렷한 상호작용 없음"}
            >
              {mf.month}월 {mf.ganZhi}
            </span>
          ))}
        </div>
      )}
    </div>
  );
}
