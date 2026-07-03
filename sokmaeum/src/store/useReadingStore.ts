import { create } from "zustand";
import { saveFeedback } from "../lib/feedback";
import { streamReading } from "../lib/readingApi";
import { deleteSession, loadSessions, saveSession, toggleFavorite } from "../lib/storage";
import type {
  BirthInfo,
  DrawnTarotCard,
  FeedbackRating,
  ReadingContext,
  ReadingFocus,
  ReadingSession,
  ReadingType,
} from "../types";

interface StartReadingParams {
  type: ReadingType;
  question: string;
  focus?: ReadingFocus;
  context?: ReadingContext;
  birthInfo?: BirthInfo;
  tarotCards?: DrawnTarotCard[];
  spreadNote?: string;
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
  submitFeedback: (id: string, rating: FeedbackRating, tags: string[]) => void;
}

function newId(): string {
  return crypto.randomUUID();
}

export const useReadingStore = create<ReadingStore>((set, get) => ({
  currentSession: null,
  loading: false,
  error: null,
  savedSessions: [],

  startReading: async ({ type, question, focus, context, birthInfo, tarotCards, spreadNote }) => {
    set({ loading: true, error: null });
    // 스트리밍 도중 계속 갱신되는 세션 (meta 도착 시 생성 → 텍스트가 실시간으로 자란다)
    let session: ReadingSession | null = null;
    let textUpdates = 0;
    try {
      const result = await streamReading(
        { type, question, focus, context, birthInfo, tarotCards, spreadNote },
        {
          onMeta: (meta) => {
            session = {
              id: newId(),
              type,
              createdAt: new Date().toISOString(),
              question,
              focus,
              context,
              birthInfo,
              sajuChart: meta.sajuChart,
              luckCycles: meta.luckCycles,
              tarotCards,
              messages: [
                { role: "user", content: meta.userMessage },
                { role: "assistant", content: "" },
              ],
            };
            set({ currentSession: session });
          },
          onText: (accumulated) => {
            if (!session) return;
            session = {
              ...session,
              messages: [session.messages[0], { role: "assistant", content: accumulated }],
            };
            set({ currentSession: session });
            // 연결이 끊겨도 부분 결과가 남도록 주기적으로 저장
            textUpdates += 1;
            if (textUpdates % 20 === 0) saveSession(session);
          },
        },
      );

      // TS는 콜백 안의 할당을 추적하지 못하므로 여기서 타입을 되살린다
      const built = session as ReadingSession | null;
      if (!built) throw new Error("서버가 계산 결과를 보내지 않았습니다. 다시 시도해보세요.");
      const finalSession: ReadingSession = {
        ...built,
        messages: [built.messages[0], { role: "assistant", content: result.reply }],
      };
      saveSession(finalSession);
      set({ currentSession: finalSession, loading: false });
      get().refreshHistory();
    } catch (err) {
      // 부분 결과가 있으면 저장해서 살린다
      const partial = session as ReadingSession | null;
      if (partial && partial.messages[1]?.content) saveSession(partial);
      set({ loading: false, error: err instanceof Error ? err.message : "알 수 없는 오류" });
      get().refreshHistory();
    }
  },

  sendFollowUp: async (question: string) => {
    const session = get().currentSession;
    if (!session) return;

    const historyWithQuestion = [...session.messages, { role: "user" as const, content: question }];
    set({ loading: true, error: null, currentSession: { ...session, messages: historyWithQuestion } });

    try {
      const result = await streamReading(
        { type: "followup", history: historyWithQuestion },
        {
          onText: (accumulated) => {
            set({
              currentSession: {
                ...session,
                messages: [...historyWithQuestion, { role: "assistant", content: accumulated }],
              },
            });
          },
        },
      );

      const updatedSession: ReadingSession = {
        ...session,
        messages: [...historyWithQuestion, { role: "assistant", content: result.reply }],
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

  submitFeedback: (id: string, rating: FeedbackRating, tags: string[]) => {
    const updated = saveFeedback(id, rating, tags);
    const current = get().currentSession;
    if (updated && current?.id === id) {
      set({ currentSession: { ...current, feedback: updated.feedback } });
    }
    get().refreshHistory();
  },
}));
