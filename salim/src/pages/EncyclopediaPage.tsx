import { useMemo, useState } from "react";
import { useSearchParams } from "react-router-dom";
import { useStore } from "../store/useStore";
import { HOWTO_CATEGORIES, HOWTOS, findHowto, searchHowtos } from "../data/howtos";
import type { HowToEntry } from "../types";

export default function EncyclopediaPage() {
  const [params, setParams] = useSearchParams();
  const selectedId = params.get("id");
  const selected = selectedId ? findHowto(selectedId) : undefined;

  const [q, setQ] = useState("");
  const [cat, setCat] = useState<string | null>(null);

  const results = useMemo(() => (q.trim() ? searchHowtos(q) : []), [q]);
  const browse = useMemo(
    () => (cat ? HOWTOS.filter((h) => h.category === cat) : []),
    [cat],
  );

  if (selected) {
    return <Detail entry={selected} onBack={() => setParams({})} />;
  }

  return (
    <div className="page">
      <input
        className="search big"
        placeholder="🔍 증상·문제로 검색 (쉰내, 곰팡이, 변기 막힘…)"
        value={q}
        onChange={(e) => setQ(e.target.value)}
        autoFocus
      />

      {q.trim() ? (
        results.length === 0 ? (
          <div className="empty">
            <p>'{q}' 검색 결과가 없어요.</p>
            <p className="dim">다른 단어로 찾거나 아래 카테고리를 둘러보세요.</p>
          </div>
        ) : (
          <ul className="list">
            {results.map((h) => (
              <li key={h.id} className="card howto-row" onClick={() => setParams({ id: h.id })}>
                <span>{h.emergency ? "🚨 " : ""}{h.title}</span>
                <span className="dim small">{h.category}</span>
              </li>
            ))}
          </ul>
        )
      ) : (
        <>
          <h2 className="sec-title">카테고리 둘러보기</h2>
          <div className="cat-grid">
            {HOWTO_CATEGORIES.map((c) => (
              <button
                key={c}
                className={`cat-card ${cat === c ? "cat-on" : ""}`}
                onClick={() => setCat(cat === c ? null : c)}
              >
                {c}
              </button>
            ))}
          </div>
          {cat && (
            <ul className="list">
              {browse.map((h) => (
                <li key={h.id} className="card howto-row" onClick={() => setParams({ id: h.id })}>
                  <span>{h.emergency ? "🚨 " : ""}{h.title}</span>
                </li>
              ))}
            </ul>
          )}
        </>
      )}
    </div>
  );
}

function Detail({ entry, onBack }: { entry: HowToEntry; onBack: () => void }) {
  const chores = useStore((s) => s.chores);
  const addChoreByName = useStore((s) => s.addChoreByName);

  return (
    <div className="page">
      <button className="link-btn" onClick={onBack}>
        ← 목록으로
      </button>

      <article className={`howto ${entry.emergency ? "emergency" : ""}`}>
        <h1 className="howto-title">
          {entry.emergency ? "🚨 " : ""}
          {entry.title}
        </h1>

        {entry.emergency && entry.caution && (
          <div className="caution top">⚠️ {entry.caution}</div>
        )}

        {entry.cause && (
          <section className="howto-sec">
            <h3>왜 이런가</h3>
            <p>{entry.cause}</p>
          </section>
        )}

        <section className="howto-sec">
          <h3>해결 순서</h3>
          <ol>
            {entry.steps.map((s, i) => (
              <li key={i}>{s}</li>
            ))}
          </ol>
        </section>

        {entry.prevent && entry.prevent.length > 0 && (
          <section className="howto-sec">
            <h3>예방 팁</h3>
            <ul>
              {entry.prevent.map((p, i) => (
                <li key={i}>{p}</li>
              ))}
            </ul>
          </section>
        )}

        {!entry.emergency && entry.caution && <div className="caution">⚠️ {entry.caution}</div>}

        {entry.relatedChores && entry.relatedChores.length > 0 && (
          <section className="howto-sec">
            <h3>관련 집안일</h3>
            <div className="sugg-row">
              {entry.relatedChores.map((name) => {
                const owned = chores.some((c) => c.name === name);
                return (
                  <button
                    key={name}
                    className="chip"
                    disabled={owned}
                    onClick={() => addChoreByName(name)}
                  >
                    {owned ? `✓ ${name}` : `+ ${name} 추가`}
                  </button>
                );
              })}
            </div>
          </section>
        )}
      </article>
    </div>
  );
}
