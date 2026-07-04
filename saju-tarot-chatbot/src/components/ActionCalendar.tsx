import type { LuckCycles, MonthFlowInfo } from "../types";

function actionFor(month: MonthFlowInfo): { tone: "quiet" | "move" | "care"; label: string; action: string } {
  const count = month.interactions.length;
  const joined = month.interactions.join(" ");
  if (count >= 3) {
    return { tone: "care", label: "조정 집중", action: "큰 결정은 하루 더 두고, 일정·관계·돈의 조건을 다시 확인하세요." };
  }
  if (count >= 2) {
    return { tone: "move", label: "변화 활용", action: "새 제안이나 방향 전환을 검토하되, 조건을 문서로 남기세요." };
  }
  if (/합|끌림|묶임/.test(joined)) {
    return { tone: "move", label: "관계 형성", action: "사람을 만나고 제안을 연결하기 좋습니다. 약속과 역할은 분명히 하세요." };
  }
  if (/충|형|파|해|부딪|흔들|깨짐|방해/.test(joined)) {
    return { tone: "care", label: "무리 금지", action: "감정적으로 바로 결정하지 말고, 계획을 작게 수정하는 쪽이 좋습니다." };
  }
  return { tone: "quiet", label: "기본기 정리", action: "새로 벌리기보다 루틴, 기록, 정리, 회복을 챙기세요." };
}

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
          const action = actionFor(month);
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
