import Gauge from "./Gauge";
import type { FiveElementBalance, LuckCycles, SajuChart, SajuPillar, StrengthAssessment, YearFlowInfo } from "../types";

const ELEMENT_LABEL: Record<keyof FiveElementBalance, string> = {
  wood: "목",
  fire: "화",
  earth: "토",
  metal: "금",
  water: "수",
};

const ELEMENT_ORDER: Array<keyof FiveElementBalance> = ["wood", "fire", "earth", "metal", "water"];

const STRENGTH_GLOSS: Record<StrengthAssessment["label"], string> = {
  신강: "타고난 기운이 스스로 강한 편이에요. 밀어붙이는 힘은 있지만 자기 고집도 셀 수 있어요.",
  중화: "기운이 한쪽으로 치우치지 않고 균형 잡힌 편이에요.",
  신약: "기운이 약한 편이라 주변의 도움이나 흐름을 잘 타는 게 유리해요.",
};

function PillarBox({ label, pillar }: { label: string; pillar: SajuPillar | null }) {
  return (
    <div className="pillar-box">
      <span className="pillar-box__label">{label}</span>
      <span className="pillar-box__value">{pillar ? pillar.ganZhi : "모름"}</span>
    </div>
  );
}

function ElementBars({ fiveElements }: { fiveElements: FiveElementBalance }) {
  const max = Math.max(1, ...ELEMENT_ORDER.map((k) => fiveElements[k]));
  return (
    <div className="element-bars">
      {ELEMENT_ORDER.map((k) => (
        <div className="element-bar" key={k}>
          <span className="element-bar__label">{ELEMENT_LABEL[k]}</span>
          <div className="element-bar__track">
            <span
              className={`element-bar__fill element-bar__fill--${k}`}
              style={{ width: `${(fiveElements[k] / max) * 100}%` }}
            />
          </div>
          <span className="element-bar__value">{fiveElements[k]}</span>
        </div>
      ))}
    </div>
  );
}

function YinYangBar({ yang, yin }: { yang: number; yin: number }) {
  const total = Math.max(1, yang + yin);
  return (
    <div className="yinyang-bar">
      <div className="yinyang-bar__track">
        <span className="yinyang-bar__yang" style={{ width: `${(yang / total) * 100}%` }} />
      </div>
      <div className="yinyang-bar__labels">
        <span>양 {yang}</span>
        <span>음 {yin}</span>
      </div>
    </div>
  );
}

function DaYunTimeline({ luckCycles }: { luckCycles: LuckCycles }) {
  return (
    <div className="dayun-timeline">
      {luckCycles.daYun.map((dy) => (
        <div key={`${dy.startAge}-${dy.ganZhi}`} className={`dayun-pill${dy.current ? " dayun-pill--current" : ""}`}>
          <span className="dayun-pill__age">{dy.startAge}세~</span>
          <span className="dayun-pill__ganzhi">{dy.ganZhi}</span>
        </div>
      ))}
    </div>
  );
}

function YearlyTimeline({ yearlyFlow }: { yearlyFlow: YearFlowInfo[] }) {
  return (
    <div className="yearly-timeline">
      {yearlyFlow.map((y) => (
        <div
          key={y.year}
          className={`year-pill${y.current ? " year-pill--current" : ""}${y.interactions.length > 0 ? " year-pill--active" : ""}`}
          title={y.interactions.length > 0 ? y.interactions.join(", ") : "원국과 큰 상호작용 없음"}
        >
          <span className="year-pill__year">{y.year}</span>
          <span className="year-pill__ganzhi">{y.ganZhi}</span>
          <span className="year-pill__age">{y.age}세</span>
        </div>
      ))}
    </div>
  );
}

