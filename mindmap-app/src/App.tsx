import { TopBar } from './components/TopBar';
import { OutlineView } from './components/OutlineView';
import { MindMapView } from './components/MindMapView';
import { BacklinkPanel } from './components/BacklinkPanel';
import { useStore } from './store/useStore';
import './App.css';

export default function App() {
  const { viewMode } = useStore();

  return (
    <div className="app">
      <TopBar />
      <div className="main-area">
        <div className="canvas">
          {viewMode === 'outline' ? <OutlineView /> : <MindMapView />}
        </div>
      </div>
      <div className="bottom-panel">
        <BacklinkPanel />
      </div>
    </div>
  );
}
