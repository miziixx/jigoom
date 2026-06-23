import { useMemo, useState } from "react";
import { useStore } from "../store/useStore";
import { shortKor } from "../lib/date";

// 보관 (1-7): 물건+위치 추가/검색/삭제, '오늘 꺼냈어요'(lastTouched 갱신).
// '잠자는 물건' 코칭(5-5)은 5단계에서.
export default function StashPage() {
  const stash = useStore((s) => s.stash);
  const addStash = useStore((s) => s.addStash);
  const touchStash = useStore((s) => s.touchStash);
  const deleteStash = useStore((s) => s.deleteStash);

  const [name, setName] = useState("");
  const [location, setLocation] = useState("");
  const [q, setQ] = useState("");

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

      {stash.length > 0 && (
        <input className="search" placeholder="🔍 이름·위치로 검색" value={q} onChange={(e) => setQ(e.target.value)} />
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
                <div className="chore-sub dim">
                  📍 {it.location} · 마지막 {shortKor(it.lastTouched)}
                </div>
              </div>
              <div className="stash-actions">
                <button className="btn ghost sm" onClick={() => touchStash(it.id)}>
                  오늘 꺼냈어요
                </button>
                <button className="icon-btn" onClick={() => deleteStash(it.id)} aria-label="삭제">
                  ✕
                </button>
              </div>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
