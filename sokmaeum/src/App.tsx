import { BrowserRouter, Route, Routes } from "react-router-dom";
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
import SeoPage from "./pages/SeoPage";

export default function App() {
  return (
    <BrowserRouter>
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
          <Route path="seo/:slug" element={<SeoPage />} />
        </Route>
      </Routes>
    </BrowserRouter>
  );
}
