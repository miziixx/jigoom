import { useState } from "react";
import { Link } from "react-router-dom";
import { resolveSavedBirth } from "../lib/profile";
import { activateProfile, activeProfileId, loadProfileList, saveProfileToList, type SavedProfile } from "../lib/profileList";

/**
 * 햄버거 사이드바 (C-4, 재기획안 §5).
 *
 * "홈은 상품 진열만 남기고 보조 기능을 전부 수납" — 저장된 사주 전환(신규, profileList.ts)과
 * 내 기록·이름 감정·작명·개인정보 처리방침·어떻게 계산하나요(C-3에서 만듦)를 한 곳에 모은다.
 * "설정(테마 등)"은 §5가 언급하지만 이 앱에 테마 기능 자체가 아직 없어(구현 없음), 빈 페이지를
 * 만들지 않고 이번 스코프에서 제외한다 — 워크로그에 기록.
 */
export default function Sidebar() {
  const [open, setOpen] = useState(false);
  const [profiles, setProfiles] = useState<SavedProfile[]>(() => loadProfileList());
  const [activeId, setActiveId] = useState<string | null>(() => activeProfileId());

  function refresh() {
    setProfiles(loadProfileList());
    setActiveId(activeProfileId());
  }

  function handleActivate(id: string) {
    activateProfile(id);
    setOpen(false);
    // 이미 열려 있는 화면들(오늘 운세 등)이 컴포넌트 마운트 시점에만 저장된 명식을 읽으므로,
    // 전환이 화면 전체에 확실히 반영되도록 새로고침한다.
    window.location.reload();
  }

  function handleSaveCurrent() {
    const current = resolveSavedBirth();
    if (!current) return;
    const label = window.prompt("이 명식을 어떤 이름으로 저장할까요?", current.displayName ?? "");
    if (label === null) return;
    saveProfileToList(current, label);
    refresh();
  }

  return (
    <>
      <button type="button" className="sidebar-toggle" aria-label="메뉴 열기" onClick={() => setOpen(true)}>
        ☰
      </button>
      {open && (
        <div className="sidebar-overlay" onClick={() => setOpen(false)}>
          <nav className="sidebar-panel" onClick={(e) => e.stopPropagation()} aria-label="보조 메뉴">
            <div className="sidebar-panel__head">
              <span className="sidebar-panel__title">메뉴</span>
              <button type="button" className="sidebar-close" aria-label="메뉴 닫기" onClick={() => setOpen(false)}>
                ✕
              </button>
            </div>

            <div className="sidebar-section">
              <div className="sidebar-section__head">
                <span>저장된 사주 전환</span>
                <button type="button" className="sidebar-add" onClick={handleSaveCurrent}>
                  + 지금 명식 저장
                </button>
              </div>
              {profiles.length === 0 ? (
                <p className="sidebar-empty">아직 저장된 사주가 없어요. 사주를 본 뒤 "지금 명식 저장"을 눌러보세요.</p>
              ) : (
                <ul className="sidebar-profile-list">
                  {profiles.map((p) => (
                    <li key={p.id}>
                      <button
                        type="button"
                        className={`sidebar-profile${activeId === p.id ? " sidebar-profile--active" : ""}`}
                        onClick={() => handleActivate(p.id)}
                      >
                        {p.label}
                        {activeId === p.id && <span className="sidebar-profile__badge">사용중</span>}
                      </button>
                    </li>
                  ))}
                </ul>
              )}
            </div>

            <div className="sidebar-section">
              <ul className="sidebar-links">
                <li>
                  <Link to="/history" onClick={() => setOpen(false)}>
                    내 기록
                  </Link>
                </li>
                <li>
                  <Link to="/naming" onClick={() => setOpen(false)}>
                    이름 감정·작명
                  </Link>
                </li>
                <li>
                  <Link to="/methodology" onClick={() => setOpen(false)}>
                    어떻게 계산하나요?
                  </Link>
                </li>
                <li>
                  <Link to="/privacy" onClick={() => setOpen(false)}>
                    개인정보 처리방침
                  </Link>
                </li>
              </ul>
            </div>
          </nav>
        </div>
      )}
    </>
  );
}
