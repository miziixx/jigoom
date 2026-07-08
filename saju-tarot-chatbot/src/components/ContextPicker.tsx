import { useMemo } from "react";
import { buildStyleHintFromFeedback } from "../lib/feedback";
import type { AnswerDepth, AnswerTone, BirthTimeAccuracy, LifeDomain, PastEvent, ReadingContext, SituationStage } from "../types";

const PAST_DOMAIN_OPTIONS: Array<{ value: LifeDomain; label: string }> = [
  { value: "career", label: "직업·일" },
  { value: "money", label: "돈·재물" },
  { value: "love", label: "연애·관계" },
  { value: "health", label: "건강·컨디션" },
  { value: "family", label: "가족" },
  { value: "move", label: "이사·이동" },
  { value: "startup", label: "창업·독립" },
];

const CURRENT_YEAR = new Date().getFullYear();

const SITUATIONS: Array<{ value: SituationStage; label: string }> = [
  { value: "before", label: "시작 전 고민" },
  { value: "ongoing", label: "이미 진행 중" },
  { value: "waiting", label: "결과 기다리는 중" },
  { value: "closing", label: "정리하는 중" },
];

const TONES: Array<{ value: AnswerTone; label: string; desc: string }> = [
  { value: "realistic", label: "현실적으로", desc: "조건과 가능성 위주" },
  { value: "warm", label: "부드럽게", desc: "차분하고 덜 날카롭게" },
  { value: "action", label: "행동 중심", desc: "오늘 할 일 위주" },
];

const DEPTHS: Array<{ value: AnswerDepth; label: string }> = [
  { value: "advanced", label: "고급" },
];

const TIME_ACCURACIES: Array<{ value: BirthTimeAccuracy; label: string }> = [
  { value: "exact", label: "정확함" },
  { value: "half-hour", label: "30분 오차 가능" },
  { value: "over-hour", label: "1시간 이상 오차" },
  { value: "unknown", label: "모름" },
];

const CONCERN_AREAS = ["일·커리어", "돈·수입", "연애·관계", "가족", "인간관계", "건강·컨디션", "진로·공부", "사업·브랜드", "마음상태"];

interface Props {
  value: ReadingContext;
  onChange: (context: ReadingContext) => void;
  /** 생년월일 입력이 있는 리딩에서만 출생 시간 정확도를 묻는다 */
  showTimeAccuracy?: boolean;
}

