import { useMemo } from "react";
import { buildEventForecast } from "../lib/eventEngine";
import type { EventActivation, LuckCycles, SajuChart, Gender } from "../types";

const DOMAIN_ICON: Record<string, string> = {
  career: "💼",
  money: "💰",
  love: "💗",
  health: "🌿",
  family: "🏠",
  move: "🧭",
  startup: "🚀",
};

const ACTIVATION_LABEL: Record<EventActivation, string> = {
  high: "지금 크게 움직임",
  mid: "변화 신호 있음",
  low: "평이함",
};

/**
 * 사건화 엔진(무 API·결정론) 결과를 "지금 움직이는 분야" 카드로 보여준다.
 * 활성(high/mid) 분야를 강조하고, 전체 분야는 접힘 영역으로 둔다.
 * 전문 용어는 표면에 노출하지 않고, 근거(evidence)는 계산 근거 영역 성격으로만 접어둔다.
 */
export default function EventForecastPanel({
  sajuChart,
  luckCycles,
  gender,
}: {
  sajuChart?: SajuChart;
  luckCycles?: LuckCycles;
  gender?: Gender;
}) {
  const forecast = useMemo(
    () => buildEventForecast(sajuChart, luckCycles, gender),
    [sajuChart, luckCycles, gender],
  );
  if (!forecast) return null;

  const active = forecast.domains.filter((d) => d.activation !== "low");
  const quiet = forecast.domains.filter((d) => d.activation === "low");

  return (
    <section className="card event-forecast" aria-label="지금 움직이는 분야">
      <div className="event-forecast__head">
        <span className="event-forecast__tag">지금 움직이는 분야</span>
        <p className="event-forecast__headline">{forecast.headline}</p>
      </div>

      {active.length > 0 && (
        <div className="event-forecast__grid">
          {active.map((d) => (
            <div key={d.domain} className={`event-domain event-domain--${d.activation}`}>
              <div className="event-domain__title">
                <span className="event-domain__icon">{DOMAIN_ICON[d.domain]}</span>
                <b>{d.label}</b>
                <span className={`event-domain__badge event-domain__badge--${d.activation}`}>
                  {ACTIVATION_LABEL[d.activation]}
                </span>
              </div>
              <p className="event-domain__note">{d.activationNote}</p>
              {d.timingSignals.length > 0 && (
                <ul className="event-domain__list">
                  {d.timingSignals.slice(0, 2).map((t, i) => (
                    <li key={i}>{t}</li>
                  ))}
                </ul>
              )}
              {d.cautions.length > 0 && (
                <p className="event-domain__caution">⚠ {d.cautions[0]}</p>
              )}
            </div>
          ))}
        </div>
      )}

      <details className="event-forecast__all">
        <summary>모든 분야 경향 보기 ({forecast.domains.length}개)</summary>
        <div className="event-forecast__all-body">
          {[...active, ...quiet].map((d) => (
            <div key={d.domain} className="event-domain-row">
              <div className="event-domain-row__head">
                <span>{DOMAIN_ICON[d.domain]} {d.label}</span>
                <span className={`event-domain__badge event-domain__badge--${d.activation}`}>
                  {ACTIVATION_LABEL[d.activation]}
                </span>
              </div>
              {d.patterns.length > 0 && (
                <ul className="event-domain__list">
                  {d.patterns.map((p, i) => (
                    <li key={i}>{p}</li>
                  ))}
                </ul>
              )}
              {d.cautions.length > 0 && (
                <p className="event-domain__caution">⚠ {d.cautions.join(" / ")}</p>
              )}
            </div>
          ))}
          <p className="event-forecast__disclaimer">
            이 예보는 계산된 사주 흐름을 분야별로 옮긴 참고 자료입니다. 정해진 길흉이 아니라, 지금 어떤 영역을 더 챙기면
            좋은지에 대한 방향으로 읽어 주세요.
          </p>
        </div>
      </details>
    </section>
  );
}
