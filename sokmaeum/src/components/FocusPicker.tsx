import type { ReadingFocus } from "../types";

export const FOCUS_LABEL: Record<ReadingFocus, string> = {
  general: "전반",
  career: "직업·돈",
  relationship: "연애·관계",
  wellness: "건강·컨디션",
  mental: "멘탈·감정",
  decision: "선택·시기",
};

interface Props {
  value: ReadingFocus;
  onChange: (focus: ReadingFocus) => void;
}

export default function FocusPicker({ value, onChange }: Props) {
  return (
    <div className="field-row">
      <span className="field-label">해석 포커스</span>
      {(Object.keys(FOCUS_LABEL) as ReadingFocus[]).map((focus) => (
        <label key={focus}>
          <input type="radio" name="focus" checked={value === focus} onChange={() => onChange(focus)} />
          {FOCUS_LABEL[focus]}
        </label>
      ))}
    </div>
  );
}
