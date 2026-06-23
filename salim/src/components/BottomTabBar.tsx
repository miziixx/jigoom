import { NavLink } from "react-router-dom";

const TABS: { to: string; label: string; icon: string }[] = [
  { to: "/", label: "오늘", icon: "🏡" },
  { to: "/chores", label: "집안일", icon: "🧹" },
  { to: "/supply", label: "살림", icon: "🧺" },
  { to: "/ledger", label: "가계부", icon: "💰" },
  { to: "/stash", label: "보관", icon: "📦" },
  { to: "/encyclopedia", label: "백과", icon: "📖" },
];

export default function BottomTabBar() {
  return (
    <nav className="tabbar">
      {TABS.map((t) => (
        <NavLink
          key={t.to}
          to={t.to}
          end={t.to === "/"}
          className={({ isActive }) => `tab ${isActive ? "tab-active" : ""}`}
        >
          <span className="tab-icon">{t.icon}</span>
          <span className="tab-label">{t.label}</span>
        </NavLink>
      ))}
    </nav>
  );
}
