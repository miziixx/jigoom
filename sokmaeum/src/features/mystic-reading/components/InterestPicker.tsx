import { INTEREST_LABEL } from "../evidenceMapper";
import type { ReadingInterest } from "../../../types";

const ORDER: ReadingInterest[] = [
  "work",
  "money",
  "love",
  "marriage",
  "relationship",
  "family",
  "health",
  "future",
  "selfWorth",
  "all",
];

interface Props {
  value: ReadingInterest;
  onChange: (interest: ReadingInterest) => void;
}

/** 리딩 전 관심사 선택 — 선택값이 리딩 생성에 반영된다 */
export default function InterestPicker({ value, onChange }: Props) {
  return (
    <div className="mystic-interest">
      <span className="field-label">지금 가장 마음이 가는 곳</span>
      <div className="mystic-interest__chips">
        {ORDER.map((it) => (
          <button
            key={it}
            type="button"
            className={value === it ? "mystic-chip mystic-chip--active" : "mystic-chip"}
            onClick={() => onChange(it)}
          >
            {INTEREST_LABEL[it]}
          </button>
        ))}
      </div>
    </div>
  );
}
