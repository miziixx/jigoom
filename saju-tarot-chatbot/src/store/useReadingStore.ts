import { create } from "zustand";
import { saveFeedback } from "../lib/feedback";
import { streamReading } from "../lib/readingApi";
import { getCachedResult, periodBucket, setCachedResult } from "../lib/resultCache";
import { computeLuckCycles, computeSajuChart } from "../lib/saju";
import { deleteAllSessions, deleteSession, isSessionSaved, loadSessions, saveSession, toggleFavorite } from "../lib/storage";
import type {
  BirthInfo,
  DrawnTarotCard,
  FeedbackRating,
  ReadingContext,
  ReadingFocus,
  ReadingSession,
  ReadingType,
} from "../types";

const MAX_FOLLOW_UP_QUESTIONS = 5;

interface StartReadingParams {
  type: ReadingType;
  question: string;
  focus?: ReadingFocus;
  context?: ReadingContext;
  birthInfo?: BirthInfo;
  tarotCards?: DrawnTarotCard[];
  spreadNote?: string;
  saveToHistory?: boolean;
  /** true면 캐시를 무시하고 새로 생성한다 ('다시 생성' 버튼) */
  forceRegenerate?: boolean;
}

interface CachedReading {
  reply: string;
  userMessage: string;
}

interface ReadingStore {
  currentSession: ReadingSession | null;
  loading: boolean;
  error: string | null;
  savedSessions: ReadingSession[];

  startReading: (params: StartReadingParams) => Promise<void>;
  regenerateCurrent: () => Promise<void>;
  sendFollowUp: (question: string) => Promise<void>;
  saveCurrentSession: (session: ReadingSession) => void;
  loadSessionById: (id: string) => void;
  clearCurrentSession: () => void;
  refreshHistory: () => void;
  removeFromHistory: (id: string) => void;
  removeAllHistory: () => void;
  toggleFavoriteById: (id: string) => void;
  submitFeedback: (id: string, rating: FeedbackRating, tags: string[]) => void;
}

function newId(): string {
  return crypto.randomUUID();
}

function followUpModeFor(question: string): "concise" | "deep" {
  return /자세히|깊게|상세|구체적으로|길게/.test(question) ? "deep" : "concise";
}

export const useReadingStore = create<ReadingStore>((set, get) => ({
  currentSession: null,
  loading: false,
  error: null,
  savedSessions: [],

  startReading: async ({ type, question, focus, context, birthInfo, tarotCards, spreadNote, saveToHistory, forceRegenerate }) => {
    set({ loading: true, error: null });
    // 개인정보 보호: 사주 계산을 여기(브라우저)에서 끝내고, 서버로는 생년월일 원본 대신 계산 결과와
    // 성별만 보낸다. 리딩 기록은 사용자가 직접 저장을 선택한 경우에만 브라우저 저장소에 남긴다.
    const includeMonthlyFlow = type === "saju" || type === "combo" || type === "flow";
    const sajuChart = birthInfo ? computeSajuChart(birthInfo) : undefined;
    const luckCycles = birthInfo ? computeLuckCycles(birthInfo, new Date(), { includeMonthlyFlow }) : undefined;

    // 같은 입력이면 저장된 결과를 재사용해 매번 API를 부르지 않는다(일관성 + 비용 절감).
    // 날짜 의존 흐름이 오래 고정되지 않도록 오늘 흐름은 일 단위, 나머지는 월 단위로 신선도를 둔다.
    const cacheKey = {
      type,
      question: question.trim(),
      focus: focus ?? null,
      context: context ?? null,
      gender: birthInfo?.gender ?? null,
      sajuChart: sajuChart ?? null,
      tarotCards: tarotCards ?? null,
      spreadNote: spreadNote ?? null,
      bucket: periodBucket(type === "today" ? "day" : "month"),
    };
    if (!forceRegenerate) {
      const cached = getCachedResult<CachedReading>("reading", cacheKey);
      if (cached) {
        const cachedSession: ReadingSession = {
          id: newId(),
          type,
          createdAt: new Date().toISOString(),
          question,
          focus,
          context,
          birthInfo,
          sajuChart,
          luckCycles,
          tarotCards,
          messages: [
            { role: "user", content: cached.userMessage },
            { role: "assistant", content: cached.reply },
          ],
        };
        if (saveToHistory) {
          saveSession(cachedSession);
          get().refreshHistory();
        }
        set({ currentSession: cachedSession, loading: false });
        return;
      }
    }

    // 스트리밍 도중 계속 갱신되는 세션 (meta 도착 시 생성 → 텍스트가 실시간으로 자란다)
    let session: ReadingSession | null = null;
    let metaUserMessage = "";
    try {
      const result = await streamReading(
        { type, question, focus, context, gender: birthInfo?.gender, sajuChart, luckCycles, tarotCards, spreadNote },
        {
          onMeta: (meta) => {
            metaUserMessage = meta.userMessage;
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
      // 같은 입력 재사용을 위해 결과를 캐시에 저장 (성공 시에만)
      if (result.reply.trim()) {
        setCachedResult<CachedReading>("reading", cacheKey, {
          reply: result.reply,
          userMessage: metaUserMessage || finalSession.messages[0].content,
        });
      }
      if (saveToHistory) {
        saveSession(finalSession);
        get().refreshHistory();
      }
      set({ currentSession: finalSession, loading: false });
    } catch (err) {
      set({ loading: false, error: err instanceof Error ? err.message : "알 수 없는 오류" });
    }
  },

  regenerateCurrent: async () => {
    const s = get().currentSession;
    if (!s) return;
    await get().startReading({
      type: s.type,
      question: s.question,
      focus: s.focus,
      context: s.context,
      birthInfo: s.birthInfo,
      tarotCards: s.tarotCards,
      saveToHistory: false,
      forceRegenerate: true,
    });
  },

  sendFollowUp: async (question: string) => {
    const session = get().currentSession;
    if (!session) return;
    const usedQuestions = session.messages.slice(2).filter((m) => m.role === "user").length;
    if (usedQuestions >= MAX_FOLLOW_UP_QUESTIONS) {
      set({ error: "후속 질문은 최대 5개까지 가능합니다. 새 질문은 새 리딩으로 시작해주세요." });
      return;
    }

    const historyWithQuestion = [...session.messages, { role: "user" as const, content: question }];
    set({ loading: true, error: null, currentSession: { ...session, messages: historyWithQuestion } });

    try {
      const result = await streamReading(
        { type: "followup", history: historyWithQuestion, followUpMode: followUpModeFor(question) },
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
      if (isSessionSaved(session.id)) {
        saveSession(updatedSession);
        get().refreshHistory();
      }
      set({ currentSession: updatedSession, loading: false });
    } catch (err) {
      set({ loading: false, error: err instanceof Error ? err.message : "알 수 없는 오류" });
    }
  },

  saveCurrentSession: (session: ReadingSession) => {
    saveSession(session);
    set({ currentSession: session });
    get().refreshHistory();
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

  removeAllHistory: () => {
    deleteAllSessions();
    const current = get().currentSession;
    set({ savedSessions: [], currentSession: current ? { ...current, favorite: false, feedback: undefined } : null });
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
