import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import HistoryList from "../components/HistoryList";
import FeedbackStats from "../components/FeedbackStats";
import BackupPanel from "../components/BackupPanel";
import { useReadingStore } from "../store/useReadingStore";
import { useMysticStore } from "../store/useMysticStore";

const PATH_BY_TYPE = { saju: "/saju", tarot: "/tarot", combo: "/combo", today: "/today", flow: "/flow", mystic: "/mystic" } as const;

export default function HistoryPage() {
  const { savedSessions, refreshHistory, removeFromHistory, loadSessionById, toggleFavoriteById } =
    useReadingStore();
  const loadMysticById = useMysticStore((s) => s.loadSessionById);
  const navigate = useNavigate();
  const [showFavoritesOnly, setShowFavoritesOnly] = useState(false);
  const [compareIds, setCompareIds] = useState<string[]>([]);

  useEffect(() => {
    refreshHistory();
  }, [refreshHistory]);

  const visibleSessions = showFavoritesOnly ? savedSessions.filter((s) => s.favorite) : savedSessions;

  function handleSelect(id: string) {
    const session = savedSessions.find((s) => s.id === id);
    if (!session) return;
    if (session.type === "mystic") {
      loadMysticById(id);
    } else {
      loadSessionById(id);
    }
    navigate(PATH_BY_TYPE[session.type]);
  }

  function handleToggleCompare(id: string) {
    setCompareIds((prev) => (prev.includes(id) ? prev.filter((x) => x !== id) : [...prev, id].slice(0, 2)));
  }

  return (
    <section className="page">
      <h2 className="page-title">지난 리딩 기록</h2>

      <FeedbackStats sessions={savedSessions} />

      <BackupPanel onImported={refreshHistory} />

      <div className="history-toolbar">
        <div className="filter-tabs">
          <button
            className={showFavoritesOnly ? "filter-tab" : "filter-tab filter-tab--active"}
            onClick={() => setShowFavoritesOnly(false)}
          >
            전체
          </button>
          <button
            className={showFavoritesOnly ? "filter-tab filter-tab--active" : "filter-tab"}
            onClick={() => setShowFavoritesOnly(true)}
          >
            ★ 즐겨찾기
          </button>
        </div>
        <button
          className="btn btn--primary btn--small"
          disabled={compareIds.length !== 2}
          onClick={() => navigate(`/compare?a=${compareIds[0]}&b=${compareIds[1]}`)}
        >
          {compareIds.length === 2 ? "선택한 2개 비교하기" : `비교할 리딩 선택 (${compareIds.length}/2)`}
        </button>
      </div>

      <HistoryList
        sessions={visibleSessions}
        onSelect={handleSelect}
        onDelete={removeFromHistory}
        onToggleFavorite={toggleFavoriteById}
        compareIds={compareIds}
        onToggleCompare={handleToggleCompare}
      />
    </section>
  );
}
