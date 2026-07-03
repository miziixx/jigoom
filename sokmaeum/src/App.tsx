import { HashRouter, Route, Routes } from "react-router-dom";
import Layout from "./components/Layout";
import LandingPage from "./pages/LandingPage";
import SajuPage from "./pages/SajuPage";
import TarotPage from "./pages/TarotPage";
import ComboPage from "./pages/ComboPage";
import TodayPage from "./pages/TodayPage";
import MysticPage from "./pages/MysticPage";
import FortunePage from "./pages/FortunePage";
import FlowPage from "./pages/FlowPage";
import HistoryPage from "./pages/HistoryPage";
import ComparePage from "./pages/ComparePage";

export default function App() {
  return (
    <HashRouter>
      <Routes>
        <Route element={<Layout />}>
          <Route index element={<LandingPage />} />
          <Route path="mystic" element={<MysticPage />} />
          <Route path="saju" element={<SajuPage />} />
          <Route path="tarot" element={<TarotPage />} />
          <Route path="combo" element={<ComboPage />} />
          <Route path="today" element={<TodayPage />} />
          <Route path="fortune" element={<FortunePage />} />
          <Route path="flow" element={<FlowPage />} />
          <Route path="history" element={<HistoryPage />} />
          <Route path="compare" element={<ComparePage />} />
        </Route>
      </Routes>
    </HashRouter>
  );
}
