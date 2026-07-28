import { buildInstantSummary } from "../lib/instantSummary";
import type { LuckCycles, SajuChart } from "../types";

/**
 * 계산 사실만으로 만든 즉시 요약. AI 리딩이 오기 전/도중에도 바로 읽을 거리를 준다.
 * loading일 때는 "AI 심화 해석을 쓰는 중"임을 함께 알린다.
 */
export default function InstantSummary({
  sajuChart,
  luckCycles,
  loading = false,
}: {
  sajuChart?: SajuChart;
  luckCycles?: LuckCycles;
  loading?: boolean;
}) {
  const summary = buildInstantSummary(sajuChart, luckCycles);
  if (!summary) return null;

  return (
    <section className="card instant-summary">
      <div className="instant-summary__head">
        <h3 className="card-title">바로 보는 요약</h3>
        <span className="instant-summary__badge">계산 기반</span>
      </div>
      <p className="instant-summary__note">
        아래는 사주 계산값만으로 즉시 정리한 요약이에요.
        {loading ? " 더 깊은 해석은 지금 아래에서 생성되고 있어요." : " 더 깊은 해석은 아래 리딩에 이어집니다."}
      </p>
      <ul className="instant-summary__list">
        {summary.lines.map((line) => (
          <li className="instant-summary__item" key={line.label}>
            <span className="instant-summary__label">{line.label}</span>
            <span className="instant-summary__text">{line.text}</span>
          </li>
        ))}
      </ul>
    </section>
  );
}
