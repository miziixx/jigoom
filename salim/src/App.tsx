import { HashRouter, Route, Routes } from "react-router-dom";
import Layout from "./components/Layout";
import TodayPage from "./pages/TodayPage";
import ChoresPage from "./pages/ChoresPage";
import SupplyPage from "./pages/SupplyPage";
import LedgerPage from "./pages/LedgerPage";
import StashPage from "./pages/StashPage";
import EncyclopediaPage from "./pages/EncyclopediaPage";

// HashRouter: 정적 호스팅·Capacitor(file://)에서도 새로고침/딥링크가 안전.
export default function App() {
  return (
    <HashRouter>
      <Routes>
        <Route element={<Layout />}>
          <Route index element={<TodayPage />} />
          <Route path="chores" element={<ChoresPage />} />
          <Route path="supply" element={<SupplyPage />} />
          <Route path="ledger" element={<LedgerPage />} />
          <Route path="stash" element={<StashPage />} />
          <Route path="encyclopedia" element={<EncyclopediaPage />} />
        </Route>
      </Routes>
    </HashRouter>
  );
}
