import { useState, type ReactNode } from "react";
import { getSectionFeedback, saveSectionFeedback, SECTION_FEEDBACK_LABEL } from "../sectionFeedback";
import type { SectionFeedback } from "../../../types";

interface Props {
  title: string;
  summary?: string;
  /** 근거 보기(접기/펼치기)에 넣을 근거 배열 */
  evidence?: string[];
  /** 이 카드의 피드백 저장 키 (readingId + sectionKey) */
  readingId?: string;
  sectionKey?: string;
  /** 강한 첫 점괘 카드 스타일 */
  emphasized?: boolean;
  children: ReactNode;
}

const RATINGS: SectionFeedback["feedback"][] = ["accurate", "partial", "unsure", "wrong"];

export default function MysticCard({ title, summary, evidence, readingId, sectionKey, emphasized, children }: Props) {
  const [showEvidence, setShowEvidence] = useState(false);
  const [rating, setRating] = useState<SectionFeedback["feedback"] | null>(
    readingId && sectionKey ? getSectionFeedback(readingId, sectionKey) : null,
  );

  function pick(r: SectionFeedback["feedback"]) {
    if (!readingId || !sectionKey) return;
    saveSectionFeedback(readingId, sectionKey, r);
    setRating(r);
  }

  return (
    <div className={emphasized ? "card mystic-card mystic-card--oracle" : "card mystic-card"}>
      <h3 className="mystic-card__title">{title}</h3>
      {summary && <p className="mystic-card__summary">{summary}</p>}
      <div className="mystic-card__body">{children}</div>

      {evidence && evidence.length > 0 && (
        <div className="mystic-card__evidence">
          <button className="mystic-evidence-toggle" onClick={() => setShowEvidence((v) => !v)}>
            {showEvidence ? "근거 접기 ▲" : "근거 보기 ▼"}
          </button>
          {showEvidence && (
            <ul className="mystic-evidence-list">
              {evidence.map((ev, i) => (
                <li key={i}>{ev}</li>
              ))}
            </ul>
          )}
        </div>
      )}

      {readingId && sectionKey && (
        <div className="mystic-card__feedback">
          {RATINGS.map((r) => (
            <button
              key={r}
              className={rating === r ? "mystic-fb-btn mystic-fb-btn--active" : "mystic-fb-btn"}
              onClick={() => pick(r)}
            >
              {SECTION_FEEDBACK_LABEL[r]}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
