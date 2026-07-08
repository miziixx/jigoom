import { useState } from "react";
import type { MonthFlowInfo } from "../../types";
import { describeMonthFlow } from "../../lib/monthFlowNarrative";

/** ReadingResult가 AI 텍스트에서 파싱한 월별 상세(키워드/기회/주의/조언)와 구조적으로 호환되는 타입. */
export interface MonthDetail {
  month: string;
  keyword?: string;
  opportunity?: string;
  caution?: string;
  advice?: string;
}

/** 세로축 심각도 4단계 범례 (매달 반복되는 설명 문구가 아니라 축 눈금 이름이다). */
const TONE_LABELS = ["잔잔함", "가벼운 자극", "변화 있음", "흔들림 큼"];
const PLOT_LEFT = 66;
const PLOT_RIGHT = 352;
const BASE_Y = 104;
const STEP_Y = 26;

function monthNumberOf(detailMonth: string): number {
  const m = detailMonth.match(/(\d{1,2})\s*월/);
  return m ? Number(m[1]) : NaN;
}

function FlowChartInner({
  monthlyFlow,
  monthDetails,
  caption,
}: {
  monthlyFlow: MonthFlowInfo[];
  monthDetails?: MonthDetail[] | null;
  caption?: string | null;
}) {
  const currentMonth = new Date().getMonth() + 1;
  const [selected, setSelected] = useState<number>(() =>
    monthlyFlow.some((m) => m.month === currentMonth) ? currentMonth : monthlyFlow[0].month,
  );

  const n = monthlyFlow.length;
  const xOf = (i: number) => (n === 1 ? (PLOT_LEFT + PLOT_RIGHT) / 2 : PLOT_LEFT + (i * (PLOT_RIGHT - PLOT_LEFT)) / (n - 1));
  const yOf = (mf: MonthFlowInfo) => BASE_Y - describeMonthFlow(mf).level * STEP_Y;

  const linePoints = monthlyFlow.map((mf, i) => `${xOf(i).toFixed(1)},${yOf(mf).toFixed(1)}`).join(" ");
  const areaPath = `M ${xOf(0).toFixed(1)} ${BASE_Y} L ${linePoints.split(" ").join(" L ")} L ${xOf(n - 1).toFixed(1)} ${BASE_Y} Z`;

  const sel = monthlyFlow.find((m) => m.month === selected) ?? monthlyFlow[0];
  const selTone = describeMonthFlow(sel);
  const selDetail = monthDetails?.find((d) => monthNumberOf(d.month) === sel.month);

  return (
    <div className="viz-flow">
      <svg viewBox="0 0 360 118" aria-hidden="true" focusable="false">
        {TONE_LABELS.map((label, level) => {
          const y = BASE_Y - level * STEP_Y;
          return (
            <g key={label}>
              <line className="viz-flow__grid-line" x1={PLOT_LEFT} y1={y} x2={PLOT_RIGHT} y2={y} />
              <text className="viz-flow__tone-label" x={PLOT_LEFT - 8} y={y + 3} textAnchor="end">
                {label}
              </text>
            </g>
          );
        })}
        <path className="viz-flow__area" d={areaPath} />
        <polyline className="viz-flow__line" points={linePoints} />
        {monthlyFlow.map((mf, i) => (
          <g key={mf.month}>
            {mf.month === currentMonth && <circle className="viz-flow__ring" cx={xOf(i).toFixed(1)} cy={yOf(mf).toFixed(1)} r={7} />}
            <circle
              className={`viz-flow__dot${mf.month === sel.month ? " viz-flow__dot--selected" : ""}`}
              cx={xOf(i).toFixed(1)}
              cy={yOf(mf).toFixed(1)}
              r={mf.month === sel.month ? 4.6 : 3.4}
            />
          </g>
        ))}
      </svg>

      <div className="viz-flow__months" role="group" aria-label="달 선택">
        {monthlyFlow.map((mf) => {
          const tone = describeMonthFlow(mf);
          return (
            <button
              type="button"
              key={mf.month}
              className={`viz-flow__month${mf.month === sel.month ? " viz-flow__month--selected" : ""}${
                mf.month === currentMonth ? " viz-flow__month--current" : ""
              }`}
              aria-pressed={mf.month === sel.month}
              title={`${mf.month}월 · ${tone.label}`}
              onClick={() => setSelected(mf.month)}
            >
              <span>{mf.month}월</span>
              <i className={`viz-flow__month-dot viz-flow__month-dot--l${tone.level}`} aria-hidden="true" />
            </button>
          );
        })}
      </div>

      <div className="viz-flow__detail">
        <div className="viz-flow__detail-head">
          <b>{sel.month}월</b>
          <span className="viz-flow__ganzhi">{sel.ganZhi}</span>
          {sel.month === currentMonth && <span className="viz-flow__now">이번 달</span>}
          <span className="viz-flow__tone">{selTone.label}</span>
        </div>
        <p className="viz-flow__tone-detail">{selTone.detail}</p>
        {selDetail && (
          <div className="viz-flow__rows">
            {selDetail.keyword && (
              <p>
                <span>키워드</span> {selDetail.keyword}
              </p>
            )}
            {selDetail.opportunity && (
              <p>
                <span>기회</span> {selDetail.opportunity}
              </p>
            )}
            {selDetail.caution && (
              <p className="viz-flow__row--caution">
                <span>주의</span> {selDetail.caution}
              </p>
            )}
            {selDetail.advice && (
              <p className="viz-flow__row--advice">
                <span>조언</span> {selDetail.advice}
              </p>
            )}
          </div>
        )}
        {sel.interactions.length > 0 && <small className="viz-flow__evidence">계산 근거: {sel.interactions.join(", ")}</small>}
      </div>

      <p className="viz-caption">
        {caption ?? "선의 높낮이는 그 달 흐름이 내 원국과 얼마나 강하게 맞물리는지를 쉬운 말 4단계로 나눈 것입니다. 달을 누르면 상세가 열려요."}
      </p>
    </div>
  );
}

/**
 * 1~12월 흐름 차트. 곡선은 계산값(monthlyFlow.interactions)만 사용하고,
 * AI가 쓴 월별 텍스트(monthDetails)는 달을 눌렀을 때 상세로만 보여준다.
 * 데이터가 없으면 조용히 null을 반환해 호출부의 기존 폴백 렌더를 유지한다(스트리밍 내성).
 */
export default function MonthlyFlowChart(props: {
  monthlyFlow?: MonthFlowInfo[] | null;
  monthDetails?: MonthDetail[] | null;
  caption?: string | null;
}) {
  if (!props.monthlyFlow || props.monthlyFlow.length < 2) return null;
  return <FlowChartInner monthlyFlow={props.monthlyFlow} monthDetails={props.monthDetails} caption={props.caption} />;
}
