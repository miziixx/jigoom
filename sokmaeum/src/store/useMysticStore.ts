import { create } from "zustand";
import { getMysticReading } from "../features/mystic-reading/readingApi";
import { INTEREST_LABEL } from "../features/mystic-reading/evidenceMapper";
import { buildMysticStyleHint } from "../features/mystic-reading/sectionFeedback";
import { mysticResultToText } from "../features/mystic-reading/resultToText";
import { computeAstrologyProfile } from "../lib/astrology";
import { computeSajuChart } from "../lib/saju";
import { streamReading } from "../lib/readingApi";
import { loadSessions, saveSession } from "../lib/storage";
import { resolveSavedBirth, saveProfile } from "../lib/profile";
import type { BirthInfo, ReadingInterest, ReadingSession } from "../types";

const MAX_FOLLOW_UP_QUESTIONS = 5;

interface MysticStore {
  birthInfo: BirthInfo | null;
  interest: ReadingInterest;
  partner: BirthInfo | null;
  session: ReadingSession | null;
  loading: boolean;
  error: string | null;

  init: () => void;
  setInterest: (interest: ReadingInterest) => void;
  generate: (birthInfo: BirthInfo, interest: ReadingInterest, partner?: BirthInfo | null) => Promise<void>;
  regenerate: () => Promise<void>;
  sendFollowUp: (question: string) => Promise<void>;
  loadSessionById: (id: string) => void;
  reset: () => void;
}

function newId(): string {
  return crypto.randomUUID();
}

function followUpModeFor(question: string): "concise" | "deep" {
  return /자세히|깊게|상세|구체적으로|길게/.test(question) ? "deep" : "concise";
}

export const useMysticStore = create<MysticStore>((set, get) => ({
  birthInfo: null,
  interest: "all",
  partner: null,
  session: null,
  loading: false,
  error: null,

  init: () => {
    if (get().birthInfo) return;
    const saved = resolveSavedBirth();
    if (saved) set({ birthInfo: saved });
  },

  setInterest: (interest) => set({ interest }),

  generate: async (birthInfo, interest, partner) => {
    saveProfile(birthInfo);
    const partnerBirth = partner ?? null;
    set({ birthInfo, interest, partner: partnerBirth, loading: true, error: null, session: null });
    try {
      const styleHint = buildMysticStyleHint() ?? undefined;
      const result = await getMysticReading(birthInfo, interest, {
        partner: partnerBirth ?? undefined,
        styleHint,
      });
      const sajuChart = computeSajuChart(birthInfo);
      const astrologyProfile = computeAstrologyProfile(birthInfo);
      const readingText = mysticResultToText(result);
      const session: ReadingSession = {
        id: newId(),
        type: "mystic",
        createdAt: new Date().toISOString(),
        question: `속마음 리딩 · 관심사: ${INTEREST_LABEL[interest]}`,
        focus: "general",
        birthInfo,
        sajuChart,
        astrologyProfile,
        mysticResult: result,
        messages: [
          {
            role: "user",
            content: `내 사주 근거로 뽑은 속마음 리딩이야. 아래 리딩 내용을 바탕으로 이어지는 질문에 같은 톤(단정 없이, 상담하듯)으로 답해줘.\n\n${readingText}`,
          },
          {
            role: "assistant",
            content: `${result.openingOracle.sentence}\n\n리딩을 함께 봤어요. 더 깊이 들여다보고 싶은 부분이 있으면 편하게 물어보세요.`,
          },
        ],
      };
      saveSession(session);
      set({ session, loading: false });
    } catch (err) {
      set({ loading: false, error: err instanceof Error ? err.message : "리딩을 생성하지 못했습니다." });
    }
  },

  regenerate: async () => {
    const { birthInfo, interest, partner } = get();
    if (!birthInfo) return;
    set({ loading: true, error: null });
    try {
      const styleHint = buildMysticStyleHint() ?? undefined;
      const result = await getMysticReading(birthInfo, interest, {
        force: true,
        partner: partner ?? undefined,
        styleHint,
      });
      const current = get().session;
      const sajuChart = computeSajuChart(birthInfo);
      const astrologyProfile = computeAstrologyProfile(birthInfo);
      const readingText = mysticResultToText(result);
      const contextMsg = {
        role: "user" as const,
        content: `내 사주 근거로 뽑은 속마음 리딩이야. 아래 리딩 내용을 바탕으로 이어지는 질문에 같은 톤(단정 없이, 상담하듯)으로 답해줘.\n\n${readingText}`,
      };
      const session: ReadingSession = current
        ? {
            ...current,
            sajuChart,
            astrologyProfile,
            mysticResult: result,
            messages: [contextMsg, current.messages[1] ?? { role: "assistant", content: result.openingOracle.sentence }],
          }
        : {
            id: newId(),
            type: "mystic",
            createdAt: new Date().toISOString(),
            question: "속마음 리딩",
            birthInfo,
            sajuChart,
            astrologyProfile,
            mysticResult: result,
            messages: [contextMsg, { role: "assistant", content: result.openingOracle.sentence }],
          };
      saveSession(session);
      set({ session, loading: false });
    } catch (err) {
      set({ loading: false, error: err instanceof Error ? err.message : "리딩을 생성하지 못했습니다." });
    }
  },

  // 리딩에 대한 이어묻기 챗봇 (기존 /api/reading followup 경로 재사용)
  sendFollowUp: async (question) => {
    const session = get().session;
    if (!session) return;
    const usedQuestions = session.messages.slice(2).filter((m) => m.role === "user").length;
    if (usedQuestions >= MAX_FOLLOW_UP_QUESTIONS) {
      set({ error: "후속 질문은 최대 5개까지 가능합니다. 새 질문은 새 리딩으로 시작해주세요." });
      return;
    }
    const historyWithQuestion = [...session.messages, { role: "user" as const, content: question }];
    set({ loading: true, error: null, session: { ...session, messages: historyWithQuestion } });
    try {
      const result = await streamReading(
        { type: "followup", history: historyWithQuestion, followUpMode: followUpModeFor(question) },
        {
          onText: (accumulated) => {
            set({
              session: { ...session, messages: [...historyWithQuestion, { role: "assistant", content: accumulated }] },
            });
          },
        },
      );
      const updated: ReadingSession = {
        ...session,
        messages: [...historyWithQuestion, { role: "assistant", content: result.reply }],
      };
      saveSession(updated);
      set({ session: updated, loading: false });
    } catch (err) {
      set({ loading: false, error: err instanceof Error ? err.message : "알 수 없는 오류" });
    }
  },

  loadSessionById: (id) => {
    const session = loadSessions().find((s) => s.id === id);
    if (session && session.type === "mystic") {
      set({ session, birthInfo: session.birthInfo ?? get().birthInfo });
    }
  },

  reset: () => set({ session: null, error: null }),
}));
