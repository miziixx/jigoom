import { describeMonthAction } from "../lib/monthFlowNarrative";
import type { LuckCycles } from "../types";

function currentQuarter(month: number): string {
  if (month <= 3) return "1분기";
  if (month <= 6) return "2분기";
  if (month <= 9) return "3분기";
  return "4분기";
}

export default function ActionCalendar({ luckCycles }: { luckCycles?: LuckCycles }) {
  const monthly = luckCycles?.monthlyFlow;
  if (!monthly || monthly.length === 0) return null;
  const active = monthly.filter((m) => m.interactions.length > 0).sort((a, b) => b.interactions.length - a.interactions.length);
  const highlight = active[0] ?? monthly[luckCycles?.month ? Math.max(0, luckCycles.month - 1) : 0];

  return (
    <section className="card action-calendar">
      <div className="section-heading-row">
        <h3 className="card-title">월별 실행 캘린더</h3>
        <span className="feature-badge">1월-12월</span>
      </div>
      {highlight && (
        <p className="action-calendar__lead">
          올해는 <b>{highlight.month}월</b>이 가장 눈에 띄는 달입니다. {currentQuarter(highlight.month)} 안에서 일정과
          선택 기준을 미리 정리해두면 흐름을 더 잘 쓸 수 있어요.
        </p>
      )}
      <div className="action-calendar__grid">
        {monthly.map((month) => {
          const action = describeMonthAction(month);
          return (
            <article className={`action-month action-month--${action.tone}`} key={month.month}>
              <div className="action-month__top">
                <span>{month.month}월</span>
                <b>{action.label}</b>
              </div>
              <p>{action.action}</p>
            </article>
          );
        })}
      </div>
    </section>
  );
}
