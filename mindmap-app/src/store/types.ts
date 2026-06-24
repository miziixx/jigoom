export interface MindNode {
  id: string;
  text: string;
  parentId: string | null;
  position: { x: number; y: number };
  collapsed: boolean;
  refs: string[];
  order: number;
  date?: string; // "YYYY-MM-DD"
}

export type ViewMode = 'outline' | 'mindmap' | 'calendar';

export interface ThemeSettings {
  bgHue: number;    // 0-360
  bgSat: number;    // 0-30
  bgLight: number;  // 4-20
  textHue: number;  // 0-360
  textSat: number;  // 0-40
  textLight: number;// 60-100
}

export const DEFAULT_THEME: ThemeSettings = {
  bgHue: 220,
  bgSat: 15,
  bgLight: 7,
  textHue: 230,
  textSat: 20,
  textLight: 89,
};

export interface AppState {
  nodes: Record<string, MindNode>;
  rootIds: string[];
  viewMode: ViewMode;
  selectedId: string | null;
  sidebarOpen: boolean;
  settingsOpen: boolean;
  theme: ThemeSettings;
  calendarMonth: string; // "YYYY-MM"
}
