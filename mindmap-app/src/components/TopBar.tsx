import { useStore } from '../store/useStore';

const HINTS: Record<string, string> = {
  outline:  'Enter: 새 항목(루트) / 줄바꿈(중첩) · Tab: 들여쓰기 · Shift+Tab: 내어쓰기',
  mindmap:  '더블클릭: 자식 추가 · 드래그: 위치 이동',
  calendar: '노드를 선택하고 날짜를 지정하면 달력에 표시됩니다',
};

export function TopBar() {
  const { viewMode, setSidebarOpen, setSettingsOpen } = useStore();

  return (
    <header className="topbar">
      <button className="topbar-hamburger" onClick={() => setSidebarOpen(true)} aria-label="메뉴">
        ☰
      </button>
      <span className="topbar-logo">🗺 mindmap</span>
      <span className="topbar-hint">{HINTS[viewMode]}</span>
      <button className="topbar-settings-btn" onClick={() => setSettingsOpen(true)} aria-label="설정">
        ⚙
      </button>
    </header>
  );
}
