import { useMemo } from "react";
import { computePastEventCalibrationInputs } from "../lib/saju";
import { buildPastValidationReport } from "../lib/pastValidation";
import type { BirthInfo, PastEvent, PastEventMatch, SajuChart } from "../types";

const LEVEL_LABEL: Record<PastEventMatch["level"], string> = {
  strong: "잘 맞음",
  partial: "일부 맞음",
  weak: "신호 약함",
};

/**
 * 과거 검증 결과를 결과 화면에 보여준다. 계산은 무 API·결정론(브라우저).
 * "이 사주가 맞다/틀리다"가 아니라, 어느 축을 더 믿고 볼지에 대한 신뢰도 보정 참고.
 */
export default function PastValidationPanel({
  birthInfo,
  sajuChart,
  pastEvents,
}: {
  birthInfo?: BirthInfo;
  sajuChart?: SajuChart;
  pastEvents?: PastEvent[];
}) {
  const report = useMemo(() => {
    if (!birthInfo || !sajuChart || !pastEvents || pastEvents.length === 0) return null;
    return buildPastValidationReport(
      sajuChart.dayMasterGan,
      computePastEventCalibrationInputs(birthInfo, pastEvents),
    );
  }, [birthInfo, sajuChart, pastEvents]);

  if (!report) return null;

  return (
    <section className="card past-validation" aria-label="과거 사건 검증">
      <div>
        <span className="event-forecast__tag">과거 사건 검증</span>
      </div>
      <p className="past-validation__headline">{report.headline}</p>
      {report.matches.map((m) => (
        <div key={`${m.year}-${m.domain}`} className={`past-match past-match--${m.level}`}>
          <div className="past-match__head">
            <span>
              {m.year}년 · {m.domainLabel}
              {m.note ? ` — ${m.note}` : ""}
            </span>
            <span className={`past-match__badge past-match__badge--${m.level}`}>{LEVEL_LABEL[m.level]}</span>
          </div>
          <p className="past-match__summary">{m.summary}</p>
        </div>
      ))}
      <p className="past-validation__disclaimer">
        과거가 맞았다고 미래가 정해지는 것은 아닙니다. 이 결과는 당신의 실제 경험에 비춰 어떤 흐름을 더 믿고 보면 좋은지에 대한
        참고입니다.
      </p>
    </section>
  );
}
