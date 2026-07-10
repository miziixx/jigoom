import { useMemo, useState } from "react";
import Gauge, { tierWord } from "../components/Gauge";
import ArcGauge from "../components/viz/ArcGauge";
import { VizIcon } from "../components/viz/icons";
import ReadingResult from "../components/ReadingResult";
import ReadingActions from "../components/ReadingActions";
import FeedbackBar from "../components/FeedbackBar";
import KeywordCloud from "../components/KeywordCloud";
import ChatFollowUp from "../components/ChatFollowUp";
import LoadingNotice from "../components/LoadingNotice";
import PersonDeepTeaser from "../components/PersonDeepTeaser";
import { BIRTH_PLACES } from "../data/birthPlaces";
import { computeCompatibility, computeSajuChart } from "../lib/saju";
import { buildPersonDeepEvidence } from "../lib/personDeep";
import { isPremium, unlockPremium } from "../lib/premium";
import { useReadingStore } from "../store/useReadingStore";
import type {
  BirthInfo,
  CalendarType,
  CompatibilityRelationType,
  CompatibilityResult,
  Gender,
  LateNightZiMode,
  PartnerBehaviorCheck,
} from "../types";

/**
 * 세부 흐름(breakdown)을 N축 폴리곤 레이더로 요약한다. 꼭짓점 라벨은 점수 대신
 * 생활 언어(tierWord)를 함께 보여주고, 정확한 항목별 내용은 아래 게이지 목록이 담당한다.
 */
function CompatBreakdownRadar({ breakdown }: { breakdown: CompatibilityResult["breakdown"] }) {
  const axes = breakdown.slice(0, 6);
  if (axes.length < 3) return null;

  const CX = 150;
  const CY = 120;
  const R = 66;
  const vertex = (i: number, radius: number) => {
    const angle = ((-90 + (i * 360) / axes.length) * Math.PI) / 180;
    return { x: CX + radius * Math.cos(angle), y: CY + radius * Math.sin(angle) };
  };
  const ring = (radius: number) =>
    axes.map((_, i) => {
      const v = vertex(i, radius);
      return `${v.x.toFixed(1)},${v.y.toFixed(1)}`;
    }).join(" ");

  return (
    <figure className="viz-radar compat-radar">
      <svg viewBox="0 0 300 240" role="img" aria-label={`관계 세부 흐름: ${axes.map((b) => `${b.label} ${tierWord(b.score)}`).join(", ")}`}>
        {[1 / 3, 2 / 3, 1].map((f) => (
          <polygon key={f} className="viz-radar__grid" points={ring(R * f)} />
        ))}
        {axes.map((b, i) => {
          const v = vertex(i, R);
          return <line key={b.label} className="viz-radar__spoke" x1={CX} y1={CY} x2={v.x.toFixed(1)} y2={v.y.toFixed(1)} />;
        })}
        <polygon
          className="viz-radar__area"
          points={axes.map((b, i) => {
            const v = vertex(i, (Math.max(8, Math.min(100, b.score)) / 100) * R);
            return `${v.x.toFixed(1)},${v.y.toFixed(1)}`;
          }).join(" ")}
        />
        {axes.map((b, i) => {
          const v = vertex(i, (Math.max(8, Math.min(100, b.score)) / 100) * R);
          return <circle key={b.label} className="compat-radar__dot" cx={v.x.toFixed(1)} cy={v.y.toFixed(1)} r={3.6} />;
        })}
        {axes.map((b, i) => {
          const v = vertex(i, R + 14);
          const anchor = Math.abs(v.x - CX) < 12 ? "middle" : v.x > CX ? "start" : "end";
          const dy = v.y < CY - 10 ? -4 : 6;
          return (
            <g key={b.label}>
              <text className="viz-radar__name" x={v.x.toFixed(1)} y={(v.y + dy).toFixed(1)} textAnchor={anchor}>
                {b.label}
              </text>
              <text className="viz-radar__gloss" x={v.x.toFixed(1)} y={(v.y + dy + 11).toFixed(1)} textAnchor={anchor}>
                {tierWord(b.score)}
              </text>
            </g>
          );
        })}
      </svg>
      <figcaption className="viz-caption">
        모양이 넓을수록 잘 맞물리는 영역이 많다는 뜻이에요. 항목별 자세한 설명은 아래 목록에 있습니다.
      </figcaption>
    </figure>
  );
}

