import { Outlet, useLocation, useNavigate } from "react-router-dom";
import BottomTabBar from "./BottomTabBar";

const TITLES: Record<string, string> = {
  "/": "오늘",
  "/chores": "집안일",
  "/supply": "살림",
  "/ledger": "가계부",
  "/stash": "보관",
  "/encyclopedia": "살림백과",
};

export default function Layout() {
  const loc = useLocation();
  const navigate = useNavigate();
  const title = TITLES[loc.pathname] ?? "살림 관리";

  return (
    <div className="layout">
      <header className="appbar">
        <span className="appbar-title">{title}</span>
        {/* 3-6: 어느 화면에서든 살림백과 검색 바로가기 */}
        {loc.pathname !== "/encyclopedia" && (
          <button
            className="appbar-search"
            aria-label="살림백과 검색"
            onClick={() => navigate("/encyclopedia")}
          >
            🔍
          </button>
        )}
      </header>

      <main className="content">
        <Outlet />
      </main>

      <BottomTabBar />
    </div>
  );
}
