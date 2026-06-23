import { create } from "zustand";
import { persist, createJSONStorage } from "zustand/middleware";
import { appStorage, STORAGE_KEY } from "../lib/storage";
import { uid } from "../lib/id";
import { todayStr } from "../lib/date";
import { predictEmptyDate } from "../lib/predict";
import { CHORE_TEMPLATES } from "../data/choreTemplates";
import type {
  Chore,
  ChoreTemplate,
  Expense,
  InventoryItem,
  LogEntry,
  LogType,
  Settings,
  ShoppingItem,
  StashItem,
} from "../types";

interface AppState {
  chores: Chore[];
  inventory: InventoryItem[];
  shopping: ShoppingItem[];
  expenses: Expense[];
  stash: StashItem[];
  logs: LogEntry[];
  settings: Settings;

  // 설정
  setSetting: <K extends keyof Settings>(key: K, value: Settings[K]) => void;

  // 로그
  addLog: (type: LogType, label: string, meta?: Record<string, unknown>) => void;

  // 집안일
  addChoresFromTemplates: (templates: ChoreTemplate[]) => void;
  addChoreByName: (name: string) => void;
  addCustomChore: (input: Omit<Chore, "id" | "lastDone">) => void;
  completeChore: (id: string) => void;
  updateChore: (id: string, patch: Partial<Chore>) => void;
  deleteChore: (id: string) => void;

  // 보관
  addStash: (name: string, location: string) => void;
  touchStash: (id: string) => void;
  deleteStash: (id: string) => void;

  // 재고
  addInventory: (name: string, qty: number, threshold: number) => void;
  adjustQty: (id: string, delta: number) => void;
  setThreshold: (id: string, threshold: number) => void;
  deleteInventory: (id: string) => void;

  // 보관 — 잠자는 물건 (5-5)
  declutterStash: (id: string) => void;

  // 장보기
  addShopping: (name: string, fromInventoryId?: string) => void;
  toggleShopping: (id: string) => void;
  setShoppingPrice: (id: string, price: number) => void;
  deleteShopping: (id: string) => void;
  purchaseChecked: () => void;

  // 가계부
  addExpense: (input: Omit<Expense, "id">) => void;
  deleteExpense: (id: string) => void;
}

