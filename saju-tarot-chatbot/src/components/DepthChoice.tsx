import type { AnswerDepth } from "../types";

interface Props {
  /** undefined = 기본, "advanced" = 고급 */
  value: AnswerDepth | undefined;
  onChange: (depth: AnswerDepth | undefined) => void;
}

/**
 * 리딩 깊이 선택 (기본 / 고급).
 * 기본은 표준 리딩, 고급은 더 깊고 정밀한 확장 리딩. 사주·타로·통합에서 공통으로 쓴다.
 */
export default function DepthChoice({ value, onChange }: Props) {
  const isAdvanced = value === "advanced";
  return (
    <div className="field-row field-row--column">
      <span className="field-label">해석 깊이</span>
      <div className="depth-choice-grid">
        <button
          type="button"
          className={!isAdvanced ? "tone-choice tone-choice--active" : "tone-choice"}
          onClick={() => onChange(undefined)}
        >
          <b>기본</b>
          <span>핵심을 빠짐없이 담은 표준 리딩</span>
        </button>
        <button
          type="button"
          className={isAdvanced ? "tone-choice tone-choice--active" : "tone-choice"}
          onClick={() => onChange("advanced")}
        >
          <b>고급</b>
          <span>더 깊고 정밀하게 확장한 리딩</span>
        </button>
      </div>
    </div>
  );
}