/** 리딩 전 개인화 질문 — 답할수록 해석의 초점과 신뢰도 판정이 정확해진다 */
export default function ContextPicker({ value, onChange, showTimeAccuracy = false }: Props) {
  // 지난 피드백에서 뽑을 수 있는 스타일 조정 힌트 (없으면 체크박스를 숨긴다)
  const availableStyleHint = useMemo(() => buildStyleHintFromFeedback(), []);

  const pastEvents = value.pastEvents ?? [];
  const updatePastEvents = (next: PastEvent[]) =>
    onChange({ ...value, pastEvents: next.length > 0 ? next : undefined });
  const setPastEvent = (index: number, patch: Partial<PastEvent>) =>
    updatePastEvents(pastEvents.map((ev, i) => (i === index ? { ...ev, ...patch } : ev)));
  const addPastEvent = () =>
    updatePastEvents([...pastEvents, { year: CURRENT_YEAR - 1, domain: "career" }]);
  const removePastEvent = (index: number) => updatePastEvents(pastEvents.filter((_, i) => i !== index));

  return (
    <div className="context-picker">
      <div className="context-picker__intro">
        <b>상황을 더 넣고 싶을 때</b>
        <span>선택사항이에요. 그냥 넘어가도 질문 내용을 보고 기본값으로 풀이합니다.</span>
      </div>

      <div className="consultation-grid">
        <label className="field-row field-row--column">
          <span className="field-label">고민 분야</span>
          <select value={value.concernArea ?? ""} onChange={(e) => onChange({ ...value, concernArea: e.target.value || undefined })}>
            <option value="">선택 안 함</option>
            {CONCERN_AREAS.map((area) => (
              <option key={area} value={area}>
                {area}
              </option>
            ))}
          </select>
        </label>

        <label className="field-row field-row--column">
          <span className="field-label">현재 상황</span>
          <select
            value={value.situation ?? ""}
            onChange={(e) => onChange({ ...value, situation: (e.target.value || undefined) as SituationStage | undefined })}
          >
            <option value="">선택 안 함</option>
            {SITUATIONS.map((s) => (
              <option key={s.value} value={s.value}>
                {s.label}
              </option>
            ))}
          </select>
        </label>
      </div>

      <label className="field-row field-row--column">
        <span className="field-label">고민 중인 선택지</span>
        <textarea
          rows={2}
          placeholder="예: A. 지금 일 유지 / B. 퇴사 후 새 시작 / C. 회사 다니며 부업 준비"
          value={value.optionsText ?? ""}
          onChange={(e) => onChange({ ...value, optionsText: e.target.value || undefined })}
        />
      </label>

      <label className="field-row field-row--column">
        <span className="field-label">최근 1~3개월 실제 상황</span>
        <textarea
          rows={2}
          placeholder="예: 일이 많아졌고, 사람 문제로 지치며, 새 일을 준비할 에너지가 줄었어요."
          value={value.recentContext ?? ""}
          onChange={(e) => onChange({ ...value, recentContext: e.target.value || undefined })}
        />
      </label>

      <label className="field-row field-row--column">
        <span className="field-label">가장 두려운 결과</span>
        <textarea
          rows={2}
          placeholder="예: 지금 움직였다가 돈도 잃고 다시 지칠까 봐 걱정돼요."
          value={value.fearPoint ?? ""}
          onChange={(e) => onChange({ ...value, fearPoint: e.target.value || undefined })}
        />
      </label>

      <div className="field-row field-row--column past-events">
        <span className="field-label">실제로 있었던 과거 일 (검증용, 선택)</span>
        <p className="past-events__hint">
          연도와 분야를 넣으면, 그 시기 사주 흐름과 얼마나 맞는지 계산해서 해석 신뢰도를 조정합니다. 맞은 축은 더 자신 있게,
          안 맞은 축은 조심스럽게 풀이합니다.
        </p>
        {pastEvents.map((ev, i) => (
          <div className="past-event-row" key={i}>
            <input
              type="number"
              className="past-event-row__year"
              min={1930}
              max={CURRENT_YEAR}
              value={ev.year}
              aria-label="연도"
              onChange={(e) => setPastEvent(i, { year: Number(e.target.value) || CURRENT_YEAR })}
            />
            <select
              className="past-event-row__domain"
              value={ev.domain}
              aria-label="분야"
              onChange={(e) => setPastEvent(i, { domain: e.target.value as LifeDomain })}
            >
              {PAST_DOMAIN_OPTIONS.map((d) => (
                <option key={d.value} value={d.value}>
                  {d.label}
                </option>
              ))}
            </select>
            <input
              type="text"
              className="past-event-row__note"
              placeholder="무슨 일이었는지 (선택)"
              value={ev.note ?? ""}
              aria-label="사건 설명"
              onChange={(e) => setPastEvent(i, { note: e.target.value || undefined })}
            />
            <button type="button" className="past-event-row__remove" onClick={() => removePastEvent(i)} aria-label="삭제">
              ✕
            </button>
          </div>
        ))}
        <button type="button" className="past-events__add" onClick={addPastEvent}>
          + 과거 일 추가
        </button>
      </div>

      <div className="field-row field-row--column">
        <span className="field-label">풀이 말투</span>
        <div className="tone-choice-grid">
          <button
            type="button"
            className={!value.tone ? "tone-choice tone-choice--active" : "tone-choice"}
            onClick={() => onChange({ ...value, tone: undefined })}
          >
            <b>기본</b>
            <span>균형 있게</span>
          </button>
          {TONES.map((t) => (
            <button
              type="button"
              key={t.value}
              className={value.tone === t.value ? "tone-choice tone-choice--active" : "tone-choice"}
              onClick={() => onChange({ ...value, tone: t.value })}
            >
              <b>{t.label}</b>
              <span>{t.desc}</span>
            </button>
          ))}
        </div>
        <span className="field-hint">같은 근거라도 원하는 말투에 맞춰 풀이합니다.</span>
      </div>

      <div className="field-row">
        <span className="field-label">해석 깊이</span>
        <select
          value={value.depth ?? ""}
          onChange={(e) => onChange({ ...value, depth: (e.target.value || undefined) as AnswerDepth | undefined })}
        >
          <option value="">기본</option>
          {DEPTHS.map((d) => (
            <option key={d.value} value={d.value}>
              {d.label}
            </option>
          ))}
        </select>
      </div>

      {showTimeAccuracy && (
        <div className="field-row">
          <span className="field-label">출생시간 정확도</span>
          <select
            value={value.timeAccuracy ?? ""}
            onChange={(e) =>
              onChange({ ...value, timeAccuracy: (e.target.value || undefined) as BirthTimeAccuracy | undefined })
            }
          >
            <option value="">선택 안 함</option>
            {TIME_ACCURACIES.map((t) => (
              <option key={t.value} value={t.value}>
                {t.label}
              </option>
            ))}
          </select>
          <span className="field-hint">오차 가능성이 있으면 시주 의존 해석의 신뢰도를 낮춰서 알려드립니다.</span>
        </div>
      )}

      {availableStyleHint && (
        <div className="field-row">
          <label>
            <input
              type="checkbox"
              checked={value.styleHint !== undefined}
              onChange={(e) => onChange({ ...value, styleHint: e.target.checked ? availableStyleHint : undefined })}
            />
            지난 리딩 피드백을 반영해 설명 방식 조정 (동의 시에만 사용)
          </label>
        </div>
      )}
    </div>
  );
}