/** "경오" 같은 간지 문자열 4개를 미니 기둥 박스로 보여준다. */
function MiniPillars({ pillars }: { pillars: { year: string; month: string; day: string; hour?: string | null } }) {
  const cells = [
    { label: "연", value: pillars.year },
    { label: "월", value: pillars.month },
    { label: "일", value: pillars.day },
    { label: "시", value: pillars.hour ?? "모름" },
  ];
  return (
    <div className="compat-mini-pillars">
      {cells.map((c) => (
        <span className="compat-mini-pillar" key={c.label}>
          <small>{c.label}</small>
          <b>{c.value}</b>
        </span>
      ))}
    </div>
  );
}

const HOURS = Array.from({ length: 24 }, (_, h) => h);

const RELATION_OPTIONS: Array<{ value: CompatibilityRelationType; label: string }> = [
  { value: "romantic", label: "연인·배우자" },
  { value: "family", label: "가족" },
  { value: "bossEmployee", label: "사장·직원" },
  { value: "coworker", label: "업무·협업" },
  { value: "friend", label: "친구·지인" },
];

// 상대 완전분석용 행동 체크 필드 (전부 선택, 계산 불변, 말·행동 대조 보조)
const PARTNER_CHECK_FIELDS: Array<{ key: keyof PartnerBehaviorCheck; label: string; placeholder: string }> = [
  { key: "whoContacts", label: "연락은 주로 누가 먼저", placeholder: "예: 거의 내가 먼저 / 반반 / 상대가 먼저" },
  { key: "onlineOfflineGap", label: "만날 때 vs 카톡·문자 태도차", placeholder: "예: 만나면 다정한데 톡은 단답" },
  { key: "makesPlans", label: "약속을 먼저 잡는 편인지", placeholder: "예: 내가 잡아야 만난다 / 상대가 잘 잡는다" },
  { key: "wordsMatchActions", label: "말과 행동이 일치하는지", placeholder: "예: 말은 잘하는데 약속은 자주 미룬다" },
  { key: "publicness", label: "관계를 주변에 공개하는지", placeholder: "예: 아직 아무도 모른다 / 다 안다" },
  { key: "knownDuration", label: "알게 된 기간", placeholder: "예: 3개월 / 2년" },
  { key: "recentMood", label: "최근 분위기", placeholder: "예: 요즘 연락이 뜸해졌다" },
];

interface PersonInput {
  calendarType: CalendarType;
  year: string;
  month: string;
  day: string;
  hour: string;
  minute: string;
  lateNightZi: LateNightZiMode;
  birthPlace: string;
  isLeapMonth: boolean;
  gender: Gender;
}

const EMPTY: PersonInput = {
  calendarType: "solar",
  year: "",
  month: "",
  day: "",
  hour: "unknown",
  minute: "",
  lateNightZi: "late",
  birthPlace: "none",
  isLeapMonth: false,
  gender: "female",
};

function toBirthInfo(p: PersonInput): BirthInfo {
  return {
    calendarType: p.calendarType,
    year: Number(p.year),
    month: Number(p.month),
    day: Number(p.day),
    hour: p.hour === "unknown" ? null : Number(p.hour),
    minute: p.hour === "unknown" || p.minute === "" ? 0 : Number(p.minute),
    lateNightZi: p.hour === "23" ? p.lateNightZi : undefined,
    birthPlace: p.birthPlace,
    isLeapMonth: p.calendarType === "lunar" ? p.isLeapMonth : undefined,
    gender: p.gender,
  };
}

