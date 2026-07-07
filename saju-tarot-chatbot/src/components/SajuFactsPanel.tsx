import { buildLifestyleGuide } from "../lib/lifestyleGuide";
import { computeSajuChart } from "../lib/saju";
import type { BirthInfo, FiveElementBalance, LuckCycles, SajuChart, SajuPillar, StrengthAssessment, YearFlowInfo } from "../types";
import ArcGauge from "./viz/ArcGauge";
import ElementRadarChart from "./viz/ElementRadarChart";
import MonthlyFlowChart from "./viz/MonthlyFlowChart";
import { ELEMENT_GLOSS, ELEMENT_KEY_BY_KO, ELEMENT_LABEL, ELEMENT_ORDER } from "./viz/elementMeta";
import { VizIcon } from "./viz/icons";

const GAN_KO: Record<string, string> = {
  갑: "갑목",
  을: "을목",
  병: "병화",
  정: "정화",
  무: "무토",
  기: "기토",
  경: "경금",
  신: "신금",
  임: "임수",
  계: "계수",
};

const GAN_HANJA: Record<string, string> = {
  갑: "甲",
  을: "乙",
  병: "丙",
  정: "丁",
  무: "戊",
  기: "己",
  경: "庚",
  신: "辛",
  임: "壬",
  계: "癸",
};

const ZHI_KO: Record<string, string> = {
  자: "쥐",
  축: "소",
  인: "호랑이",
  묘: "토끼",
  진: "용",
  사: "뱀",
  오: "말",
  미: "양",
  신: "원숭이",
  유: "닭",
  술: "개",
  해: "돼지",
};

const ZHI_HANJA: Record<string, string> = {
  자: "子",
  축: "丑",
  인: "寅",
  묘: "卯",
  진: "辰",
  사: "巳",
  오: "午",
  미: "未",
  신: "申",
  유: "酉",
  술: "戌",
  해: "亥",
};

const STEM_META: Record<string, { element: string; yinYang: string }> = {
  갑: { element: "목", yinYang: "양" },
  을: { element: "목", yinYang: "음" },
  병: { element: "화", yinYang: "양" },
  정: { element: "화", yinYang: "음" },
  무: { element: "토", yinYang: "양" },
  기: { element: "토", yinYang: "음" },
  경: { element: "금", yinYang: "양" },
  신: { element: "금", yinYang: "음" },
  임: { element: "수", yinYang: "양" },
  계: { element: "수", yinYang: "음" },
};

const BRANCH_META: Record<string, { element: string; yinYang: string }> = {
  자: { element: "수", yinYang: "양" },
  축: { element: "토", yinYang: "음" },
  인: { element: "목", yinYang: "양" },
  묘: { element: "목", yinYang: "음" },
  진: { element: "토", yinYang: "양" },
  사: { element: "화", yinYang: "음" },
  오: { element: "화", yinYang: "양" },
  미: { element: "토", yinYang: "음" },
  신: { element: "금", yinYang: "양" },
  유: { element: "금", yinYang: "음" },
  술: { element: "토", yinYang: "양" },
  해: { element: "수", yinYang: "음" },
};

const STRENGTH_GLOSS: Record<StrengthAssessment["label"], string> = {
  신강: "타고난 기운이 스스로 강한 편이에요. 밀어붙이는 힘은 있지만 자기 고집도 셀 수 있어요.",
  중화: "기운이 한쪽으로 치우치지 않고 균형 잡힌 편이에요.",
  신약: "기운이 약한 편이라 주변의 도움이나 흐름을 잘 타는 게 유리해요.",
};

