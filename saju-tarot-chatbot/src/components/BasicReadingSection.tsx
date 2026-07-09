import InstantSummary from "./InstantSummary";
import { buildBasicReading } from "../lib/basicReadingRenderer";
import type { Gender, LuckCycles, SajuChart } from "../types";

/**
 * 무료 "기본 리딩" 상단 노출 (재기획안 §5·§8). API 호출 없이 즉시 조립되므로
 * AI 텍스트가 스트리밍되기 전/도중에도 항상 보인다.
 *
 * 블록 2(원국 스냅샷)는 기존 InstantSummary를 그대로 승격해 재사용한다(중복 렌더 방지를 위해
 * CalculationEvidenceZone에서는 제거했다). 블록 4(분야별 신호)·블록 6(생활 처방)은 이미
 * EventForecastPanel·SajuFactsPanel이 상단에서 보여주고 있어 여기서 다시 그리지 않는다.
 * 블록 3(내 사용 설명서)·블록 5(올해 흐름 미니 캘린더)만 이 컴포넌트에서 새로 그린다.
 * 블록 1(소름 검증)은 아직 없다(§7·실행 덩어리 C-1에서 채워질 예정).
 */
export default function BasicReadingSection({
  sajuChart,
  luckCycles,
  gender,
  loading = false,
}: {
  sajuChart?: SajuChart;
  luckCycles?: LuckCycles;
  gender?: Gender;
  loading?: boolean;
}) {
  const reading = buildBasicReading({ sajuChart, luckCycles, gender });
  if (!reading.snapshot && !reading.userManual && !reading.yearFlow) return null;

  return (
    <>
      {reading.snapshot && <InstantSummary sajuChart={sajuChart} luckCycles={luckCycles} loading={loading} />}

      {reading.userManual && (
        <section className="card basic-reading-block">
          <div className="section-heading-row">
            <h3 className="card-title">내 사용 설명서</h3>
            <span className="feature-badge">무료 · 즉시</span>
          </div>
          <ul className="basic-reading-block__list">
            <li className="basic-reading-block__item">
              <span className="basic-reading-block__label">핵심 욕구</span>
              <span className="basic-reading-block__text">{reading.userManual.data.coreDesire}</span>
            </li>
            {reading.userManual.data.outerInner && (
              <li className="basic-reading-block__item">
                <span className="basic-reading-block__label">겉과 속</span>
                <span className="basic-reading-block__text">{reading.userManual.data.outerInner}</span>
              </li>
            )}
            <li className="basic-reading-block__item">
              <span className="basic-reading-block__label">눌릴 때 나오는 방식</span>
              <span className="basic-reading-block__text">{reading.userManual.data.defense}</span>
            </li>
            <li className="basic-reading-block__item">
              <span className="basic-reading-block__label">인정·선택</span>
              <span className="basic-reading-block__text">{reading.userManual.data.recognitionDecision}</span>
            </li>
            <li className="basic-reading-block__item">
              <span className="basic-reading-block__label">가까운 관계</span>
              <span className="basic-reading-block__text">{reading.userManual.data.attachment}</span>
            </li>
            <li className="basic-reading-block__item">
              <span className="basic-reading-block__label">스트레스·회복</span>
              <span className="basic-reading-block__text">{reading.userManual.data.stressPattern}</span>
            </li>
            <li className="basic-reading-block__item">
              <span className="basic-reading-block__label">반복되는 패턴</span>
              <span className="basic-reading-block__text">{reading.userManual.data.repeatedPattern}</span>
            </li>
          </ul>
        </section>
      )}

      {reading.yearFlow && (
        <section className="card basic-reading-block">
          <div className="section-heading-row">
            <h3 className="card-title">올해 흐름 미니 캘린더</h3>
            <span className="feature-badge">무료 · 즉시</span>
          </div>
          <div className="basic-reading-month-grid">
            {reading.yearFlow.data.map((m) => (
              <div className={`basic-reading-month basic-reading-month--${m.level}`} key={m.month}>
                <div className="basic-reading-month__head">
                  <span className="basic-reading-month__num">{m.month}월</span>
                  <span className="basic-reading-month__label">{m.label}</span>
                </div>
                <p className="basic-reading-month__detail">{m.detail}</p>
              </div>
            ))}
          </div>
        </section>
      )}
    </>
  );
}
