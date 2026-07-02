import type { ReadingSession } from "../types";

const TYPE_LABEL: Record<ReadingSession["type"], string> = {
  saju: "사주",
  tarot: "타로",
  combo: "사주+타로",
};

interface Props {
  sessions: ReadingSession[];
  onSelect: (id: string) => void;
  onDelete: (id: string) => void;
  onToggleFavorite: (id: string) => void;
  /** 비교용 선택 (최대 2개) */
  compareIds: string[];
  onToggleCompare: (id: string) => void;
}

export default function HistoryList({
  sessions,
  onSelect,
  onDelete,
  onToggleFavorite,
  compareIds,
  onToggleCompare,
}: Props) {
  if (sessions.length === 0) {
    return <p className="empty-state">아직 저장된 리딩이 없습니다.</p>;
  }

  return (
    <ul className="history-list">
      {sessions.map((session) => {
        const checked = compareIds.includes(session.id);
        return (
          <li key={session.id} className="card history-item">
            <label className="history-item__compare" title="비교할 리딩 선택">
              <input
                type="checkbox"
                checked={checked}
                disabled={!checked && compareIds.length >= 2}
                onChange={() => onToggleCompare(session.id)}
              />
            </label>
            <button
              className="history-item__star"
              onClick={() => onToggleFavorite(session.id)}
              aria-label={session.favorite ? "즐겨찾기 해제" : "즐겨찾기"}
            >
              {session.favorite ? "★" : "☆"}
            </button>
            <button className="history-item__main" onClick={() => onSelect(session.id)}>
              <span className="history-item__type">{TYPE_LABEL[session.type]}</span>
              <span className="history-item__question">{session.question || "(질문 없음)"}</span>
              <span className="history-item__date">{new Date(session.createdAt).toLocaleString("ko-KR")}</span>
            </button>
            <button className="history-item__delete" onClick={() => onDelete(session.id)} aria-label="삭제">
              삭제
            </button>
          </li>
        );
      })}
    </ul>
  );
}