function MiniBirthForm({
  title,
  subtitle,
  role,
  value,
  onChange,
}: {
  title: string;
  subtitle: string;
  role: "me" | "partner";
  value: PersonInput;
  onChange: (p: PersonInput) => void;
}) {
  const set = (patch: Partial<PersonInput>) => onChange({ ...value, ...patch });
  return (
    <div className={`card mini-birth mini-birth--${role}`}>
      <div className="mini-birth__head">
        <span className={`compat-role-badge compat-role-badge--${role}`}>{title}</span>
        <p>{subtitle}</p>
      </div>
      <div className="field-row">
        <span className="field-label">달력</span>
        <label>
          <input type="radio" checked={value.calendarType === "solar"} onChange={() => set({ calendarType: "solar" })} /> 양력
        </label>
        <label>
          <input type="radio" checked={value.calendarType === "lunar"} onChange={() => set({ calendarType: "lunar" })} /> 음력
        </label>
      </div>
      <div className="field-row mini-birth-date-row">
        <span className="field-label">생년월일</span>
        <div className="mini-birth-date-inputs">
          <input type="number" placeholder="년" value={value.year} onChange={(e) => set({ year: e.target.value })} />
          <input type="number" placeholder="월" min={1} max={12} value={value.month} onChange={(e) => set({ month: e.target.value })} />
          <input type="number" placeholder="일" min={1} max={31} value={value.day} onChange={(e) => set({ day: e.target.value })} />
        </div>
      </div>
      {value.calendarType === "lunar" && (
        <div className="field-row">
          <span className="field-label">윤달</span>
          <label className="checkbox-label">
            <input type="checkbox" checked={value.isLeapMonth} onChange={(e) => set({ isLeapMonth: e.target.checked })} /> 윤달
          </label>
        </div>
      )}
      <div className="field-row">
        <span className="field-label">출생 시간</span>
        <select value={value.hour} onChange={(e) => set({ hour: e.target.value, minute: e.target.value === "unknown" ? "" : value.minute })}>
          <option value="unknown">모름</option>
          {HOURS.map((h) => (
            <option key={h} value={h}>
              {h}시
            </option>
          ))}
        </select>
        {value.hour !== "unknown" && (
          <input
            type="number"
            placeholder="분"
            min={0}
            max={59}
            value={value.minute}
            onChange={(e) => set({ minute: e.target.value })}
            aria-label="출생 분"
          />
        )}
        {value.hour === "unknown" ? (
          <span className="field-hint field-hint--accent">시간을 알면 시주까지 비교해 궁합 해석이 더 정확해집니다.</span>
        ) : (
          <span className="field-hint">분까지 정확할수록 좋아요. 애매하면 정각으로 두어도 됩니다.</span>
        )}
      </div>
      {value.hour === "23" && (
        <div className="field-row field-row--column">
          <span className="field-label">23:00 전후 기준</span>
          <select value={value.lateNightZi} onChange={(e) => set({ lateNightZi: e.target.value as LateNightZiMode })}>
            <option value="late">당일 기준 — 23:00~23:59도 입력한 날짜로 봄</option>
            <option value="early">다음날 기준 — 23:00~23:59부터 다음날로 봄</option>
          </select>
          <span className="field-hint field-hint--accent">23시대 출생은 만세력 기준에 따라 일주가 달라질 수 있어요.</span>
        </div>
      )}
      <div className="field-row">
        <span className="field-label">출생지</span>
        <select value={value.birthPlace} onChange={(e) => set({ birthPlace: e.target.value })}>
          <option value="none">보정 안 함</option>
          {Object.entries(BIRTH_PLACES).map(([key, place]) => (
            <option key={key} value={key}>
              {place.label}
            </option>
          ))}
        </select>
        <span className={`field-hint${value.birthPlace === "none" ? " field-hint--accent" : ""}`}>
          {value.birthPlace === "none"
            ? "출생지를 고르면 시주 경계 판단이 더 정밀해집니다. 모르면 비워둬도 기본 비교는 가능합니다."
            : "표준시·경도 차이를 반영합니다."}
        </span>
      </div>
      <div className="field-row">
        <span className="field-label">성별</span>
        <label>
          <input type="radio" checked={value.gender === "female"} onChange={() => set({ gender: "female" })} /> 여성
        </label>
        <label>
          <input type="radio" checked={value.gender === "male"} onChange={() => set({ gender: "male" })} /> 남성
        </label>
      </div>
    </div>
  );
}

