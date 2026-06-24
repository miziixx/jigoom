export interface MindNode {
  id: string;
  text: string;
  parentId: string | null;
  position: { x: number; y: number };
  collapsed: boolean;
  refs: string[];
  order: number;
}

export type ViewMode = 'outline' | 'mindmap';

export interface AppState {
  nodes: Record<string, MindNode>;
  rootIds: string[];
  viewMode: ViewMode;
  selectedId: string | null;
}
