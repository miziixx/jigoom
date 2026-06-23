import { useMemo, useState } from "react";
import { useStore } from "../store/useStore";
import { daysSince, shortKor } from "../lib/date";
import Icon from "../components/Icon";

// 보관 (1-7) + 잠자는 물건 코칭 (5-5).
export default function StashPage() {
  const stash = useStore((s) => s.stash);
  const addStash = useStore((s) => s.addStash);
  const touchStash = useStore((s) => s.touchStash);
  const deleteStash = useStore((s) => s.deleteStash);
  const declutterStash = useStore((s) => s.declutterStash);

  const [name, setName] = useState("");
  const [location, setLocation] = useState("");
  const [q, setQ] = useState("");

  // 1년 넘게 안 건드린 물건 (5-5)
  const sleeping = useMemo(
    () => stash.filter((it) => (daysSince(it.lastTouched) ?? 0) > 365),
    [stash],
  );

  const add = () => {
    if (!name.trim() || !location.trim()) return;
    addStash(name.trim(), location.trim());
    setName("");
    setLocation("");
  };

  const filtered = useMemo(() => {
    const query = q.trim().toLowerCase();
    if (!query) return stash;
    return stash.filter(
      (it) =>
        it.name.toLowerCase().includes(query) || it.location.toLowerCase().includes(query),
    );
  }, [stash, q]);

  return (
    <div className="page">
      <div className="card row-form">
        <input placeholder="물건 이름" value={name} onChange={(e) => setName(e.target.value)} />
        <input placeholder="보관 위치 (예: 베란다 수납장)" value={location} onChange={(e) => setLocation(e.target.value)} />
        <button className="btn" onClick={add}>
          추가
        </button>
      </div>

      {/* 5-5: 잠자는 물건 코칭 */}
      {sleeping.length > 0 && (
        <div className="banner">
          <div className="small">😴 1년 넘게 안 쓴 물건이 {sleeping.length}개 있어요. 비울까요?</div>
          <div className="sugg-row">
            {sleeping.map((it) => (
              <button key={it.id} className="chip chip-ico" onClick={() => declutterStash(it.id)}>
                <Icon name="trash" size={14} /> {it.name} 비우기
              </button>
            ))}
          </div>
        </div>
      )}

      {stash.length > 0 && (
        <div className="search-wrap">
          <Icon name="search" size={18} className="search-ico" />
          <input
            className="search"
            placeholder="이름·위치로 검색"
            value={q}
            onChange={(e) => setQ(e.target.value)}
          />
        </div>
      )}

      {stash.length === 0 ? (
        <div className="empty">
          <p>보관 중인 물건이 없어요.</p>
          <p className="dim">어디 뒀는지 잊기 쉬운 물건을 위치와 함께 적어두세요.</p>
        </div>
      ) : (
        <ul className="list">
          {filtered.map((it) => (
            <li key={it.id} className="card stash-item">
              <div className="stash-main">
                <div className="chore-name">{it.name}</div>
                <div className="chore-sub dim stash-loc">
                  <Icon name="pin" size={13} /> {it.location} · 마지막 {shortKor(it.lastTouched)}
                </div>
              </div>
              <div className="stash-actions">
                <button className="btn ghost sm" onClick={() => touchStash(it.id)}>
                  오늘 꺼냈어요
                </button>
                <button className="icon-btn" onClick={() => deleteStash(it.id)} aria-label="삭제">
                  <Icon name="close" size={16} />
                </button>
              </div>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
