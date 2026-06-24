import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import { v4 as uuidv4 } from 'uuid';
import type { MindNode, AppState, ViewMode, ThemeSettings } from './types';
import { DEFAULT_THEME } from './types';

interface Actions {
  addNode: (parentId: string | null, afterId?: string) => string;
  updateText: (id: string, text: string) => void;
  deleteNode: (id: string) => void;
  moveNode: (id: string, newParentId: string | null, afterId?: string) => void;
  indentNode: (id: string) => void;
  unindentNode: (id: string) => void;
  toggleCollapse: (id: string) => void;
  setSelected: (id: string | null) => void;
  setViewMode: (mode: ViewMode) => void;
  updatePosition: (id: string, x: number, y: number) => void;
  addRef: (fromId: string, toId: string) => void;
  removeRef: (fromId: string, toId: string) => void;
  setNodeDate: (id: string, date: string | null) => void;
  setSidebarOpen: (open: boolean) => void;
  setSettingsOpen: (open: boolean) => void;
  setTheme: (patch: Partial<ThemeSettings>) => void;
  resetTheme: () => void;
  setCalendarMonth: (month: string) => void;
}

type Store = AppState & Actions;

function getSiblings(state: AppState, id: string): string[] {
  const node = state.nodes[id];
  if (!node) return [];
  if (node.parentId === null) return state.rootIds;
  const parent = state.nodes[node.parentId];
  return parent ? getChildIds(state, node.parentId) : [];
}

export function getChildIds(state: Pick<AppState, 'nodes'>, parentId: string): string[] {
  return Object.values(state.nodes)
    .filter(n => n.parentId === parentId)
    .sort((a, b) => a.order - b.order)
    .map(n => n.id);
}

function getAllDescendants(state: AppState, id: string): string[] {
  const children = getChildIds(state, id);
  return children.flatMap(c => [c, ...getAllDescendants(state, c)]);
}

function getMaxOrder(state: AppState, parentId: string | null): number {
  const siblings = parentId === null
    ? state.rootIds.map(id => state.nodes[id]).filter(Boolean)
    : Object.values(state.nodes).filter(n => n.parentId === parentId);
  return siblings.length > 0 ? Math.max(...siblings.map(n => n.order)) : -1;
}

const now = new Date();
const thisMonth = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;

const initialNodes: Record<string, MindNode> = {};
const rootId1 = uuidv4();
const rootId2 = uuidv4();
const child1 = uuidv4();
const child2 = uuidv4();

initialNodes[rootId1] = { id: rootId1, text: '아이디어 1', parentId: null, position: { x: 100, y: 100 }, collapsed: false, refs: [], order: 0 };
initialNodes[rootId2] = { id: rootId2, text: '아이디어 2', parentId: null, position: { x: 400, y: 100 }, collapsed: false, refs: [], order: 1 };
initialNodes[child1] = { id: child1, text: '세부 항목', parentId: rootId1, position: { x: 150, y: 200 }, collapsed: false, refs: [], order: 0 };
initialNodes[child2] = { id: child2, text: '또 다른 항목', parentId: rootId1, position: { x: 150, y: 300 }, collapsed: false, refs: [], order: 1 };

