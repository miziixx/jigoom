import { HashRouter, Navigate, Route, Routes } from "react-router-dom";
import Layout from "./components/Layout";
import LandingPage from "./pages/LandingPage";
import SajuPage from "./pages/SajuPage";
import TarotPage from "./pages/TarotPage";
import TarotTodayPage from "./pages/TarotTodayPage";
import ComboPage from "./pages/ComboPage";
import FortunePage from "./pages/FortunePage";
import FlowPage from "./pages/FlowPage";
import HistoryPage from "./pages/HistoryPage";
import ComparePage from "./pages/ComparePage";
import CompatibilityPage from "./pages/CompatibilityPage";
import NamingPage from "./pages/NamingPage";
import PrivacyPage from "./pages/PrivacyPage";
import QualityDashboardPage from "./pages/QualityDashboardPage";

export default function App() {
  return (
    <HashRouter>
      <Routes>
        <Route element={<Layout />}>
          <Route index element={<LandingPage />} />
          <Route path="saju" element={<SajuPage />} />
          <Route path="tarot" element={<TarotPage />} />
          <Route path="tarot-today" element={<TarotTodayPage />} />
          <Route path="combo" element={<ComboPage />} />
          <Route path="today" element={<Navigate to="/fortune" replace />} />
          <Route path="fortune" element={<FortunePage />} />
          <Route path="flow" element={<FlowPage />} />
          <Route path="compatibility" element={<CompatibilityPage />} />
          <Route path="naming" element={<NamingPage />} />
          <Route path="history" element={<HistoryPage />} />
          <Route path="compare" element={<ComparePage />} />
          <Route path="privacy" element={<PrivacyPage />} />
          {/* 개발자 전용 운영 화면. 접근 제한은 페이지 내부(isQualityDashboardEnabled)에서 처리 */}
          <Route path="_internal/quality" element={<QualityDashboardPage />} />
        </Route>
      </Routes>
    </HashRouter>
  );
}
