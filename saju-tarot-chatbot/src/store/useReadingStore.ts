import { create } from "zustand";
import { deleteSession, loadSessions, saveSession, toggleFavorite } from "../lib/storage";
import type { BirthInfo, DrawnTarotCard, ReadingFocus, ReadingSession, ReadingType } from "../types";

interface StartReadingParams {
  type: ReadingType;
  question: string;
  focus?: ReadingFocus;
  birthInfo?: BirthInfo;
  tarotCards?: DrawnTarotCard[];
}

interface ReadingStore {
  currentSession: ReadingSession | null;
  loading: boolean;
  error: string | null;
  savedSessions: ReadingSession[];

  startReading: (params: StartReadingParams) => Promise<void>;
  sendFollowUp: (question: string) => Promise<void>;
  loadSessionById: (id: string) => void;
  clearCurrentSession: () => void;
  refreshHistory: () => void;
  removeFromHistory: (id: string) => void;
  toggleFavoriteById: (id: string) => void;
}

function newId(): string {
  return crypto.randomUUID();
}

export const useReadingStore = create<ReadingStore>((set, get) => ({
  currentSession: null,
  loading: false,
  error: null,
  savedSessions: [],

  startReading: async ({ type, question, focus, birthInfo, tarotCards }) => {
    set({ loading: true, error: null });
    try {
      const res = await fetch("/api/reading", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ type, question, focus, birthInfo, tarotCards }),
      });
      if (!res.ok) {
        const body = await res.json().catch(() => ({}));
        throw new Error(body.error ?? "리딩 생성에 실패했습니다.");
      }
      const data = await res.json();

      const session: ReadingSession = {
        id: newId(),
        type,
        createdAt: new Date().toISOString(),
        question,
        focus,
        birthInfo,
        sajuChart: data.sajuChart,
        luckCycles: data.luckCycles,
        tarotCards,
        messages: [
          { role: "user", content: data.userMessage as string },
          { role: "assistant", content: data.reply as string },
        ],
      };

      saveSession(session);
      set({ currentSession: session, loading: false });
      get().refreshHistory();
    } catch (err) {
      set({ loading: false, error: err instanceof Error ? err.message : "알 수 없는 오류" });
    }
  },

  sendFollowUp: async (question: string) => {
    const session = get().currentSession;
    if (!session) return;

    const historyWithQuestion = [...session.messages, { role: "user" as const, content: question }];
    set({ loading: true, error: null, currentSession: { ...session, messages: historyWithQuestion } });

    try {
      const res = await fetch("/api/reading", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ type: "followup", history: historyWithQuestion }),
      });
      if (!res.ok) {
        const body = await res.json().catch(() => ({}));
        throw new Error(body.error ?? "답변 생성에 실패했습니다.");
      }
      const data = await res.json();

      const updatedSession: ReadingSession = {
        ...session,
        messages: [...historyWithQuestion, { role: "assistant", content: data.reply as string }],
      };
      saveSession(updatedSession);
      set({ currentSession: updatedSession, loading: false });
      get().refreshHistory();
    } catch (err) {
      set({ loading: false, error: err instanceof Error ? err.message : "알 수 없는 오류" });
    }
  },

  loadSessionById: (id: string) => {
    const session = get().savedSessions.find((s) => s.id === id) ?? loadSessions().find((s) => s.id === id);
    if (session) set({ currentSession: session });
  },

  clearCurrentSession: () => set({ currentSession: null, error: null }),

  refreshHistory: () => set({ savedSessions: loadSessions() }),

  removeFromHistory: (id: string) => {
    deleteSession(id);
    get().refreshHistory();
  },

  toggleFavoriteById: (id: string) => {
    const updated = toggleFavorite(id);
    const current = get().currentSession;
    if (updated && current?.id === id) {
      set({ currentSession: { ...current, favorite: updated.favorite } });
    }
    get().refreshHistory();
  },
}));