export default function SajuFactsPanel({ sajuChart, luckCycles }: { sajuChart?: SajuChart; luckCycles?: LuckCycles }) {
  if (!sajuChart && !luckCycles) return null;

  const ratio = sajuChart?.strength ? Math.round((sajuChart.strength.supportScore / sajuChart.strength.totalScore) * 100) : null;

  return (
    <div className="card saju-facts">
      {sajuChart && (
        <>
          <h3 className="card-title">내 사주 원국</h3>
          <div className="pillar-grid">
            <PillarBox label="연주" pillar={sajuChart.year} />
            <PillarBox label="월주" pillar={sajuChart.month} />
            <PillarBox label="일주" pillar={sajuChart.day} />
            <PillarBox label="시주" pillar={sajuChart.hour} />
          </div>
          <p className="saju-facts__note">일간(나를 뜻하는 글자) {sajuChart.dayMasterGan}</p>

          {sajuChart.iljuTrait && (
            <p className="ilju-trait">
              <b>일주 {sajuChart.day.ganZhi}</b> — {sajuChart.iljuTrait}
            </p>
          )}

          {sajuChart.gyeokguk && (
            <div className="gyeokguk-box">
              <span className="gyeokguk-box__name">{sajuChart.gyeokguk.name}</span>
              <span className="gyeokguk-box__gloss">{sajuChart.gyeokguk.gloss}</span>
            </div>
          )}

          {sajuChart.sinsal && sajuChart.sinsal.length > 0 && (
            <>
              <h4 className="saju-facts__subhead">신살</h4>
              <div className="sinsal-list">
                {sajuChart.sinsal.map((s, i) => (
                  <span className="sinsal-chip" key={`${s.name}-${s.position}-${i}`} title={s.gloss}>
                    {s.name}
                    <span className="sinsal-chip__pos">{s.position}</span>
                  </span>
                ))}
              </div>
            </>
          )}

          <h4 className="saju-facts__subhead">오행 분포</h4>
          <ElementBars fiveElements={sajuChart.fiveElements} />

          {sajuChart.yinYang && (
            <>
              <h4 className="saju-facts__subhead">음양 분포</h4>
              <YinYangBar yang={sajuChart.yinYang.yang} yin={sajuChart.yinYang.yin} />
            </>
          )}

          {sajuChart.strength && ratio !== null && (
            <>
              <h4 className="saju-facts__subhead">기운 강도</h4>
              <Gauge
                label={sajuChart.strength.label}
                score={ratio}
                tone="neutral"
                comment={STRENGTH_GLOSS[sajuChart.strength.label]}
              />
            </>
          )}

          <details className="saju-facts__details">
            <summary>계산값 자세히 보기</summary>
            <div className="saju-facts__details-body">
              {sajuChart.tenGods.length > 0 && <p>천간 십성 — {sajuChart.tenGods.join(", ")}</p>}
              {sajuChart.branchTenGods && sajuChart.branchTenGods.length > 0 && (
                <p>지지 십성 — {sajuChart.branchTenGods.join(", ")}</p>
              )}
              {sajuChart.hiddenStems && sajuChart.hiddenStems.length > 0 && <p>지장간 — {sajuChart.hiddenStems.join(", ")}</p>}
              {sajuChart.interactions && (
                <p>합충형파해 — {sajuChart.interactions.length > 0 ? sajuChart.interactions.join(", ") : "원국 내 해당 없음"}</p>
              )}
              {sajuChart.twelveStages && sajuChart.twelveStages.length > 0 && (
                <p>12운성 — {sajuChart.twelveStages.join(", ")}</p>
              )}
              {sajuChart.gongmang && <p>공망 — {sajuChart.gongmang}</p>}
              {sajuChart.seasonNote && <p>조후(계절) — {sajuChart.seasonNote}</p>}
              {sajuChart.yongshin && (
                <p>
                  용신 후보 — 용신: {(sajuChart.yongshin.yongshin ?? sajuChart.yongshin.supportive).join("·") || "없음"}
                  {sajuChart.yongshin.heesin && sajuChart.yongshin.heesin.length > 0 ? ` / 희신: ${sajuChart.yongshin.heesin.join("·")}` : ""}
                  {sajuChart.yongshin.unfavorable.length > 0 ? ` / 기신: ${sajuChart.yongshin.unfavorable.join("·")}` : ""}
                </p>
              )}
              {sajuChart.gyeokguk && <p>격국 — {sajuChart.gyeokguk.name} ({sajuChart.gyeokguk.basis})</p>}
              {sajuChart.timeCorrection && sajuChart.timeCorrection.applied.length > 0 && (
                <p>
                  시각 보정 — {sajuChart.timeCorrection.applied.join(", ")} (보정 후 {sajuChart.timeCorrection.correctedDateTime})
                </p>
              )}
              {sajuChart.timeCorrection?.boundaryWarning && (
                <p className="boundary-warning">⚠ {sajuChart.timeCorrection.boundaryWarning}</p>
              )}
            </div>
          </details>
        </>
      )}

      {luckCycles && (
        <>
          <h4 className="saju-facts__subhead">운 흐름 (대운·세운·월운)</h4>
          <div className="luck-chips">
            <span className="luck-chip">
              세운({luckCycles.year}년) <b>{luckCycles.yearGanZhi}</b>
            </span>
            <span className="luck-chip">
              월운({luckCycles.month}월) <b>{luckCycles.monthGanZhi}</b>
            </span>
            {luckCycles.dayGanZhi && (
              <span className="luck-chip">
                오늘 일진 <b>{luckCycles.dayGanZhi}</b>
              </span>
            )}
            <span className="luck-chip">
              현재 대운 <b>{luckCycles.currentDaYun ?? "시작 전"}</b>
            </span>
          </div>
          <DaYunTimeline luckCycles={luckCycles} />

          {luckCycles.yearlyFlow && luckCycles.yearlyFlow.length > 0 && (
            <>
              <h4 className="saju-facts__subhead">세운 흐름 (앞으로 10년)</h4>
              <YearlyTimeline yearlyFlow={luckCycles.yearlyFlow} />
              <p className="saju-facts__hint">칠해진 칸 = 그해 세운이 원국과 합·충 등 상호작용이 있는 해 (마우스를 올리면 내용 표시)</p>
            </>
          )}

          {luckCycles.luckInteractions && (
            <p className="saju-facts__note">
              운과 원국의 상호작용 —{" "}
              {luckCycles.luckInteractions.length > 0
                ? luckCycles.luckInteractions.join(", ")
                : "현재 대운/세운/월운/일진과 원국 사이 새로 성립하는 관계 없음"}
            </p>
          )}

          {luckCycles.monthlyFlow && luckCycles.monthlyFlow.length > 0 && (
            <details className="saju-facts__details">
              <summary>올해 월별 흐름 자세히 보기</summary>
              <div className="month-flow-grid">
                {luckCycles.monthlyFlow.map((mf) => (
                  <div key={mf.month} className={`month-flow-cell${mf.interactions.length > 0 ? " month-flow-cell--active" : ""}`}>
                    <span className="month-flow-cell__month">{mf.month}월</span>
                    <span className="month-flow-cell__ganzhi">{mf.ganZhi}</span>
                  </div>
                ))}
              </div>
            </details>
          )}
        </>
      )}
    </div>
  );
}
