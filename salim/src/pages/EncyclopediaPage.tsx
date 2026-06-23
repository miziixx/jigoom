import { useMemo, useState } from "react";
import { useSearchParams } from "react-router-dom";
import { useStore } from "../store/useStore";
import {
  HOWTO_CATEGORIES,
  HOWTOS,
  FEATURED_HOWTOS,
  countByCategory,
  findHowto,
  searchHowtos,
} from "../data/howtos";
import type { HowToEntry } from "../types";

function HowtoRow({ h, onClick }: { h: HowToEntry; onClick: () => void }) {
  return (
    <li className="card howto-row" onClick={onClick}>
      <div className="howto-row-main">
        <div className="howto-row-title">
          {h.emergency ? "🚨 " : ""}
          {h.title}
        </div>
        {h.summary && <div className="howto-row-sum dim small">{h.summary}</div>}
      </div>
      <span className="howto-row-arr dim">›</span>
    </li>
  );
}

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

  const open = (id: string) => setParams({ id });

  return (
    <div className="page">
      <input
        className="search big"
        placeholder="🔍 증상·문제로 검색 (쉰내, 곰팡이, 변기 막힘…)"
        value={q}
        onChange={(e) => setQ(e.target.value)}
      />

      {q.trim() ? (
        results.length === 0 ? (
          <div className="empty">
            <p>'{q}' 검색 결과가 없어요.</p>
            <p className="dim">다른 단어로 찾거나 아래 카테고리를 둘러보세요.</p>
          </div>
        ) : (
          <>
            <div className="dim small enc-count">{results.length}개 항목</div>
            <ul className="list">
              {results.map((h) => (
                <HowtoRow key={h.id} h={h} onClick={() => open(h.id)} />
              ))}
            </ul>
          </>
        )
      ) : (
        <>
          {/* 자주 찾는 항목 */}
          <h2 className="sec-title">자주 찾는 항목</h2>
          <ul className="list">
            {FEATURED_HOWTOS.map((h) => (
              <HowtoRow key={h.id} h={h} onClick={() => open(h.id)} />
            ))}
          </ul>

          {/* 카테고리 둘러보기 (항목 수 표시) */}
          <h2 className="sec-title">카테고리 둘러보기</h2>
          <div className="cat-grid">
            {HOWTO_CATEGORIES.map((c) => (
              <button
                key={c}
                className={`cat-card ${cat === c ? "cat-on" : ""}`}
                onClick={() => setCat(cat === c ? null : c)}
              >
                <span className="cat-card-name">{c}</span>
                <span className="cat-card-count dim">{countByCategory(c)}</span>
              </button>
            ))}
          </div>
          {cat && (
            <ul className="list">
              {browse.map((h) => (
                <HowtoRow key={h.id} h={h} onClick={() => open(h.id)} />
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
        <div className="dim small howto-cat">{entry.category}</div>
        <h1 className="howto-title">
          {entry.emergency ? "🚨 " : ""}
          {entry.title}
        </h1>

        {entry.summary && <p className="howto-lead">{entry.summary}</p>}

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
