import { create } from "zustand";
import { saveFeedback } from "../lib/feedback";
import { streamReading } from "../lib/readingApi";
import { getCachedResult, periodBucket, setCachedResult } from "../lib/resultCache";
import { computeLuckCycles, computePastEventCalibrationInputs, computeSajuChart } from "../lib/saju";
import { buildPastValidationReport } from "../lib/pastValidation";
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

function inferFocusFromQuestion(question: string): ReadingFocus {
  const text = question.replace(/\s/g, "").toLowerCase();
  if (!text) return "general";
  if (/연애|사랑|남친|여친|남자친구|여자친구|썸|재회|이별|결혼|배우자|상대|관계|궁합/.test(text)) return "relationship";
  if (/직장|회사|이직|퇴사|취업|업무|프로젝트|커리어|사업|창업|브랜드|공부|진로|시험|합격/.test(text)) return "career";
  if (/돈|금전|재물|수입|월급|연봉|투자|부업|매출|지출|저축|대출/.test(text)) return "career";
  if (/건강|몸|아프|병원|컨디션|체력|수면|피로|두통|위장|간|눈|피부|허리|목|어깨/.test(text)) return "wellness";
  if (/마음|불안|우울|멘탈|감정|스트레스|외롭|답답|무기력|자존감/.test(text)) return "mental";
  if (/선택|결정|해야할까|해도될까|말까|시기|언제|타이밍|유지|그만|시작|기다/.test(text)) return "decision";
  return "general";
}

function concernAreaForFocus(focus: ReadingFocus): string | undefined {
  switch (focus) {
    case "career":
      return "일·돈·진로";
    case "relationship":
      return "연애·관계";
    case "wellness":
      return "건강·컨디션";
    case "mental":
      return "마음상태";
    case "decision":
      return "선택·시기";
    default:
      return undefined;
  }
}

export const useReadingStore = create<ReadingStore>((set, get) => ({
  currentSession: null,
  loading: false,
  error: null,
  savedSessions: [],

  startReading: async ({ type, question, focus, context, birthInfo, tarotCards, spreadNote, saveToHistory, forceRegenerate }) => {
    set({ loading: true, error: null });
    const cleanQuestion = question.trim();
    const inferredFocus = focus && focus !== "general" ? focus : inferFocusFromQuestion(cleanQuestion);
    const inferredConcernArea = concernAreaForFocus(inferredFocus);
    const effectiveContext: ReadingContext = {
      ...(context ?? {}),
      concernArea: context?.concernArea ?? inferredConcernArea,
    };
    // 개인정보 보호: 사주 계산을 여기(브라우저)에서 끝내고, 서버로는 생년월일 원본 대신 계산 결과와
    // 성별만 보낸다. 리딩 기록은 사용자가 직접 저장을 선택한 경우에만 브라우저 저장소에 남긴다.
    const includeMonthlyFlow = type === "saju" || type === "combo" || type === "flow";
    const sajuChart = birthInfo ? computeSajuChart(birthInfo) : undefined;
    const luckCycles = birthInfo ? computeLuckCycles(birthInfo, new Date(), { includeMonthlyFlow }) : undefined;
    // 과거 검증: 사용자가 실제 과거 사건을 입력했으면 그 시기 흐름 부합도를 계산한다(무 API·결정론).
    const pastValidation =
      birthInfo && sajuChart && effectiveContext.pastEvents && effectiveContext.pastEvents.length > 0
        ? buildPastValidationReport(
            sajuChart.dayMasterGan,
            computePastEventCalibrationInputs(birthInfo, effectiveContext.pastEvents),
          ) ?? undefined
        : undefined;
    const provisionalSession: ReadingSession | null =
      sajuChart || tarotCards?.length
        ? {
            id: newId(),
            type,
            createdAt: new Date().toISOString(),
            question,
            focus: inferredFocus,
            context: effectiveContext,
            birthInfo,
            sajuChart,
            luckCycles,
            tarotCards,
            messages: [
              { role: "user", content: question.trim() || "리딩 요청" },
              { role: "assistant", content: "" },
            ],
          }
        : null;

    // 같은 입력이면 저장된 결과를 재사용해 매번 API를 부르지 않는다(일관성 + 비용 절감).
    // 날짜 의존 흐름이 오래 고정되지 않도록 오늘 흐름은 일 단위, 나머지는 월 단위로 신선도를 둔다.
    const cacheKey = {
      type,
      question: cleanQuestion,
      focus: inferredFocus,
      context: effectiveContext,
      gender: birthInfo?.gender ?? null,
      sajuChart: sajuChart ?? null,
      tarotCards: tarotCards ?? null,
      spreadNote: spreadNote ?? null,
      pastEvents: effectiveContext.pastEvents ?? null,
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
          focus: inferredFocus,
          context: effectiveContext,
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

    if (provisionalSession) set({ currentSession: provisionalSession });

    // 스트리밍 도중 계속 갱신되는 세션 (계산 결과는 즉시 세션으로 먼저 보여주고, AI 텍스트가 실시간으로 자란다)
    let session: ReadingSession | null = provisionalSession;
    let metaUserMessage = "";
    try {
      const result = await streamReading(
        { type, question, focus: inferredFocus, context: effectiveContext, gender: birthInfo?.gender, sajuChart, luckCycles, tarotCards, spreadNote, pastValidation },
        {
          onMeta: (meta) => {
            metaUserMessage = meta.userMessage;
            session = {
              id: session?.id ?? newId(),
              type,
              createdAt: session?.createdAt ?? new Date().toISOString(),
              question,
              focus: inferredFocus,
              context: effectiveContext,
              birthInfo,
              sajuChart: meta.sajuChart ?? sajuChart,
              luckCycles: meta.luckCycles ?? luckCycles,
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
