import { useStore } from '../store/useStore';
import type { ViewMode } from '../store/types';

const VIEWS: { mode: ViewMode; label: string; icon: string }[] = [
  { mode: 'outline',  label: '아웃라인', icon: '☰' },
  { mode: 'mindmap',  label: '마인드맵', icon: '⬡' },
  { mode: 'calendar', label: '달력',    icon: '🗓' },
];

export function Sidebar() {
  const { sidebarOpen, setSidebarOpen, viewMode, setViewMode, setSettingsOpen } = useStore();

  function go(mode: ViewMode) {
    setViewMode(mode);
    setSidebarOpen(false);
  }

  return (
    <>
      {sidebarOpen && (
        <div className="sidebar-overlay" onClick={() => setSidebarOpen(false)} />
      )}
      <aside className={`sidebar ${sidebarOpen ? 'sidebar--open' : ''}`}>
        <div className="sidebar-header">
          <span className="sidebar-title">🗺 mindmap</span>
          <button className="sidebar-close" onClick={() => setSidebarOpen(false)}>✕</button>
        </div>

        <nav className="sidebar-nav">
          <p className="sidebar-section-label">뷰</p>
          {VIEWS.map(v => (
            <button
              key={v.mode}
              className={`sidebar-nav-btn ${viewMode === v.mode ? 'active' : ''}`}
              onClick={() => go(v.mode)}
            >
              <span className="sidebar-nav-icon">{v.icon}</span>
              {v.label}
            </button>
          ))}
        </nav>

        <div className="sidebar-bottom">
          <button
            className="sidebar-nav-btn"
            onClick={() => { setSettingsOpen(true); setSidebarOpen(false); }}
          >
            <span className="sidebar-nav-icon">⚙</span>
            설정
          </button>
        </div>
      </aside>
    </>
  );
}