function PillarBox({ label, pillar }: { label: string; pillar: SajuPillar | null }) {
  const ganKo = pillar ? (GAN_KO[pillar.gan] ?? pillar.gan) : "";
  const zhiKo = pillar ? (ZHI_KO[pillar.zhi] ?? pillar.zhi) : "";
  const ganHanja = pillar ? (GAN_HANJA[pillar.gan] ?? pillar.gan) : "";
  const zhiHanja = pillar ? (ZHI_HANJA[pillar.zhi] ?? pillar.zhi) : "";
  const stem = pillar ? STEM_META[pillar.gan] : null;
  const branch = pillar ? BRANCH_META[pillar.zhi] : null;
  const elementKey = stem ? ELEMENT_KEY_BY_KO[stem.element] : undefined;
  return (
    <div className={`pillar-box${elementKey ? ` pillar-box--${elementKey}` : ""}`}>
      <span className="pillar-box__label">{label}</span>
      <span className="pillar-box__value">{pillar ? `${ganHanja}${zhiHanja}` : "모름"}</span>
      {pillar && (
        <>
          <span className="pillar-box__hangul">{pillar.ganZhi}</span>
          <span className="pillar-box__ko">
            {ganKo} {stem?.yinYang}/{stem?.element} · {zhiKo} {branch?.yinYang}/{branch?.element}
          </span>
        </>
      )}
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
          <span className="element-bar__gloss">{ELEMENT_GLOSS[k]}</span>
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

function LifestyleGuidePanel({ sajuChart }: { sajuChart: SajuChart }) {
  const guide = buildLifestyleGuide(sajuChart);
  const items = [
    { label: "고유 색", value: guide.colors.join(" · ") },
    { label: "고유 숫자", value: guide.numbers.join(" · ") },
    { label: "맞는 방향", value: guide.directions.join(" · ") },
    { label: "잘 맞는 장소", value: guide.places.join(" · ") },
    { label: "자연 키워드", value: guide.nature.join(" · ") },
    { label: "운동", value: guide.movement.join(" · ") },
    { label: "건강 체크", value: guide.healthFocus.join(" · ") },
    { label: "일하는 방식", value: guide.workStyle.join(" · ") },
    { label: "회복 루틴", value: guide.recovery.join(" · ") },
  ];

  return (
    <section className="lifestyle-guide">
      <div className="lifestyle-guide__head">
        <div>
          <h4 className="saju-facts__subhead">내 생활 처방</h4>
          <p>{guide.basisReason}</p>
        </div>
        <span className={`lifestyle-guide__badge lifestyle-guide__badge--${guide.basisElement}`}>{guide.basisLabel}</span>
      </div>
      <div className="lifestyle-guide__grid">
        {items.map((item) => (
          <div className="lifestyle-guide__item" key={item.label}>
            <span>{item.label}</span>
            <b>{item.value}</b>
          </div>
        ))}
      </div>
      <p className="lifestyle-guide__caution">{guide.caution}</p>
      <div className="lifestyle-guide__mission">
        <b>재밌게 바로 해볼 것</b>
        <ul>
          {guide.playfulActions.map((action) => (
            <li key={action}>{action}</li>
          ))}
        </ul>
      </div>
      <details className="lifestyle-guide__evidence">
        <summary>추천 기준 보기</summary>
        <ul>
          {guide.evidence.map((line) => (
            <li key={line}>{line}</li>
          ))}
        </ul>
      </details>
    </section>
  );
}

// 대운 천간 오행 → 그 시기의 기운을 쉬운 말 한 단어로 (가독성용)
const ELEMENT_PHASE_WORD: Record<string, string> = {
  목: "성장기",
  화: "표현기",
  토: "안정기",
  금: "정리기",
  수: "사색기",
};

function dayunPhase(ganZhi: string): string | null {
  const gan = ganZhi?.[0];
  const el = gan ? STEM_META[gan]?.element : null;
  return el ? (ELEMENT_PHASE_WORD[el] ?? null) : null;
}

// 시기별 기운을 한 문장 주제로 (인생 지도용, 계산값을 쉬운 말로만 옮김 — 새 운명 주장 아님)
const ELEMENT_PHASE_THEME: Record<string, string> = {
  목: "새로 시작하고 배우고 뻗어나가는 힘이 커지는 시기",
  화: "드러내고 표현하고 사람들 앞에 나서는 힘이 커지는 시기",
  토: "터를 다지고 책임을 맡으며 현실을 정리하는 시기",
  금: "기준을 세우고 정리하고 결단하는 힘이 커지는 시기",
  수: "생각하고 준비하고 흐름을 살피며 안으로 쌓는 시기",
};

function dayunTheme(ganZhi: string): string | null {
  const gan = ganZhi?.[0];
  const el = gan ? STEM_META[gan]?.element : null;
  return el ? (ELEMENT_PHASE_THEME[el] ?? null) : null;
}

/**
 * 평생사주(인생 지도)용 대운 세로 타임라인. 계산된 대운 배열을 10년 단위 흐름으로
 * 나이·연도·간지·기운 주제와 함께 보여준다. 현재 대운을 강조. (계산 로직 불변, 표현만)
 */
export function DaYunLifeMap({ luckCycles }: { luckCycles?: LuckCycles }) {
  if (!luckCycles?.daYun || luckCycles.daYun.length === 0) return null;
  return (
    <ol className="dayun-lifemap">
      {luckCycles.daYun.map((dy) => {
        const gan = dy.ganZhi?.[0];
        const elementKo = gan ? STEM_META[gan]?.element : undefined;
        const elementKey = elementKo ? ELEMENT_KEY_BY_KO[elementKo] : undefined;
        const phase = dayunPhase(dy.ganZhi);
        const theme = dayunTheme(dy.ganZhi);
        return (
          <li
            key={`${dy.startAge}-${dy.ganZhi}`}
            className={`dayun-lifemap__row${elementKey ? ` dayun-lifemap__row--${elementKey}` : ""}${
              dy.current ? " dayun-lifemap__row--current" : ""
            }`}
          >
            <div className="dayun-lifemap__age">
              <b>{dy.startAge}~{dy.endAge}세</b>
              <small>{dy.startYear}~{dy.endYear}</small>
            </div>
            <div className="dayun-lifemap__body">
              <div className="dayun-lifemap__head">
                <span className="dayun-lifemap__ganzhi">{dy.ganZhi}</span>
                {phase && <span className="dayun-lifemap__phase">{phase}</span>}
                {dy.current && (
                  <span className="dayun-lifemap__now">
                    <VizIcon name="flag" size={10} /> 지금 이 시기
                  </span>
                )}
              </div>
              {theme && <p className="dayun-lifemap__theme">{theme}</p>}
            </div>
          </li>
        );
      })}
    </ol>
  );
}

function DaYunTimeline({ luckCycles }: { luckCycles: LuckCycles }) {
  return (
    <div className="dayun-timeline">
      {luckCycles.daYun.map((dy) => {
        const phase = dayunPhase(dy.ganZhi);
        const gan = dy.ganZhi?.[0];
        const elementKo = gan ? STEM_META[gan]?.element : undefined;
        const elementKey = elementKo ? ELEMENT_KEY_BY_KO[elementKo] : undefined;
        return (
          <div
            key={`${dy.startAge}-${dy.ganZhi}`}
            className={`dayun-pill${elementKey ? ` dayun-pill--${elementKey}` : ""}${dy.current ? " dayun-pill--current" : ""}`}
          >
            {dy.current && (
              <span className="dayun-pill__now">
                <VizIcon name="flag" size={10} /> 지금
              </span>
            )}
            <span className="dayun-pill__age">{dy.startAge}세~</span>
            <span className="dayun-pill__ganzhi">{dy.ganZhi}</span>
            {phase && <span className="dayun-pill__phase">{phase}</span>}
          </div>
        );
      })}
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

function monthTone(count: number): { label: string; detail: string } {
  if (count >= 4) return { label: "흔들림 큼", detail: "원국과 맞물리는 변화 신호가 많은 달" };
  if (count >= 2) return { label: "변화 있음", detail: "관계·일정·마음 흐름이 움직이기 쉬운 달" };
  if (count === 1) return { label: "가벼운 자극", detail: "작은 변동이나 조정 신호가 있는 달" };
  return { label: "잔잔함", detail: "큰 작용이 적어 기본 리듬을 유지하기 좋은 달" };
}

function pillarLine(chart: SajuChart) {
  return `${chart.year.ganZhi}/${chart.month.ganZhi}/${chart.day.ganZhi}/${chart.hour?.ganZhi ?? "시주 모름"}`;
}

function lateNightComparison(birthInfo?: BirthInfo) {
  if (!birthInfo || birthInfo.hour !== 23) return null;
  return {
    late: computeSajuChart({ ...birthInfo, lateNightZi: "late" }),
    early: computeSajuChart({ ...birthInfo, lateNightZi: "early" }),
  };
}

function SajuPillarGrid({ sajuChart }: { sajuChart: SajuChart }) {
  return (
    <>
      <h3 className="card-title">내 사주 원국</h3>
      <div className="pillar-grid">
        <PillarBox label="연주" pillar={sajuChart.year} />
        <PillarBox label="월주" pillar={sajuChart.month} />
        <PillarBox label="일주" pillar={sajuChart.day} />
        <PillarBox label="시주" pillar={sajuChart.hour} />
      </div>
      <p className="saju-facts__note">일간(나를 뜻하는 글자) {sajuChart.dayMasterGan}</p>
    </>
  );
}

/** 계산 근거를 접기 전에도 항상 보이는 사주 원국 4기둥만 담은 스냅샷 카드. */
export function SajuPillarSnapshot({ sajuChart }: { sajuChart?: SajuChart }) {
  if (!sajuChart) return null;
  return (
    <div className="card saju-facts">
      <SajuPillarGrid sajuChart={sajuChart} />
    </div>
  );
}

export default function SajuFactsPanel({
  sajuChart,
  luckCycles,
  birthInfo,
  showPillars = true,
  showDaYun = true,
}: {
  sajuChart?: SajuChart;
  luckCycles?: LuckCycles;
  birthInfo?: BirthInfo;
  /** 이미 SajuPillarSnapshot으로 4기둥을 보여준 경우 중복 렌더를 막기 위해 false로 넘긴다. */
  showPillars?: boolean;
  /** 평생사주 템플릿이 대운을 인생 지도로 위에서 이미 보여줄 때 대운 알약 타임라인을 숨긴다. */
  showDaYun?: boolean;
}) {
  if (!sajuChart && !luckCycles) return null;

  const ratio = sajuChart?.strength ? Math.round((sajuChart.strength.supportScore / sajuChart.strength.totalScore) * 100) : null;
  const ziComparison = lateNightComparison(birthInfo);
  const ziBasis = sajuChart?.calculationBasis?.lateNightZi;

  return (
    <div className="card saju-facts">
      {sajuChart && (
        <>
          {showPillars && <SajuPillarGrid sajuChart={sajuChart} />}

          {(ziBasis || sajuChart.timeCorrection) && (
            <div className="calculation-basis">
              {ziBasis && (
                <p>
                  <b>23:00 전후 계산 기준</b> — 현재 결과는{" "}
                  {ziBasis === "late" ? "당일 기준(입력한 날짜의 일주 유지)" : "다음날 기준(23시대부터 다음날 일주 적용)"}입니다.
                </p>
              )}
              {sajuChart.timeCorrection && (
                <p>
                  <b>시각 보정</b> —{" "}
                  {sajuChart.timeCorrection.applied.length > 0 ? sajuChart.timeCorrection.applied.join(", ") : "시주 경계 확인"} ·
                  보정 후 {sajuChart.timeCorrection.correctedDateTime}
                </p>
              )}
              {sajuChart.timeCorrection?.boundaryWarning && <p>{sajuChart.timeCorrection.boundaryWarning}</p>}
            </div>
          )}

          {ziComparison && (
            <div className="zi-comparison">
              <h4 className="saju-facts__subhead">23시대 기준 비교</h4>
              <p className="saju-facts__hint">
                23:00~23:59 출생은 만세력마다 기준이 다를 수 있어 두 방식을 함께 확인합니다.
              </p>
              <div className="zi-comparison__grid">
                <div className={ziBasis !== "early" ? "zi-comparison__item zi-comparison__item--active" : "zi-comparison__item"}>
                  <span>당일 기준</span>
                  <b>{pillarLine(ziComparison.late)}</b>
                  <small>입력한 날짜의 일주를 유지합니다.</small>
                </div>
                <div className={ziBasis === "early" ? "zi-comparison__item zi-comparison__item--active" : "zi-comparison__item"}>
                  <span>다음날 기준</span>
                  <b>{pillarLine(ziComparison.early)}</b>
                  <small>23시대부터 다음날 일주로 봅니다.</small>
                </div>
              </div>
            </div>
          )}

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
                  <div className="sinsal-chip" key={`${s.name}-${s.position}-${i}`} title={s.gloss}>
                    <span className="sinsal-chip__name">{s.name}</span>
                    <span className="sinsal-chip__pos">{s.position}</span>
                    <span className="sinsal-chip__gloss">{s.gloss}</span>
                  </div>
                ))}
              </div>
            </>
          )}

          <h4 className="saju-facts__subhead">오행 분포</h4>
          <ElementRadarChart fiveElements={sajuChart.fiveElements} />
          <ElementBars fiveElements={sajuChart.fiveElements} />

          <LifestyleGuidePanel sajuChart={sajuChart} />

          {sajuChart.yinYang && (
            <>
              <h4 className="saju-facts__subhead">음양 분포</h4>
              <YinYangBar yang={sajuChart.yinYang.yang} yin={sajuChart.yinYang.yin} />
            </>
          )}

          {sajuChart.strength && ratio !== null && (
            <>
              <h4 className="saju-facts__subhead">기운 강도</h4>
              <ArcGauge
                label="나를 돕는 기운의 비중"
                score={ratio}
                tone="neutral"
                tierLabel={sajuChart.strength.label}
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
              {sajuChart.calculationBasis?.lateNightZi && (
                <p>
                  23시대 기준 —{" "}
                  {sajuChart.calculationBasis.lateNightZi === "late"
                    ? "당일 기준(입력 날짜 일주 유지)"
                    : "다음날 기준(23시대부터 다음날 일주)"}
                </p>
              )}
              {sajuChart.rootedness && sajuChart.rootedness.length > 0 && (
                <p>통근(뿌리) — {sajuChart.rootedness.map((r) => r.note).join(" ")}</p>
              )}
              {sajuChart.transparency && <p>투출(드러남) — {sajuChart.transparency.note}</p>}
              {sajuChart.yongshin && (
                <p>
                  용신 후보 — 용신: {(sajuChart.yongshin.yongshin ?? sajuChart.yongshin.supportive).join("·") || "없음"}
                  {sajuChart.yongshin.heesin && sajuChart.yongshin.heesin.length > 0 ? ` / 희신: ${sajuChart.yongshin.heesin.join("·")}` : ""}
                  {sajuChart.yongshin.unfavorable.length > 0 ? ` / 기신: ${sajuChart.yongshin.unfavorable.join("·")}` : ""}
                  {sajuChart.yongshin.climatic ? ` / 조후용신: ${sajuChart.yongshin.climatic.element}` : ""}
                  {sajuChart.yongshin.mediating ? ` / 통관용신: ${sajuChart.yongshin.mediating.element}` : ""}
                  {sajuChart.yongshin.method ? ` (${sajuChart.yongshin.method})` : ""}
                </p>
              )}
              {sajuChart.gyeokguk && (
                <p>
                  격국 — {sajuChart.gyeokguk.name} ({sajuChart.gyeokguk.basis})
                  {sajuChart.gyeokguk.status ? ` · 성패: ${sajuChart.gyeokguk.status}` : ""}
                </p>
              )}
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
          {showDaYun && <DaYunTimeline luckCycles={luckCycles} />}

          {showDaYun && luckCycles.daYunYearOverlap && (
            <div className={`luck-overlap luck-overlap--${luckCycles.daYunYearOverlap.combo}`}>
              <span className="luck-overlap__tag">큰 흐름 × 올해 흐름</span>
              <p className="luck-overlap__headline">{luckCycles.daYunYearOverlap.headline}</p>
            </div>
          )}

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
            <details className="saju-facts__details saju-facts__monthly">
              <summary>월별 흐름 계산값 보기</summary>
              <h4 className="saju-facts__subhead">올해 1월~12월 흐름</h4>
              <MonthlyFlowChart monthlyFlow={luckCycles.monthlyFlow} />
              <div className="month-flow-grid">
                {luckCycles.monthlyFlow.map((mf) => (
                  <div
                    key={mf.month}
                    className={`month-flow-cell${mf.interactions.length > 0 ? " month-flow-cell--active" : ""}`}
                    title={mf.interactions.length > 0 ? mf.interactions.join(", ") : monthTone(0).detail}
                  >
                    <span className="month-flow-cell__month">{mf.month}월</span>
                    <span className="month-flow-cell__ganzhi">{mf.ganZhi}</span>
                    <span className="month-flow-cell__note">{monthTone(mf.interactions.length).label}</span>
                    <span className="month-flow-cell__detail">{monthTone(mf.interactions.length).detail}</span>
                  </div>
                ))}
              </div>
              <p className="saju-facts__hint">월별 표시는 원국과 올해 흐름이 얼마나 강하게 맞물리는지를 쉬운 말로 바꾼 것입니다. 더 읽기 쉬운 해석은 "월별 실행 캘린더"와 "올해의 흐름" 섹션에 있습니다.</p>
            </details>
          )}
        </>
      )}
    </div>
  );
}