export const useStore = create<Store>()(
  persist(
    (set, get) => ({
      nodes: initialNodes,
      rootIds: [rootId1, rootId2],
      viewMode: 'outline',
      selectedId: null,
      sidebarOpen: false,
      settingsOpen: false,
      theme: DEFAULT_THEME,
      calendarMonth: thisMonth,

      addNode: (parentId, afterId) => {
        const id = uuidv4();
        const state = get();
        let order: number;
        if (afterId) {
          const after = state.nodes[afterId];
          order = after ? after.order + 0.5 : getMaxOrder(state, parentId) + 1;
        } else {
          order = getMaxOrder(state, parentId) + 1;
        }
        const parentNode = parentId ? state.nodes[parentId] : null;
        const px = parentNode?.position.x ?? 0;
        const py = parentNode?.position.y ?? 0;
        const newNode: MindNode = {
          id, text: '', parentId,
          position: { x: px + 200, y: py + Math.random() * 100 },
          collapsed: false, refs: [], order,
        };
        set(s => {
          const nodes = { ...s.nodes, [id]: newNode };
          const siblings = Object.values(nodes)
            .filter(n => n.parentId === parentId)
            .sort((a, b) => a.order - b.order);
          siblings.forEach((n, i) => { nodes[n.id] = { ...nodes[n.id], order: i }; });
          const rootIds = parentId === null
            ? Object.values(nodes).filter(n => n.parentId === null).sort((a, b) => a.order - b.order).map(n => n.id)
            : s.rootIds;
          return { nodes, rootIds, selectedId: id };
        });
        return id;
      },

      updateText: (id, text) => set(s => ({
        nodes: { ...s.nodes, [id]: { ...s.nodes[id], text } }
      })),

      deleteNode: (id) => set(s => {
        const node = s.nodes[id];
        if (!node) return {};
        const toDelete = [id, ...getAllDescendants(s, id)];
        const nodes = { ...s.nodes };
        toDelete.forEach(d => delete nodes[d]);
        Object.values(nodes).forEach(n => {
          nodes[n.id] = { ...n, refs: n.refs.filter(r => !toDelete.includes(r)) };
        });
        const rootIds = s.rootIds.filter(r => !toDelete.includes(r));
        const selectedId = toDelete.includes(s.selectedId ?? '') ? null : s.selectedId;
        return { nodes, rootIds, selectedId };
      }),

      moveNode: (id, newParentId, afterId) => set(s => {
        const node = s.nodes[id];
        if (!node) return {};
        const order = afterId ? (s.nodes[afterId]?.order ?? 0) + 0.5 : getMaxOrder(s, newParentId) + 1;
        const nodes = { ...s.nodes, [id]: { ...node, parentId: newParentId, order } };
        const rootIds = newParentId === null
          ? [...new Set([...s.rootIds.filter(r => r !== id), id])]
          : s.rootIds.filter(r => r !== id);
        return { nodes, rootIds };
      }),

      indentNode: (id) => {
        const state = get();
        const node = state.nodes[id];
        if (!node) return;
        const siblings = getSiblings(state, id);
        const idx = siblings.indexOf(id);
        if (idx === 0) return;
        get().moveNode(id, siblings[idx - 1]);
      },

      unindentNode: (id) => {
        const state = get();
        const node = state.nodes[id];
        if (!node || node.parentId === null) return;
        const grandParentId = state.nodes[node.parentId]?.parentId ?? null;
        get().moveNode(id, grandParentId, node.parentId);
      },

      toggleCollapse: (id) => set(s => ({
        nodes: { ...s.nodes, [id]: { ...s.nodes[id], collapsed: !s.nodes[id].collapsed } }
      })),

      setSelected: (id) => set({ selectedId: id }),
      setViewMode: (viewMode) => set({ viewMode }),

      updatePosition: (id, x, y) => set(s => ({
        nodes: { ...s.nodes, [id]: { ...s.nodes[id], position: { x, y } } }
      })),

      addRef: (fromId, toId) => set(s => {
        const node = s.nodes[fromId];
        if (!node || node.refs.includes(toId) || fromId === toId) return {};
        return { nodes: { ...s.nodes, [fromId]: { ...node, refs: [...node.refs, toId] } } };
      }),

      removeRef: (fromId, toId) => set(s => {
        const node = s.nodes[fromId];
        if (!node) return {};
        return { nodes: { ...s.nodes, [fromId]: { ...node, refs: node.refs.filter(r => r !== toId) } } };
      }),

      setNodeDate: (id, date) => set(s => {
        const node = s.nodes[id];
        if (!node) return {};
        const updated = { ...node };
        if (date) updated.date = date;
        else delete updated.date;
        return { nodes: { ...s.nodes, [id]: updated } };
      }),

      setSidebarOpen: (open) => set({ sidebarOpen: open }),
      setSettingsOpen: (open) => set({ settingsOpen: open }),

      setTheme: (patch) => set(s => ({ theme: { ...s.theme, ...patch } })),
      resetTheme: () => set({ theme: DEFAULT_THEME }),

      setCalendarMonth: (calendarMonth) => set({ calendarMonth }),
    }),
    { name: 'mindmap-store' }
  )
);

export { getAllDescendants };
