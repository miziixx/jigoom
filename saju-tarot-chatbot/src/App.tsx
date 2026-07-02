import { HashRouter, Route, Routes } from "react-router-dom";
import Layout from "./components/Layout";
import LandingPage from "./pages/LandingPage";
import SajuPage from "./pages/SajuPage";
import TarotPage from "./pages/TarotPage";
import ComboPage from "./pages/ComboPage";
import HistoryPage from "./pages/HistoryPage";

export default function App() {
  return (
    <HashRouter>
      <Routes>
        <Route element={<Layout />}>
          <Route index element={<LandingPage />} />
          <Route path="saju" element={<SajuPage />} />
          <Route path="tarot" element={<TarotPage />} />
          <Route path="combo" element={<ComboPage />} />
          <Route path="history" element={<HistoryPage />} />
        </Route>
      </Routes>
    </HashRouter>
  );
}
