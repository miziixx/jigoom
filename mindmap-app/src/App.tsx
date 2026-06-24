import { useEffect } from 'react';
import { TopBar } from './components/TopBar';
import { Sidebar } from './components/Sidebar';
import { OutlineView } from './components/OutlineView';
import { MindMapView } from './components/MindMapView';
import { CalendarView } from './components/CalendarView';
import { BacklinkPanel } from './components/BacklinkPanel';
import { SettingsPanel } from './components/SettingsPanel';
import { useStore } from './store/useStore';
import './App.css';

export default function App() {
  const { viewMode, theme } = useStore();

  // 테마 CSS 변수 실시간 적용
  useEffect(() => {
    const r = document.documentElement.style;
    const { bgHue, bgSat, bgLight, textHue, textSat, textLight } = theme;
    r.setProperty('--bg',      `hsl(${bgHue},${bgSat}%,${bgLight}%)`);
    r.setProperty('--surface', `hsl(${bgHue},${bgSat}%,${bgLight + 3}%)`);
    r.setProperty('--border',  `hsl(${bgHue},${bgSat}%,${bgLight + 12}%)`);
    r.setProperty('--text',    `hsl(${textHue},${textSat}%,${textLight}%)`);
    r.setProperty('--dim',     `hsl(${textHue},${textSat}%,${Math.max(30, textLight - 32)}%)`);
    r.setProperty('--selected-bg', `hsl(${bgHue},${bgSat + 10}%,${bgLight + 8}%)`);
  }, [theme]);

  return (
    <div className="app">
      <TopBar />
      <div className="main-layout">
        <Sidebar />
        <div className="main-area">
          <div className="canvas">
            {viewMode === 'outline'  && <OutlineView />}
            {viewMode === 'mindmap'  && <MindMapView />}
            {viewMode === 'calendar' && <CalendarView />}
          </div>
          {viewMode !== 'calendar' && (
            <div className="bottom-panel">
              <BacklinkPanel />
            </div>
          )}
        </div>
      </div>
      <SettingsPanel />
    </div>
  );
}