export const useStore = create<AppState>()(
  persist(
    (set, get) => ({
      chores: [],
      inventory: [],
      shopping: [],
      expenses: [],
      stash: [],
      logs: [],
      settings: {},

      setSetting: (key, value) =>
        set((s) => ({ settings: { ...s.settings, [key]: value } })),

      addLog: (type, label, meta) =>
        set((s) => ({
          logs: [
            { id: uid(), date: todayStr(), ts: Date.now(), type, label, meta },
            ...s.logs,
          ],
        })),

      addChoresFromTemplates: (templates) =>
        set((s) => {
          const existing = new Set(s.chores.map((c) => c.name));
          const toAdd: Chore[] = templates
            .filter((t) => !existing.has(t.name))
            .map((t) => ({
              id: uid(),
              name: t.name,
              category: t.category,
              cycle: t.defaultCycle,
              lastDone: null,
              durationMin: t.durationMin,
              effort: t.effort,
              weatherTag: t.weatherTag ?? null,
              seasonMonths: t.seasonMonths,
              tip: t.tip,
              howtoId: t.howtoId,
            }));
          return { chores: [...s.chores, ...toAdd] };
        }),

      addChoreByName: (name) => {
        // 마스터에 있으면 템플릿으로, 없으면 보통 주기로 추가
        const exists = get().chores.some((c) => c.name === name);
        if (exists) return;
        const t = CHORE_TEMPLATES.find((x) => x.name === name);
        set((s) => ({
          chores: [
            ...s.chores,
            t
              ? {
                  id: uid(),
                  name: t.name,
                  category: t.category,
                  cycle: t.defaultCycle,
                  lastDone: null,
                  durationMin: t.durationMin,
                  effort: t.effort,
                  weatherTag: t.weatherTag ?? null,
                  seasonMonths: t.seasonMonths,
                  tip: t.tip,
                  howtoId: t.howtoId,
                }
              : {
                  id: uid(),
                  name,
                  category: "기타",
                  cycle: "weekly",
                  lastDone: null,
                  durationMin: 10,
                  effort: "normal",
                  custom: true,
                },
          ],
        }));
      },

      addCustomChore: (input) =>
        set((s) => ({
          chores: [...s.chores, { ...input, id: uid(), lastDone: null, custom: true }],
        })),

      completeChore: (id) => {
        const chore = get().chores.find((c) => c.id === id);
        if (!chore) return;
        // 같은 날 이미 완료한 일은 무시 (일지·주간 카운트 중복 방지)
        if (chore.lastDone === todayStr()) return;
        set((s) => ({
          chores: s.chores.map((c) =>
            c.id === id ? { ...c, lastDone: todayStr() } : c,
          ),
        }));
        get().addLog("chore", `${chore.name} 완료`, { choreId: id });
      },

      updateChore: (id, patch) =>
        set((s) => ({
          chores: s.chores.map((c) => (c.id === id ? { ...c, ...patch } : c)),
        })),

      deleteChore: (id) =>
        set((s) => ({ chores: s.chores.filter((c) => c.id !== id) })),

      addStash: (name, location) =>
        set((s) => ({
          stash: [
            ...s.stash,
            { id: uid(), name, location, lastTouched: todayStr() },
          ],
        })),

      touchStash: (id) =>
        set((s) => ({
          stash: s.stash.map((it) =>
            it.id === id ? { ...it, lastTouched: todayStr() } : it,
          ),
        })),

      deleteStash: (id) =>
        set((s) => ({ stash: s.stash.filter((it) => it.id !== id) })),

      declutterStash: (id) => {
        const item = get().stash.find((it) => it.id === id);
        set((s) => ({ stash: s.stash.filter((it) => it.id !== id) }));
        if (item) get().addLog("declutter", `${item.name} 비움`, { name: item.name });
      },

      addInventory: (name, qty, threshold) =>
        set((s) => ({
          inventory: [
            ...s.inventory,
            { id: uid(), name, qty, threshold, purchaseDates: [] },
          ],
        })),

      adjustQty: (id, delta) =>
        set((s) => ({
          inventory: s.inventory.map((it) =>
            it.id === id ? { ...it, qty: Math.max(0, it.qty + delta) } : it,
          ),
        })),

      setThreshold: (id, threshold) =>
        set((s) => ({
          inventory: s.inventory.map((it) =>
            it.id === id ? { ...it, threshold: Math.max(0, threshold) } : it,
          ),
        })),

      deleteInventory: (id) =>
        set((s) => ({ inventory: s.inventory.filter((it) => it.id !== id) })),

      addShopping: (name, fromInventoryId) =>
        set((s) => {
          if (
            fromInventoryId &&
            s.shopping.some((x) => x.fromInventoryId === fromInventoryId)
          ) {
            return s;
          }
          return {
            shopping: [
              ...s.shopping,
              { id: uid(), name, checked: false, fromInventoryId },
            ],
          };
        }),

      toggleShopping: (id) =>
        set((s) => ({
          shopping: s.shopping.map((x) =>
            x.id === id ? { ...x, checked: !x.checked } : x,
          ),
        })),

      setShoppingPrice: (id, price) =>
        set((s) => ({
          shopping: s.shopping.map((x) =>
            x.id === id ? { ...x, price: Math.max(0, price) } : x,
          ),
        })),

      deleteShopping: (id) =>
        set((s) => ({ shopping: s.shopping.filter((x) => x.id !== id) })),

      purchaseChecked: () => {
        const { shopping } = get();
        const checked = shopping.filter((x) => x.checked);
        if (checked.length === 0) return;
        const today = todayStr();

        set((s) => {
          const inventory = s.inventory.map((it) => {
            const match = checked.find((x) => x.fromInventoryId === it.id);
            if (!match) return it;
            const updated: InventoryItem = {
              ...it,
              qty: it.qty + 1, // 재고 복구 (+1, 상세 수량 조정은 재고 탭에서)
              purchaseDates: [...it.purchaseDates, today],
            };
            return { ...updated, predictedEmptyDate: predictEmptyDate(updated) };
          });
          return {
            inventory,
            shopping: s.shopping.filter((x) => !x.checked),
          };
        });

        for (const item of checked) {
          get().addLog("purchase", `${item.name} 구매`, { name: item.name });
          if (item.fromInventoryId) {
            get().addLog("restock", `${item.name} 재고 보충`, {
              inventoryId: item.fromInventoryId,
            });
          }
        }

        // 5-3: 가격이 입력된 항목 합계를 가계부에 '장보기' 지출로 자동 연동
        const total = checked.reduce((sum, x) => sum + (x.price ?? 0), 0);
        if (total > 0) {
          get().addExpense({
            date: today,
            amount: total,
            category: "장보기",
            memo: checked.map((x) => x.name).join(", "),
          });
        }
      },

      addExpense: (input) => {
        set((s) => ({ expenses: [{ ...input, id: uid() }, ...s.expenses] }));
        get().addLog("expense", `${input.category} ${input.amount.toLocaleString()}원 지출`);
      },

      deleteExpense: (id) =>
        set((s) => ({ expenses: s.expenses.filter((e) => e.id !== id) })),
    }),
    {
      name: STORAGE_KEY,
      storage: createJSONStorage(() => appStorage),
      // 데이터 모델이 바뀌어도 기존 폰의 저장 데이터가 깨지지 않도록 버전 관리.
      // 향후 구조 변경 시 version을 올리고 migrate에서 옛 상태를 변환한다.
      version: 1,
      migrate: (persisted) => persisted as AppState,
      // 액션(함수)은 저장 대상에서 제외 — 데이터 필드만 영구 저장.
      partialize: (s) => ({
        chores: s.chores,
        inventory: s.inventory,
        shopping: s.shopping,
        expenses: s.expenses,
        stash: s.stash,
        logs: s.logs,
        settings: s.settings,
      }),
    },
  ),
);
