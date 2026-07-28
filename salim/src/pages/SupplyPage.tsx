import { useMemo, useState } from "react";
import { useStore } from "../store/useStore";
import { avgGapDays, isRunningLow, predictEmptyDate } from "../lib/predict";
import { daysBetween, shortKor, todayStr } from "../lib/date";
import Icon from "../components/Icon";

type Mode = "inventory" | "shopping";

export default function SupplyPage() {
  const [mode, setMode] = useState<Mode>("inventory");
  return (
    <div className="page">
      <div className="seg">
        <button className={mode === "inventory" ? "seg-on" : ""} onClick={() => setMode("inventory")}>
          재고
        </button>
        <button className={mode === "shopping" ? "seg-on" : ""} onClick={() => setMode("shopping")}>
          장보기
        </button>
      </div>
      {mode === "inventory" ? <Inventory /> : <Shopping />}
    </div>
  );
}

/* ── 재고 (4-1, 4-4) ───────────────────────────── */
function Inventory() {
  const inventory = useStore((s) => s.inventory);
  const addInventory = useStore((s) => s.addInventory);
  const adjustQty = useStore((s) => s.adjustQty);
  const setThreshold = useStore((s) => s.setThreshold);
  const deleteInventory = useStore((s) => s.deleteInventory);
  const addShopping = useStore((s) => s.addShopping);

  const [name, setName] = useState("");
  const [qty, setQty] = useState(1);
  const [threshold, setT] = useState(1);

  const add = () => {
    if (!name.trim()) return;
    addInventory(name.trim(), qty, threshold);
    setName("");
    setQty(1);
    setT(1);
  };

  return (
    <>
      <div className="card row-form">
        <input placeholder="물건 이름 (예: 휴지)" value={name} onChange={(e) => setName(e.target.value)} />
        <div className="num-row">
          <label>
            수량
            <input type="number" min={0} value={qty} onChange={(e) => setQty(Number(e.target.value))} />
          </label>
          <label>
            알림기준
            <input type="number" min={0} value={threshold} onChange={(e) => setT(Number(e.target.value))} />
          </label>
        </div>
        <button className="btn" onClick={add}>
          추가
        </button>
      </div>

      {inventory.length === 0 ? (
        <div className="empty">
          <p>등록된 재고가 없어요.</p>
          <p className="dim">자주 떨어지는 생필품을 추가해 보세요.</p>
        </div>
      ) : (
        <ul className="list">
          {inventory.map((it) => {
            const low = isRunningLow(it);
            const gap = avgGapDays(it);
            const predicted = predictEmptyDate(it);
            const dleft = predicted ? daysBetween(todayStr(), predicted) : null;
            return (
              <li key={it.id} className={`card inv ${low ? "due" : ""}`}>
                <div className="inv-head">
                  <span className="inv-name">
                    {it.name}
                    {low && <span className="badge">부족</span>}
                  </span>
                  <button className="icon-btn" onClick={() => deleteInventory(it.id)} aria-label="삭제">
                    <Icon name="close" size={16} />
                  </button>
                </div>
                <div className="qty-row">
                  <button className="qty-btn" onClick={() => adjustQty(it.id, -1)}>
                    −
                  </button>
                  <span className="qty">{it.qty}</span>
                  <button className="qty-btn" onClick={() => adjustQty(it.id, +1)}>
                    +
                  </button>
                  <label className="inline-th">
                    알림 ≤
                    <input
                      type="number"
                      min={0}
                      value={it.threshold}
                      onChange={(e) => setThreshold(it.id, Number(e.target.value))}
                    />
                  </label>
                </div>
                {gap != null && (
                  <div className="dim small">
                    보통 {gap}일 써요
                    {dleft != null && ` · ${dleft <= 0 ? "지금쯤 떨어질 때" : `약 ${dleft}일 뒤 소진 예상`}`}
                  </div>
                )}
                {low && (
                  <button className="btn ghost sm" onClick={() => addShopping(it.name, it.id)}>
                    장보기에 추가
                  </button>
                )}
              </li>
            );
          })}
        </ul>
      )}
    </>
  );
}

/* ── 장보기 (4-2, 4-3) ─────────────────────────── */
function Shopping() {
  const shopping = useStore((s) => s.shopping);
  const inventory = useStore((s) => s.inventory);
  const addShopping = useStore((s) => s.addShopping);
  const toggleShopping = useStore((s) => s.toggleShopping);
  const setShoppingPrice = useStore((s) => s.setShoppingPrice);
  const deleteShopping = useStore((s) => s.deleteShopping);
  const purchaseChecked = useStore((s) => s.purchaseChecked);

  const [name, setName] = useState("");

  // 부족 재고 중 아직 장보기에 없는 것 자동 노출
  const suggestions = useMemo(() => {
    const inList = new Set(shopping.map((x) => x.fromInventoryId).filter(Boolean));
    return inventory.filter((it) => isRunningLow(it) && !inList.has(it.id));
  }, [inventory, shopping]);

  const checkedCount = shopping.filter((x) => x.checked).length;

  return (
    <>
      <div className="card row-form">
        <input
          placeholder="살 것 추가"
          value={name}
          onChange={(e) => setName(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter" && name.trim()) {
              addShopping(name.trim());
              setName("");
            }
          }}
        />
        <button
          className="btn"
          onClick={() => {
            if (!name.trim()) return;
            addShopping(name.trim());
            setName("");
          }}
        >
          추가
        </button>
      </div>

      {suggestions.length > 0 && (
        <div className="banner">
          <div className="dim small">부족한 재고예요. 담을까요?</div>
          <div className="sugg-row">
            {suggestions.map((it) => (
              <button key={it.id} className="chip" onClick={() => addShopping(it.name, it.id)}>
                + {it.name}
              </button>
            ))}
          </div>
        </div>
      )}

      {shopping.length === 0 ? (
        <div className="empty">
          <p>장보기 목록이 비어 있어요.</p>
        </div>
      ) : (
        <>
          <ul className="list">
            {shopping.map((x) => (
              <li key={x.id} className="card shop-item">
                <label className={x.checked ? "checked" : ""}>
                  <input type="checkbox" checked={x.checked} onChange={() => toggleShopping(x.id)} />
                  <span>{x.name}</span>
                </label>
                <div className="shop-right">
                  <input
                    className="price-input"
                    type="number"
                    inputMode="numeric"
                    placeholder="가격"
                    value={x.price ?? ""}
                    onChange={(e) => setShoppingPrice(x.id, Number(e.target.value))}
                  />
                  <button className="icon-btn" onClick={() => deleteShopping(x.id)} aria-label="삭제">
                    <Icon name="close" size={16} />
                  </button>
                </div>
              </li>
            ))}
          </ul>
          {checkedCount > 0 && (
            <div className="sticky-action">
              <button className="btn block" onClick={purchaseChecked}>
                구매 완료 ({checkedCount}) — 재고 복구 · 가계부 기록
              </button>
            </div>
          )}
        </>
      )}

      <RecentPurchases />
    </>
  );
}

function RecentPurchases() {
  const logs = useStore((s) => s.logs);
  const purchases = logs.filter((l) => l.type === "purchase").slice(0, 5);
  if (purchases.length === 0) return null;
  return (
    <section>
      <h2 className="sec-title">최근 구매</h2>
      <ul className="timeline">
        {purchases.map((l) => (
          <li key={l.id} className="tl-row">
            <span className="tl-dot" />
            <span>{l.label}</span>
            <span className="dim small"> · {shortKor(l.date)}</span>
          </li>
        ))}
      </ul>
    </section>
  );
}
