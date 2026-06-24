import { useStore } from '../store/useStore';
import type { ViewMode } from '../store/types';

export function TopBar() {
  const { viewMode, setViewMode } = useStore();

  return (
    <header className="topbar">
      <div className="topbar-left">
        <span className="topbar-logo">🗺 mindmap</span>
      </div>
      <div className="topbar-toggle">
        <button
          className={`toggle-btn ${viewMode === 'outline' ? 'active' : ''}`}
          onClick={() => setViewMode('outline' as ViewMode)}
        >
          아웃라인
        </button>
        <button
          className={`toggle-btn ${viewMode === 'mindmap' ? 'active' : ''}`}
          onClick={() => setViewMode('mindmap' as ViewMode)}
        >
          마인드맵
        </button>
      </div>
      <div className="topbar-right">
        <span className="topbar-hint">
          {viewMode === 'outline'
            ? 'Enter: 형제 추가 · Tab: 들여쓰기 · Shift+Tab: 내어쓰기'
            : '더블클릭: 자식 추가 · 드래그: 위치 이동'}
        </span>
      </div>
    </header>
  );
}