export default function CompatibilityPage() {
  const [personA, setPersonA] = useState<PersonInput>({ ...EMPTY });
  const [personB, setPersonB] = useState<PersonInput>({ ...EMPTY, gender: "male" });
  const [relationType, setRelationType] = useState<CompatibilityRelationType>("romantic");
  const [workRole, setWorkRole] = useState<"meBoss" | "meEmployee">("meBoss");
  const [question, setQuestion] = useState("");
  const [result, setResult] = useState<CompatibilityResult | null>(null);
  const [error, setError] = useState<string | null>(null);

  // 상대 완전분석(personDeep): 프리미엄 토글 + 상대 행동체크 → saju AI 리딩(주체=상대)
  const { currentSession, loading, error: readingError, startReading, sendFollowUp, clearCurrentSession } = useReadingStore();
  const [personDeepOn, setPersonDeepOn] = useState(false);
  const [partnerCheck, setPartnerCheck] = useState<PartnerBehaviorCheck>({});
  const [premium, setPremium] = useState(() => isPremium());
  const showPersonDeep = currentSession?.type === "saju" && currentSession.context?.analysisMode === "personDeep";

  const setPartner = (patch: Partial<PartnerBehaviorCheck>) => setPartnerCheck((prev) => ({ ...prev, ...patch }));

  const filled = (p: PersonInput) => p.year !== "" && p.month !== "" && p.day !== "";
  const canSubmit = filled(personA) && filled(personB);

  function handleCompute() {
    setError(null);
    try {
      const roleLabels =
        relationType === "bossEmployee"
          ? workRole === "meBoss"
            ? { first: "나(사장)", second: "상대(직원)" }
            : { first: "나(직원)", second: "상대(사장)" }
          : undefined;
      setResult(computeCompatibility(toBirthInfo(personA), toBirthInfo(personB), relationType, question, roleLabels));
    } catch {
      setError("궁합 계산에 실패했어요. 생년월일을 다시 확인해 주세요.");
    }
  }

  // 결정론 궁합 결과 아래 미리보기용 원국(입력이 유효할 때만).
  const teaserCharts = useMemo(() => {
    if (!result) return null;
    try {
      return { chartA: computeSajuChart(toBirthInfo(personA)), chartB: computeSajuChart(toBirthInfo(personB)) };
    } catch {
      return null;
    }
  }, [result, personA, personB]);

  function handlePersonDeep() {
    setError(null);
    try {
      const birthB = toBirthInfo(personB);
      const chartA = computeSajuChart(toBirthInfo(personA));
      const chartB = computeSajuChart(birthB);
      const timeAccuracy = personB.hour === "unknown" ? "unknown" : "exact";
      const hasPartnerCheck = Object.values(partnerCheck).some((v) => v && v.trim());
      const cp = buildPersonDeepEvidence({
        chartB,
        chartA,
        relationType,
        hasLuck: false,
        timeAccuracy,
        partnerCheck: hasPartnerCheck ? partnerCheck : undefined,
      });
      const counterpart = cp ? `${cp.evidence}\n\n${cp.instruction}` : undefined;
      startReading({
        type: "saju",
        question: question || "이 사람은 어떤 사람인가요?",
        birthInfo: birthB,
        context: {
          analysisMode: "personDeep",
          depth: "advanced",
          counterpart,
          partnerCheck: hasPartnerCheck ? partnerCheck : undefined,
          timeAccuracy,
        },
        saveToHistory: false,
      });
    } catch {
      setError("상대 완전분석 생성에 실패했어요. 생년월일을 다시 확인해 주세요.");
    }
  }

  if (showPersonDeep && currentSession) {
    return (
      <section className="page">
        <h2 className="page-title">상대 완전분석</h2>
        <p className="page-desc">상대의 사주 원국으로 "그 사람의 작동방식"을 16단계로 해부합니다. 관계 점수가 아니라 실제 행동 기준으로 읽어드려요. (참고용)</p>
        <ReadingResult session={currentSession} loading={loading} />
        {!loading && (
          <>
            <ReadingActions session={currentSession} />
            <FeedbackBar session={currentSession} />
            <KeywordCloud session={currentSession} />
            <ChatFollowUp session={currentSession} onSend={sendFollowUp} loading={loading} />
          </>
        )}
        {readingError && <p className="error-text">{readingError}</p>}
        <button className="btn btn--ghost" onClick={clearCurrentSession}>
          궁합으로 돌아가기
        </button>
      </section>
    );
  }

  const meTitle = relationType === "bossEmployee" ? (workRole === "meBoss" ? "나 · 사장" : "나 · 직원") : "나";
  const partnerTitle = relationType === "bossEmployee" ? (workRole === "meBoss" ? "상대 · 직원" : "상대 · 사장") : "상대";
  const meSubtitle = relationType === "bossEmployee" ? (workRole === "meBoss" ? "사장/리더 생년월일시" : "직원/실무자 생년월일시") : "내 생년월일시";
  const partnerSubtitle =
    relationType === "bossEmployee" ? (workRole === "meBoss" ? "직원/실무자 생년월일시" : "사장/리더 생년월일시") : "상대방 생년월일시";

  return (
    <section className="page">
      <h2 className="page-title">궁합 보기</h2>
      <p className="page-desc">두 사람의 사주 원국을 계산해 일간 관계·지지 인연(합충)·오행 보완을 종합한 궁합 점수를 보여드려요. (참고용)</p>

      <section className="card compat-relation-picker">
        <h3 className="card-title">어떤 관계로 볼까요?</h3>
        <label className="compat-relation-select">
          <span>관계 유형</span>
          <select value={relationType} onChange={(e) => setRelationType(e.target.value as CompatibilityRelationType)}>
            {RELATION_OPTIONS.map((option) => (
              <option key={option.value} value={option.value}>
                {option.label}
              </option>
            ))}
          </select>
        </label>
        {relationType === "bossEmployee" && (
          <div className="compat-role-switch" aria-label="사장 직원 역할 선택">
            <button type="button" className={workRole === "meBoss" ? "active" : ""} onClick={() => setWorkRole("meBoss")}>
              나는 사장 · 상대는 직원
            </button>
            <button type="button" className={workRole === "meEmployee" ? "active" : ""} onClick={() => setWorkRole("meEmployee")}>
              나는 직원 · 상대는 사장
            </button>
          </div>
        )}
        <label className="compat-question-field">
          <span>궁금한 점 (선택)</span>
          <textarea
            value={question}
            onChange={(e) => setQuestion(e.target.value)}
            rows={3}
            placeholder="예: 이 사람과 계속 가까이 지내도 될까요? / 같이 일하면 괜찮을까요? / 가족 문제에서 어디까지 맞춰야 할까요?"
          />
        </label>
      </section>

      <div className="compat-forms">
        <MiniBirthForm title={meTitle} subtitle={meSubtitle} role="me" value={personA} onChange={setPersonA} />
        <MiniBirthForm title={partnerTitle} subtitle={partnerSubtitle} role="partner" value={personB} onChange={setPersonB} />
      </div>

      <button className="btn btn--primary" onClick={handleCompute} disabled={!canSubmit}>
        궁합 보기
      </button>
      {error && <p className="error-text">{error}</p>}

      <section className="card person-deep-toggle">
        <div className="section-heading-row">
          <label className="checkbox-label">
            <input type="checkbox" checked={personDeepOn} onChange={() => setPersonDeepOn((v) => !v)} />
            <b>상대 완전분석</b>
            <span className="premium-badge">프리미엄</span>
          </label>
        </div>
        <span className="field-hint">
          궁합 점수 대신 "그 사람의 작동방식"을 16단계로 해부합니다 — 좋아할 때·불안할 때·질투·미련·식을
          때의 행동, 나에게 끌리는 지점과 부담 지점, 말과 행동이 어긋나는 순간까지.
        </span>

        {personDeepOn && !premium && (
          <div className="card premium-gate">
            <p>
              <span className="premium-badge">프리미엄</span> 상대 완전분석은 프리미엄 기능입니다. 결제 연동
              전까지는 아래 버튼으로 체험할 수 있습니다.
            </p>
            <button
              type="button"
              className="btn btn--primary"
              onClick={() => {
                unlockPremium();
                setPremium(true);
              }}
            >
              체험으로 잠금 해제
            </button>
          </div>
        )}

        {personDeepOn && premium && (
          <div className="self-check-grid">
            <p className="field-hint">
              아래는 선택입니다. 상대의 실제 행동을 적으면 계산된 성향과 대조해 "말과 행동이 맞는지"까지 짚어드려요.
            </p>
            {PARTNER_CHECK_FIELDS.map((f) => (
              <label className="field-row field-row--column" key={f.key}>
                <span className="field-label">{f.label}</span>
                <input
                  type="text"
                  placeholder={f.placeholder}
                  value={partnerCheck[f.key] ?? ""}
                  onChange={(e) => setPartner({ [f.key]: e.target.value || undefined })}
                />
              </label>
            ))}
            <button className="btn btn--primary" onClick={handlePersonDeep} disabled={!canSubmit || loading}>
              상대 완전분석 보기
            </button>
          </div>
        )}
        {loading && personDeepOn && <LoadingNotice />}
      </section>

      {result && (
        <div className="compat-result">
          <div className="card compat-score-card">
            <div>
              <span className="compat-score-card__eyebrow">{result.relationLabel ?? "관계"} 종합</span>
              <h3 className="compat-score-card__title">
                {result.score >= 75 ? "잘 맞는 흐름이 강한 관계" : result.score >= 55 ? "맞는 부분과 조율할 부분이 함께 있는 관계" : "거리와 기준을 맞춰야 하는 관계"}
              </h3>
              <p className="compat-summary">{result.summary}</p>
            </div>
            <div className="compat-score">
              <ArcGauge label={tierWord(result.score)} score={result.score} />
            </div>
          </div>

          {result.questionInsight && (
            <section className="card compat-question-card">
              <span className="compat-score-card__eyebrow">질문 의도 먼저 보기</span>
              <h3 className="card-title">{result.questionInsight.question}</h3>
              <p className="reading-body">{result.questionInsight.intent}</p>
              <p className="compat-question-card__answer">{result.questionInsight.answer}</p>
              <div className="compat-advice-grid">
                <section className="compat-inline-panel">
                  <h4>현실에서 확인할 신호</h4>
                  <ul className="compat-list">
                    {result.questionInsight.signals.map((item) => (
                      <li key={item}>{item}</li>
                    ))}
                  </ul>
                </section>
                <section className="compat-inline-panel">
                  <h4>이번 주 행동</h4>
                  <ul className="compat-list">
                    {result.questionInsight.actions.map((item) => (
                      <li key={item}>{item}</li>
                    ))}
                  </ul>
                </section>
              </div>
            </section>
          )}

          {result.solutionPlan && (
            <section className="card compat-solution-card">
              <span className="compat-score-card__eyebrow">관계 맞춤 솔루션</span>
              <h3 className="card-title">{result.solutionPlan.title}</h3>
              <p className="compat-solution-card__problem">{result.solutionPlan.problem}</p>
              <div className="compat-solution-card__context">
                <article>
                  <h4>나 기준</h4>
                  <p>{result.solutionPlan.personalContext}</p>
                </article>
                <article>
                  <h4>관계 기준</h4>
                  <p>{result.solutionPlan.relationshipContext}</p>
                </article>
              </div>
              <p className="compat-solution-card__priority">{result.solutionPlan.priority}</p>
              <div className="compat-advice-grid">
                <section className="compat-inline-panel">
                  <h4>지금 해볼 것</h4>
                  <ul className="compat-list">
                    {result.solutionPlan.todayActions.map((item) => (
                      <li key={item}>{item}</li>
                    ))}
                  </ul>
                </section>
                <section className="compat-inline-panel">
                  <h4>잘 맞추기 위해 할 것</h4>
                  <ul className="compat-list">
                    {result.solutionPlan.weekActions.map((item) => (
                      <li key={item}>{item}</li>
                    ))}
                  </ul>
                </section>
                <section className="compat-inline-panel">
                  <h4>피해야 할 말과 행동</h4>
                  <ul className="compat-list">
                    {result.solutionPlan.stopDoing.map((item) => (
                      <li key={item}>{item}</li>
                    ))}
                  </ul>
                </section>
                <section className="compat-inline-panel">
                  <h4>관계를 볼 때 확인할 점</h4>
                  <ul className="compat-list">
                    {result.solutionPlan.checkSignals.map((item) => (
                      <li key={item}>{item}</li>
                    ))}
                  </ul>
                </section>
              </div>
              <div className="compat-section-block">
                <h4>대화 예시</h4>
                <div className="compat-script-list">
                  {result.solutionPlan.scripts.map((script) => (
                    <p key={script}>{script}</p>
                  ))}
                </div>
              </div>
            </section>
          )}

          {result.people && (
            <div className="compat-people-grid">
              {result.people.map((p) => {
                const role = p.label.startsWith("나") ? "me" : "partner";
                return (
                <div className={`card compat-person compat-person--${role}`} key={p.label}>
                  <span className={`compat-role-badge compat-role-badge--${role}`}>{p.label}</span>
                  <MiniPillars pillars={p.pillars} />
                  <div className="compat-person__traits">
                    <span>
                      <VizIcon name="person" size={12} /> 나를 뜻하는 글자 {p.dayMaster}
                    </span>
                    <span>
                      <VizIcon name="sparkle" size={12} /> 강한 힘: {p.strongestElement}
                    </span>
                    <span>
                      <VizIcon name="sprout" size={12} /> 보완점: {p.weakestElement}
                    </span>
                  </div>
                </div>
                );
              })}
            </div>
          )}

          {result.repairReport && (
            <section className={`card compat-repair compat-repair--${result.repairReport.level}`}>
              <span className="compat-score-card__eyebrow">관계 보완 리포트</span>
              <h3 className="card-title">{result.repairReport.headline}</h3>
              <p className="reading-body">{result.repairReport.intro}</p>

              <div className="compat-section-block">
                <h4>왜 이런 흐름이 생기는지</h4>
                <ul className="compat-list">
                  {result.repairReport.whyItHappens.map((item) => (
                    <li key={item}>{item}</li>
                  ))}
                </ul>
              </div>

              <div className="compat-section-block">
                <h4>갈등이 커지는 순서와 회복법</h4>
                <div className="compat-step-grid compat-step-grid--cycle">
                  {result.repairReport.conflictCycle.map((step, i) => (
                    <article className="compat-step-card" key={step.step}>
                      <span className="compat-step-card__num" aria-hidden="true">
                        {i + 1}
                      </span>
                      <span>{step.step}</span>
                      <p>{step.body}</p>
                      <b>
                        <VizIcon name="link" size={12} /> {step.repair}
                      </b>
                    </article>
                  ))}
                </div>
              </div>

              <div className="compat-section-block">
                <h4>나와 상대를 구분해서 맞추는 법</h4>
                <div className="compat-person-advice">
                  <article>
                    <span className="compat-role-badge compat-role-badge--me">나</span>
                    <ul className="compat-list">
                      {result.repairReport.byPerson.me.map((item) => (
                        <li key={item}>{item}</li>
                      ))}
                    </ul>
                  </article>
                  <article>
                    <span className="compat-role-badge compat-role-badge--partner">상대</span>
                    <ul className="compat-list">
                      {result.repairReport.byPerson.partner.map((item) => (
                        <li key={item}>{item}</li>
                      ))}
                    </ul>
                  </article>
                  <article>
                    <span className="compat-role-badge">둘이 같이</span>
                    <ul className="compat-list">
                      {result.repairReport.byPerson.together.map((item) => (
                        <li key={item}>{item}</li>
                      ))}
                    </ul>
                  </article>
                </div>
              </div>

              <div className="compat-section-block">
                <h4>실제로 이렇게 말해보세요</h4>
                <div className="compat-script-list">
                  {result.repairReport.scripts.map((script) => (
                    <p key={script}>{script}</p>
                  ))}
                </div>
              </div>

              <section className="compat-inline-panel">
                <h4>하지 않는 편이 좋은 반응</h4>
                <ul className="compat-list">
                  {result.repairReport.avoid.map((item) => (
                    <li key={item}>{item}</li>
                  ))}
                </ul>
              </section>
            </section>
          )}

          {result.highlights && (
            <section className="card">
              <h3 className="card-title">{result.relationLabel ?? "관계"} 핵심 카드</h3>
              <div className="compat-highlight-grid">
                {result.highlights.map((h) => (
                  <article className="compat-highlight" key={h.title}>
                    <span>{h.title}</span>
                    <p>{h.body}</p>
                    <b>{h.action}</b>
                  </article>
                ))}
              </div>
            </section>
          )}

          {result.partnerPalace && (
            <section className="card compat-feature-card">
              <span className="compat-score-card__eyebrow">{result.relationLabel ?? "관계"} 자리</span>
              <h3 className="card-title">{result.partnerPalace.title}</h3>
              <p className="reading-body">{result.partnerPalace.body}</p>
            </section>
          )}

          {result.roleChemistry && (
            <section className="card">
              <h3 className="card-title">서로에게 어떤 존재로 느껴지는지</h3>
              <div className="compat-advice-grid">
                {result.roleChemistry.map((role) => (
                  <article className="compat-highlight" key={role.title}>
                    <span>{role.title}</span>
                    <p>{role.body}</p>
                  </article>
                ))}
              </div>
            </section>
          )}

          {result.purposeFits && (
            <section className="card">
              <h3 className="card-title">관계 목적별 궁합</h3>
              <div className="compat-deep-list">
                {result.purposeFits.map((fit) => (
                  <article className="compat-deep-item" key={fit.label}>
                    <Gauge label={fit.label} score={fit.score} comment={fit.comment} tierLabel={tierWord(fit.score)} />
                    {fit.detail && <p>{fit.detail}</p>}
                    {fit.signal && (
                      <p className="compat-signal">
                        <b>이럴 때 드러나요</b> {fit.signal}
                      </p>
                    )}
                    {fit.actions && (
                      <ul className="compat-list">
                        {fit.actions.map((action) => (
                          <li key={action}>{action}</li>
                        ))}
                      </ul>
                    )}
                  </article>
                ))}
              </div>
            </section>
          )}

          <div className="card">
            <h3 className="card-title">세부 흐름</h3>
            <CompatBreakdownRadar breakdown={result.breakdown} />
            <div className="compat-deep-list">
              {result.breakdown.map((b) => (
                <article className="compat-deep-item" key={b.label}>
                  <Gauge label={b.label} score={b.score} comment={b.note} tierLabel={tierWord(b.score)} />
                  {b.detail && <p>{b.detail}</p>}
                  {b.signal && (
                    <p className="compat-signal">
                      <b>이럴 때 드러나요</b> {b.signal}
                    </p>
                  )}
                  {b.actions && (
                    <ul className="compat-list">
                      {b.actions.map((action) => (
                        <li key={action}>{action}</li>
                      ))}
                    </ul>
                  )}
                </article>
              ))}
            </div>
          </div>

          {result.timing && (
            <section className="card">
              <h3 className="card-title">시기 흐름</h3>
              <div className="compat-advice-grid">
                {result.timing.map((t) => (
                  <article className="compat-highlight" key={t.label}>
                    <span>{t.label}</span>
                    <p>{t.body}</p>
                    <b>{t.evidence}</b>
                  </article>
                ))}
              </div>
            </section>
          )}

          {result.timingDetail && (
            <section className="card">
              <h3 className="card-title">다가오는 흐름 — 교차 타이밍</h3>
              <article className="compat-highlight">
                <span>두 사람의 큰 흐름</span>
                <p>{result.timingDetail.dayunPhase.headline}</p>
                <b>{result.timingDetail.dayunPhase.evidence}</b>
              </article>
              <div className="compat-advice-grid">
                {result.timingDetail.outlook.map((o) => (
                  <article className="compat-highlight" key={o.year}>
                    <span>
                      {o.year}년 · {o.tone}
                    </span>
                    <p>{o.body}</p>
                    <b>{o.evidence}</b>
                  </article>
                ))}
              </div>
              {result.timingDetail.crossHits.length > 0 && (
                <ul className="compat-list">
                  {result.timingDetail.crossHits.map((c, i) => (
                    <li key={`${c.mover}-${c.targetSpot}-${i}`}>
                      {c.mover}의 올해 흐름이 {c.target}의 {c.targetSpot}에 닿아요 — {c.plain}
                    </li>
                  ))}
                </ul>
              )}
            </section>
          )}

          {(result.cautionPoints || result.actionPlan) && (
            <div className="compat-advice-grid">
              {result.cautionPoints && (
                <section className="card">
                  <h3 className="card-title">조심할 반복 패턴</h3>
                  <ul className="compat-list">
                    {result.cautionPoints.map((item) => (
                      <li key={item}>{item}</li>
                    ))}
                  </ul>
                </section>
              )}
              {result.actionPlan && (
                <section className="card">
                  <h3 className="card-title">오래 가는 운영법</h3>
                  <ul className="compat-list">
                    {result.actionPlan.map((item) => (
                      <li key={item}>{item}</li>
                    ))}
                  </ul>
                </section>
              )}
            </div>
          )}

          {result.improvementTips && (
            <section className="card compat-feature-card">
              <h3 className="card-title">개선할 수 있는 방향</h3>
              <ul className="compat-list">
                {result.improvementTips.map((item) => (
                  <li key={item}>{item}</li>
                ))}
              </ul>
            </section>
          )}

          {result.expertEvidence && (
            <details className="card evidence-details">
              <summary>전문가 근거 보기</summary>
              <ul className="compat-list">
                {result.expertEvidence.map((item) => (
                  <li key={item}>{item}</li>
                ))}
              </ul>
            </details>
          )}
        </div>
      )}

      {result && teaserCharts && !personDeepOn && (
        <PersonDeepTeaser chartA={teaserCharts.chartA} chartB={teaserCharts.chartB} relationType={relationType} />
      )}

      <p className="fortune-disclaimer">
        본 궁합은 결정론적 계산에 기반한 참고용입니다. 관계의 실제 모습은 두 사람의 노력과 선택에 달려 있어요.
      </p>
    </section>
  );
}
