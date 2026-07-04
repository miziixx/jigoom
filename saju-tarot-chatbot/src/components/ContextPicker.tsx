import { useMemo } from "react";
import { buildStyleHintFromFeedback } from "../lib/feedback";
import type { AnswerDepth, AnswerTone, BirthTimeAccuracy, ReadingContext, SituationStage } from "../types";

const SITUATIONS: Array<{ value: SituationStage; label: string }> = [
  { value: "before", label: "시작 전 고민" },
  { value: "ongoing", label: "이미 진행 중" },
  { value: "waiting", label: "결과 기다리는 중" },
  { value: "closing", label: "정리하는 중" },
];

const TONES: Array<{ value: AnswerTone; label: string; desc: string }> = [
  { value: "realistic", label: "현실적으로", desc: "가능성과 조건을 균형 있게" },
  { value: "warm", label: "따뜻하게", desc: "부드럽지만 뻔하지 않게" },
  { value: "blunt", label: "냉정하게", desc: "돌려 말하지 않고 핵심부터" },
  { value: "detailed", label: "아주 자세하게", desc: "근거와 예시를 촘촘하게" },
];

const DEPTHS: Array<{ value: AnswerDepth; label: string }> = [
  { value: "light", label: "가벼운 리딩" },
  { value: "basic", label: "기본" },
  { value: "advanced", label: "고급" },
  { value: "expert", label: "전문가" },
];

const TIME_ACCURACIES: Array<{ value: BirthTimeAccuracy; label: string }> = [
  { value: "exact", label: "정확함" },
  { value: "half-hour", label: "30분 오차 가능" },
  { value: "over-hour", label: "1시간 이상 오차" },
  { value: "unknown", label: "모름" },
];

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

  return (
    <>
      <div className="field-row">
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
    </>
  );
}
