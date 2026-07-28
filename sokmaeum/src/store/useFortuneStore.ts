import { create } from "zustand";
import { getTodayFortune } from "../lib/fortuneApi";
import { resolveSavedBirth, saveProfile } from "../lib/profile";
import type { BirthInfo, FortuneResult } from "../types";

interface FortuneStore {
  /** 저장된 명식 (없으면 입력 유도) */
  birthInfo: BirthInfo | null;
  result: FortuneResult | null;
  loading: boolean;
  error: string | null;

  /** 앱 시작 시 저장된 명식으로 오늘의 운세를 자동 로드 */
  init: () => Promise<void>;
  /** 명식을 등록(저장)하고 운세를 생성 */
  setBirthAndGenerate: (birthInfo: BirthInfo) => Promise<void>;
  /** 오늘 운세 다시 생성 (캐시 무시) */
  regenerate: () => Promise<void>;
  /** 명식 초기화 (다른 명식으로 보기) */
  resetBirth: () => void;
}

export const useFortuneStore = create<FortuneStore>((set, get) => ({
  birthInfo: null,
  result: null,
  loading: false,
  error: null,

  init: async () => {
    if (get().result || get().loading) return;
    const saved = resolveSavedBirth();
    if (!saved) return;
    set({ birthInfo: saved, loading: true, error: null });
    try {
      const result = await getTodayFortune(saved);
      set({ result, loading: false });
    } catch (err) {
      set({ loading: false, error: err instanceof Error ? err.message : "운세를 불러오지 못했습니다." });
    }
  },

  setBirthAndGenerate: async (birthInfo) => {
    saveProfile(birthInfo);
    set({ birthInfo, loading: true, error: null, result: null });
    try {
      const result = await getTodayFortune(birthInfo);
      set({ result, loading: false });
    } catch (err) {
      set({ loading: false, error: err instanceof Error ? err.message : "운세를 불러오지 못했습니다." });
    }
  },

  regenerate: async () => {
    const birthInfo = get().birthInfo;
    if (!birthInfo) return;
    set({ loading: true, error: null });
    try {
      const result = await getTodayFortune(birthInfo, { force: true });
      set({ result, loading: false });
    } catch (err) {
      set({ loading: false, error: err instanceof Error ? err.message : "운세를 불러오지 못했습니다." });
    }
  },

  resetBirth: () => set({ birthInfo: null, result: null, error: null }),
}));
