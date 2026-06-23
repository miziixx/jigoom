import { useMemo, useState } from "react";
import { useStore } from "../store/useStore";
import { byCategory, monthExpenses, sumAmount } from "../lib/stats";
import { todayStr } from "../lib/date";

const CATEGORIES = ["식비", "장보기", "생활용품", "공과금", "교통", "여가", "기타"];

function won(n: number): string {
  return `${n.toLocaleString()}원`;
}

export default function LedgerPage() {
  const expenses = useStore((s) => s.expenses);
  const addExpense = useStore((s) => s.addExpense);
  const deleteExpense = useStore((s) => s.deleteExpense);
  const budget = useStore((s) => s.settings.monthlyBudget);
  const setSetting = useStore((s) => s.setSetting);

  const [amount, setAmount] = useState("");
  const [category, setCategory] = useState(CATEGORIES[0]);
  const [memo, setMemo] = useState("");
  const [date, setDate] = useState(todayStr());

  const month = todayStr().slice(0, 7);
  const thisMonth = useMemo(() => monthExpenses(expenses, month), [expenses, month]);
  const total = useMemo(() => sumAmount(thisMonth), [thisMonth]);
  const cats = useMemo(() => byCategory(thisMonth), [thisMonth]);
  const max = cats[0]?.amount ?? 0;

  const add = () => {
    const a = Number(amount);
    if (!a || a <= 0) return;
    addExpense({ date, amount: a, category, memo: memo.trim() || undefined });
    setAmount("");
    setMemo("");
  };

  const over = budget != null && budget > 0 && total > budget;

  return (
    <div className="page">
      {/* 월 요약 (5-2) */}
      <section className="card">
        <div className="ledger-total-row">
          <span className="dim">이번 달 지출</span>
          <span className="ledger-total">{won(total)}</span>
        </div>
        {budget != null && budget > 0 && (
          <>
            <div className="gauge-bar">
              <div
                className="gauge-fill"
                style={{
                  width: `${Math.min(100, (total / budget) * 100)}%`,
                  background: over ? "var(--danger)" : "var(--green)",
                }}
              />
            </div>
            <div className="small dim">
              예산 {won(budget)} 중 {Math.round((total / budget) * 100)}%
              {over ? " · 예산을 넘었어요" : ` · ${won(budget - total)} 남음`}
            </div>
          </>
        )}
        <BudgetEditor budget={budget} onSave={(v) => setSetting("monthlyBudget", v)} />
      </section>

      {/* 카테고리 비중 (5-2) */}
      {cats.length > 0 && (
        <section className="card">
          <h2 className="sec-title">카테고리</h2>
          <div className="cat-bars">
            {cats.map((c) => (
              <div key={c.category} className="cat-bar">
                <span className="cat-bar-label">{c.category}</span>
                <div className="cat-bar-track">
                  <div className="cat-bar-fill" style={{ width: `${max ? (c.amount / max) * 100 : 0}%` }} />
                </div>
                <span className="cat-bar-amt small">{won(c.amount)}</span>
              </div>
            ))}
          </div>
        </section>
      )}

      {/* 지출 추가 (5-1) */}
      <section className="card row-form">
        <div className="num-row">
          <label style={{ flex: 2 }}>
            금액
            <input
              type="number"
              inputMode="numeric"
              placeholder="0"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
            />
          </label>
          <label>
            날짜
            <input type="date" value={date} onChange={(e) => setDate(e.target.value)} />
          </label>
        </div>
        <div className="num-row">
          <label style={{ flex: 1 }}>
            분류
            <select value={category} onChange={(e) => setCategory(e.target.value)}>
              {CATEGORIES.map((c) => (
                <option key={c}>{c}</option>
              ))}
            </select>
          </label>
        </div>
        <input placeholder="메모 (선택)" value={memo} onChange={(e) => setMemo(e.target.value)} />
        <button className="btn" onClick={add}>
          지출 추가
        </button>
      </section>

      {/* 내역 (5-1) */}
      <section>
        <h2 className="sec-title">이번 달 내역</h2>
        {thisMonth.length === 0 ? (
          <p className="dim small">아직 기록된 지출이 없어요.</p>
        ) : (
          <ul className="list">
            {thisMonth.map((e) => (
              <li key={e.id} className="card expense-row">
                <div>
                  <div className="chore-name">
                    {e.category} · {won(e.amount)}
                  </div>
                  <div className="chore-sub dim">
                    {e.date}
                    {e.memo ? ` · ${e.memo}` : ""}
                  </div>
                </div>
                <button className="icon-btn" onClick={() => deleteExpense(e.id)} aria-label="삭제">
                  ✕
                </button>
              </li>
            ))}
          </ul>
        )}
      </section>
    </div>
  );
}

function BudgetEditor({ budget, onSave }: { budget?: number; onSave: (v: number) => void }) {
  const [editing, setEditing] = useState(false);
  const [val, setVal] = useState(String(budget ?? ""));
  if (!editing) {
    return (
      <button className="link-btn" onClick={() => setEditing(true)}>
        {budget ? "월 예산 수정" : "월 예산 설정"}
      </button>
    );
  }
  return (
    <div className="num-row" style={{ marginTop: 8 }}>
      <input
        type="number"
        inputMode="numeric"
        placeholder="월 예산 (원)"
        value={val}
        onChange={(e) => setVal(e.target.value)}
      />
      <button
        className="btn sm"
        onClick={() => {
          onSave(Number(val) || 0);
          setEditing(false);
        }}
      >
        저장
      </button>
    </div>
  );
}
