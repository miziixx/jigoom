import { NavLink } from "react-router-dom";
import Icon, { type IconName } from "./Icon";

const TABS: { to: string; label: string; icon: IconName }[] = [
  { to: "/", label: "오늘", icon: "home" },
  { to: "/chores", label: "집안일", icon: "clean" },
  { to: "/supply", label: "살림", icon: "basket" },
  { to: "/ledger", label: "가계부", icon: "wallet" },
  { to: "/stash", label: "보관", icon: "archive" },
  { to: "/encyclopedia", label: "백과", icon: "book" },
];

export default function BottomTabBar() {
  return (
    <nav className="tabbar">
      {/* 데스크톱 사이드바 상단 브랜드 (모바일에선 CSS로 숨김) */}
      <div className="tab-brand">
        <Icon name="sprout" size={20} />
        <span>살림 관리</span>
      </div>
      {TABS.map((t) => (
        <NavLink
          key={t.to}
          to={t.to}
          end={t.to === "/"}
          className={({ isActive }) => `tab ${isActive ? "tab-active" : ""}`}
        >
          <span className="tab-icon">
            <Icon name={t.icon} size={22} />
          </span>
          <span className="tab-label">{t.label}</span>
        </NavLink>
      ))}
    </nav>
  );
}
