import { useEffect } from "react";
import { useNavigate } from "react-router-dom";
import HistoryList from "../components/HistoryList";
import { useReadingStore } from "../store/useReadingStore";

const PATH_BY_TYPE = { saju: "/saju", tarot: "/tarot", combo: "/combo" } as const;

export default function HistoryPage() {
  const { savedSessions, refreshHistory, removeFromHistory, loadSessionById } = useReadingStore();
  const navigate = useNavigate();

  useEffect(() => {
    refreshHistory();
  }, [refreshHistory]);

  function handleSelect(id: string) {
    const session = savedSessions.find((s) => s.id === id);
    if (!session) return;
    loadSessionById(id);
    navigate(PATH_BY_TYPE[session.type]);
  }

  return (
    <section className="page">
      <h2 className="page-title">지난 리딩 기록</h2>
      <HistoryList sessions={savedSessions} onSelect={handleSelect} onDelete={removeFromHistory} />
    </section>
  );
}
