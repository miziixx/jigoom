import { NavLink, Outlet } from "react-router-dom";

const NAV_ITEMS = [
  { to: "/", label: "홈", end: true },
  { to: "/saju", label: "사주" },
  { to: "/tarot", label: "타로" },
  { to: "/combo", label: "통합" },
  { to: "/history", label: "기록" },
];

export default function Layout() {
  return (
    <div className="app-shell">
      <header className="app-header">
        <span className="app-title">인사이트 오라클</span>
        <nav className="app-nav">
          {NAV_ITEMS.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              end={item.end}
              className={({ isActive }) => (isActive ? "nav-link nav-link--active" : "nav-link")}
            >
              {item.label}
            </NavLink>
          ))}
        </nav>
      </header>
      <main className="app-main">
        <Outlet />
      </main>
      <footer className="app-footer">
        이 리딩은 자기이해와 판단 보조용입니다. 의학·법률·투자 등 중대한 결정의 근거로 사용하지 마세요.
      </footer>
    </div>
  );
}
