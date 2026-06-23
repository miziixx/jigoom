import { useMemo, useState } from "react";
import { useStore } from "../store/useStore";
import {
  CHORE_CATEGORIES,
  CHORE_TEMPLATES,
} from "../data/choreTemplates";
import { CYCLE, CYCLE_KEYS, EFFORT_LABEL } from "../data/cycles";
import { isDue } from "../lib/chores";
import TipCard from "../components/TipCard";
import type { Chore, CycleKey, Effort } from "../types";

type Mode = "mine" | "pick";

export default function ChoresPage() {
  const [mode, setMode] = useState<Mode>("mine");
  const chores = useStore((s) => s.chores);

  return (
    <div className="page">
      <div className="seg">
        <button className={mode === "mine" ? "seg-on" : ""} onClick={() => setMode("mine")}>
          내 집안일 ({chores.length})
        </button>
        <button className={mode === "pick" ? "seg-on" : ""} onClick={() => setMode("pick")}>
          집안일 고르기
        </button>
      </div>
      {mode === "mine" ? <MyChores /> : <PickChores />}
    </div>
  );
}

/* ── 내 집안일 (1-2) ───────────────────────────── */
function MyChores() {
  const chores = useStore((s) => s.chores);
  const completeChore = useStore((s) => s.completeChore);

  if (chores.length === 0) {
    return (
      <div className="empty">
        <p>아직 담은 집안일이 없어요.</p>
        <p className="dim">'집안일 고르기'에서 우리 집에서 하는 걸 골라 담아보세요.</p>
      </div>
    );
  }

  return (
    <>
      <AddCustom />
      <ul className="list">
        {chores.map((c) => (
          <MyChoreItem key={c.id} chore={c} onDone={() => completeChore(c.id)} />
        ))}
      </ul>
    </>
  );
}

function MyChoreItem({ chore, onDone }: { chore: Chore; onDone: () => void }) {
  const [editing, setEditing] = useState(false);
  const due = isDue(chore);
  return (
    <li className={`card chore ${due ? "due" : ""}`}>
      <div className="chore-row">
        <button className="check" onClick={onDone} aria-label="완료">
          {due ? "○" : "✓"}
        </button>
        <div className="chore-main">
          <div className="chore-name">{chore.name}</div>
          <div className="chore-sub dim">
            {CYCLE[chore.cycle].label} · {chore.durationMin}분 · {EFFORT_LABEL[chore.effort]}
            {chore.lastDone ? ` · 마지막 ${chore.lastDone}` : " · 아직 안 함"}
          </div>
        </div>
        <button className="icon-btn" onClick={() => setEditing((v) => !v)} aria-label="수정">
          ⚙
        </button>
      </div>
      <TipCard tip={chore.tip} howtoId={chore.howtoId} />
      {editing && <ChoreEditor chore={chore} onClose={() => setEditing(false)} />}
    </li>
  );
}

function ChoreEditor({ chore, onClose }: { chore: Chore; onClose: () => void }) {
  const updateChore = useStore((s) => s.updateChore);
  const deleteChore = useStore((s) => s.deleteChore);
  const [name, setName] = useState(chore.name);
  const [cycle, setCycle] = useState<CycleKey>(chore.cycle);
  const [durationMin, setDuration] = useState(chore.durationMin);
  const [effort, setEffort] = useState<Effort>(chore.effort);

  return (
    <div className="editor">
      <label>
        이름
        <input value={name} onChange={(e) => setName(e.target.value)} />
      </label>
      <label>
        주기
        <select value={cycle} onChange={(e) => setCycle(e.target.value as CycleKey)}>
          {CYCLE_KEYS.map((k) => (
            <option key={k} value={k}>
              {CYCLE[k].label}
            </option>
          ))}
        </select>
      </label>
      <label>
        소요(분)
        <input
          type="number"
          min={1}
          value={durationMin}
          onChange={(e) => setDuration(Number(e.target.value))}
        />
      </label>
      <label>
        난이도
        <select value={effort} onChange={(e) => setEffort(e.target.value as Effort)}>
          <option value="easy">쉬움</option>
          <option value="normal">보통</option>
          <option value="heavy">힘듦</option>
        </select>
      </label>
      <div className="editor-actions">
        <button
          className="btn"
          onClick={() => {
            updateChore(chore.id, { name, cycle, durationMin, effort });
            onClose();
          }}
        >
          저장
        </button>
        <button
          className="btn danger"
          onClick={() => {
            if (confirm(`'${chore.name}'을(를) 삭제할까요?`)) deleteChore(chore.id);
          }}
        >
          삭제
        </button>
        <button className="btn ghost" onClick={onClose}>
          닫기
        </button>
      </div>
    </div>
  );
}

