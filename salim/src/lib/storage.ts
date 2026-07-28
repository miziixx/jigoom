import type { StateStorage } from "zustand/middleware";

// 저장 추상화 레이어.
// 지금은 localStorage. 향후 네이티브(Capacitor) 전환 시 이 파일만
// @capacitor/preferences·SQLite 등으로 교체하면 됨.
export const appStorage: StateStorage = {
  getItem: (name) => {
    try {
      return localStorage.getItem(name);
    } catch {
      return null;
    }
  },
  setItem: (name, value) => {
    try {
      localStorage.setItem(name, value);
    } catch {
      /* 저장 불가 환경은 조용히 무시 */
    }
  },
  removeItem: (name) => {
    try {
      localStorage.removeItem(name);
    } catch {
      /* ignore */
    }
  },
};

export const STORAGE_KEY = "salim-state-v1";