function AddCustom() {
  const addCustomChore = useStore((s) => s.addCustomChore);
  const [open, setOpen] = useState(false);
  const [name, setName] = useState("");
  const [cycle, setCycle] = useState<CycleKey>("weekly");
  const [durationMin, setDuration] = useState(10);
  const [effort, setEffort] = useState<Effort>("normal");

  if (!open) {
    return (
      <button className="btn block" onClick={() => setOpen(true)}>
        + 직접 추가
      </button>
    );
  }
  return (
    <div className="editor card">
      <label>
        이름
        <input value={name} onChange={(e) => setName(e.target.value)} placeholder="예: 어항 청소" />
      </label>
      <label>
        주기
        <select value={cycle} onChange={(e) => setCycle(e.target.value as CycleKey)}>
          {CYCLE_KEYS.map((k) => (
            <option key={k} value={k}>
              {CYCLE[k].label}
            </option>
          ))}
        </select>
      </label>
      <label>
        소요(분)
        <input type="number" min={1} value={durationMin} onChange={(e) => setDuration(Number(e.target.value))} />
      </label>
      <label>
        난이도
        <select value={effort} onChange={(e) => setEffort(e.target.value as Effort)}>
          <option value="easy">쉬움</option>
          <option value="normal">보통</option>
          <option value="heavy">힘듦</option>
        </select>
      </label>
      <div className="editor-actions">
        <button
          className="btn"
          onClick={() => {
            if (!name.trim()) return;
            addCustomChore({ name: name.trim(), category: "기타", cycle, durationMin, effort });
            setName("");
            setOpen(false);
          }}
        >
          추가
        </button>
        <button className="btn ghost" onClick={() => setOpen(false)}>
          취소
        </button>
      </div>
    </div>
  );
}

/* ── 집안일 고르기 (1-1) ───────────────────────── */
function PickChores() {
  const chores = useStore((s) => s.chores);
  const addChoresFromTemplates = useStore((s) => s.addChoresFromTemplates);
  const owned = useMemo(() => new Set(chores.map((c) => c.name)), [chores]);
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [openCat, setOpenCat] = useState<string | null>(CHORE_CATEGORIES[0] ?? null);

  const toggle = (name: string) =>
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(name)) next.delete(name);
      else next.add(name);
      return next;
    });

  const commit = () => {
    const templates = CHORE_TEMPLATES.filter((t) => selected.has(t.name));
    addChoresFromTemplates(templates);
    setSelected(new Set());
  };

  return (
    <>
      {CHORE_CATEGORIES.map((cat) => {
        const items = CHORE_TEMPLATES.filter((t) => t.category === cat);
        const open = openCat === cat;
        return (
          <div key={cat} className="acc">
            <button className="acc-head" onClick={() => setOpenCat(open ? null : cat)}>
              <span>{cat}</span>
              <span className="dim">{open ? "▾" : "▸"}</span>
            </button>
            {open && (
              <ul className="list">
                {items.map((t) => {
                  const has = owned.has(t.name);
                  const checked = selected.has(t.name);
                  return (
                    <li key={t.name} className="card pick-item">
                      <label className={has ? "dim" : ""}>
                        <input
                          type="checkbox"
                          disabled={has}
                          checked={has || checked}
                          onChange={() => toggle(t.name)}
                        />
                        <span className="pick-name">{t.name}</span>
                        <span className="chore-sub dim">
                          {CYCLE[t.defaultCycle].label} · {t.durationMin}분 · {EFFORT_LABEL[t.effort]}
                          {has ? " · 담음" : ""}
                        </span>
                      </label>
                    </li>
                  );
                })}
              </ul>
            )}
          </div>
        );
      })}

      {selected.size > 0 && (
        <div className="sticky-action">
          <button className="btn block" onClick={commit}>
            내 집안일에 담기 ({selected.size})
          </button>
        </div>
      )}
    </>
  );
}
