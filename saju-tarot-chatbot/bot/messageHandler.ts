// 사주 선생님 봇 메시지 처리 로직 — 롱폴링(bot/index.ts)과 웹훅(api/telegram-webhook.ts)이 공유한다.
// 저장소(Store)만 주입받아 동작하므로, 어떤 방식으로 실행되는지는 이 파일이 몰라도 된다.
import { sendMessage, sendTyping, type TgMessage } from "./telegram.js";
import { parseBirthInput, describeBirthInfo, looksLikeBirthInput, parseRelationType, looksLikeTwoBirths, parseTwoBirthsInput, parseBareGender } from "./parseBirth.js";
import { looksLikeFourPillars, looksLikePartialPillars, parseFourPillars, describePillars } from "./parseFourPillars.js";
import { formatChartSummary, buildCompatibilityEvidence, buildNatalEvidence, chartSourceOf, computePack, pillarsSource, birthSource, type ChartSource } from "./evidence.js";
import { inferBirthFromPillars, type InferBirthResult } from "./inferBirth.js";
import { askTeacher, askCompatibility, askTarot, askStudyExplain, askStudyLesson, pickTeacherModel } from "./teacher.js";
import { extractVerbosityHint } from "./extractVerbosityHint.js";
import { carriesRealQuestion } from "./questionHeuristics.js";
import { logError } from "./logSafe.js";
import { detectIntent, isSecretaryIntent } from "./intentDetector.js";
import { routeMessage } from "./smartRouter.js";
import { drawForQuestion, buildTarotEvidenceText, describeDrawnCardsShort } from "./tarotReading.js";
import { buildAssistantContext } from "./assistantContext.js";
import { buildAstrologyEvidenceText } from "./astrologyEvidence.js";
import { askSecretary, type SecretaryIntent } from "./secretary.js";
import { summarizeForMemory, detectMemoryDeleteScope } from "./memoryOps.js";
import {
  startStudy,
  answerStudy,
  formatProgress,
  isStudyExit,
  isDeepExplainRequest,
  deepExplainContext,
  setStudyTone,
  formatToneStatus,
  TEXTBOOK_PILLARS,
  STUDY_PRACTICE_BIRTHS,
  type StudyState,
} from "./studyMode.js";
import type { StoredPillars } from "./parseFourPillars.js";
import type { Store, UserRecord } from "./storeTypes.js";
import type { SpreadId } from "../src/lib/tarot.js";
import type { BirthInfo, DrawnTarotCard } from "../src/types/index.js";

/**
 * 학습 딥다이브·톤 강의가 근거로 쓸 사주 근거 텍스트.
 * 1~21장은 교재 사주(팔자 입력)만, 22장 이상(대운·세운·실전)은 대운이 계산되는
 * 연습 사주(생년월일시)까지 합쳐 넘긴다 — LLM이 연습 사주 간지를 인용해도 근거 점검에서
 * 오탐(없는 값 주장)으로 잡히지 않게 한다.
 */
function buildStudyEvidence(chapter: number): string {
  const parts = [buildNatalEvidence(pillarsSource({ ...TEXTBOOK_PILLARS }))];
  if (chapter >= 22) {
    for (const birth of STUDY_PRACTICE_BIRTHS) parts.push(buildNatalEvidence(birthSource(birth)));
  }
  return parts.join("\n\n");
}

/**
 * 새로 파싱된 생년월일시가 이미 등록된 사주와 사실상 같은 사람인지 판단한다.
 * 대화 도중 "이거 내 사주야"처럼 자기 사주를 다시 붙여넣었을 때, 이게 "새 사람 등록"이
 * 아니라 "같은 사람 재확인"임을 알아채 대화 맥락(history)을 날리지 않기 위함이다.
 */
function isSameBirthInfo(a: BirthInfo, b: BirthInfo | null | undefined): boolean {
  if (!b) return false;
  return (
    a.calendarType === b.calendarType &&
    a.year === b.year &&
    a.month === b.month &&
    a.day === b.day &&
    (a.hour ?? null) === (b.hour ?? null) &&
    (a.minute ?? 0) === (b.minute ?? 0) &&
    Boolean(a.isLeapMonth) === Boolean(b.isLeapMonth) &&
    a.gender === b.gender &&
    (a.birthPlace ?? "none") === (b.birthPlace ?? "none")
  );
}

/** 새로 붙여넣은 만세력 팔자가 이미 등록된 원국과 같은 사람의 것인지 (계산된 간지로 비교). */
function pillarsMatchSource(pillars: StoredPillars, source: ChartSource | null): boolean {
  if (!source) return false;
  const { chart } = computePack(source);
  if (chart.year.ganZhi !== pillars.year) return false;
  if (chart.month.ganZhi !== pillars.month) return false;
  if (chart.day.ganZhi !== pillars.day) return false;
  if (pillars.hour && chart.hour?.ganZhi && pillars.hour !== chart.hour.ganZhi) return false;
  return true;
}

// 개인 봇 보호: 지정하면 이 텔레그램 사용자 ID만 사용 가능 (쉼표 구분)
// TELEGRAM_ALLOWED_USER_IDS(기존)와 ALLOWED_TELEGRAM_USER_IDS(신규 별칭) 둘 다 인식한다.
const ALLOWED_IDS = new Set(
  [process.env.TELEGRAM_ALLOWED_USER_IDS ?? "", process.env.ALLOWED_TELEGRAM_USER_IDS ?? ""]
    .join(",")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean),
);

const BIRTH_GUIDE = [
  "생년월일시를 한 줄로 보내주세요. 형식은 자유롭게:",
  "",
  "• `1993-03-15 14:30 여 서울`",
  "• `음력 1990년 5월 2일 07시 20분 남 부산`",
  "• `1988.7.15 시간모름 남` (시간을 모르면)",
  "",
  "포함할 것: 날짜 + 시각(또는 '시간모름') + 성별(남/여)",
  "선택: 음력/윤달, 출생 지역(진태양시 보정)",
  "",
  "이미 만세력에서 사주팔자(여덟 글자)를 알고 있으면, 그걸 그대로 붙여넣어도 돼요:",
  "• `경오 무자 임술 갑진`",
  "• `연주 경오 월주 무자 일주 임술 시주 갑진`",
  "(팔자만 넣으면 대운(10년 흐름)은 빠지고 나머지는 그대로 계산돼요. 대운까지 보려면 생년월일시로 넣어주세요.)",
].join("\n");

const START_GUIDE = [
  "🔮 *나의 사주 선생님*",
  "",
  "만세력으로 정확히 계산한 사주 데이터를 근거로, 궁금한 걸 뭐든 설명해주는 개인 사주 선생님이에요.",
  "",
  "사주 등록 없이 바로 이런 것도 물어볼 수 있어요:",
  "• 지장간이 뭐야? 왜 그렇게 배당돼?",
  "• 신강신약이 뭔지 원리부터 설명해줘",
  "• 타로로 이번 달 연애 흐름 봐줘 (사주 등록 없이 바로 가능)",
  "",
  "명령어 몰라도 돼요 — 사주·타로·점성술 뭐든 그냥 말로 물어보면 알아서 골라 답해요.",
  "",
  "*내 사주 기반*으로 답을 받고 싶으면 먼저 등록해주세요 (한 줄, 형식 자유):",
  "",
  BIRTH_GUIDE,
  "",
  "등록하면 이런 질문도 가능해져요:",
  "• 나 왜 신약사주야?",
  "• 오늘 일진이 왜 이렇게 흘러가?",
  "• 내 격국이 뭔지, 왜 그렇게 잡히는지 알려줘",
  "",
  "명령어: /saju 원국 요약 · /today 오늘 일진 풀이 · /타로 타로 리딩 · /궁합 상대와 궁합 보기 · /학습 사주 이론 학습모드(21장) · /진도 학습 진도 · /톤 학습 말투·난이도 설정 · /퀴즈 배운 개념 복습 · /birth 사주 등록/재등록 · /reset 대화 초기화 · /delete 데이터 삭제",
].join("\n");

const PRIVACY_TEXT = [
  "🔒 *보안/개인정보 정책*",
  "",
  "• 이 봇은 개인 전용이에요. 등록된 텔레그램 사용자 ID만 사용할 수 있고, 그 외 사용자의 메시지는 Claude API로 전달되지 않아요.",
  "• 서버 로그에는 대화 원문·질문 원문·Claude 응답 원문을 남기지 않아요. 로그엔 요청 ID·처리 시간·토큰 수 정도만 남아요.",
  "• Claude는 사주·점성술을 직접 계산하지 않아요. 계산은 항상 프로그램(만세력/좌표 엔진)이 하고, Claude는 그 계산 결과만 해석·정리해요.",
  "• 최근 대화 맥락(히스토리)은 마지막 메시지로부터 일정 시간(기본 45분) 지나면 자동으로 사라져요.",
  "• '기억'은 명시적으로 '기억해줘'라고 요청한 내용만, 원문이 아니라 짧은 요약으로 저장돼요. '저장하지 마'/'잊어줘'라고 하면 바로 지워져요.",
  "",
  "/reset 대화 맥락 초기화 · /delete 내 사주·기억 전체 삭제",
].join("\n");

const HELP_TEXT = [
  "이 봇은 명령어 없이 그냥 말로 걸어도 알아들어요. 사주·타로·점성술 다 자연어로:",
  "• \"타로로 이번 연애 어떻게 될지 봐줘\" → 타로 (질문에 맞는 스프레드 자동 선택)",
  "• \"한 장 더 뽑아줘\" / \"그 카드 무슨 뜻이야?\" → 방금 뽑은 타로 이어서",
  "• \"나 오늘 왜 이렇게 의욕이 없지?\" → 오늘 흐름/자기분석",
  "• \"이거 기획 좀 정리해줘\" → 기획 정리",
  "• \"이 글 좀 자연스럽게 고쳐줘\" → 글쓰기 도움",
  "• \"이거 먼저 할까 저거 먼저 할까?\" → 판단/결정",
  "• \"1993-03-15 14:30 여 서울, 1995-06-20 09:30 남 부산 연인\" → 두 사람 궁합 (명령어 없이 한 줄에 둘 다 넣으면 자동)",
  "• \"방금 얘기한 거 기억해둬\" / \"이건 저장하지 마\" → 기억 저장/삭제",
  "• \"보안 상태 알려줘\" → /privacy",
  "",
  "사주 이론을 직접 공부하고 싶으면 */학습* — 21장 커리큘럼(음양오행부터 신살까지)을 고정 교재 사주로 빡세게 배우는 학습모드예요. 진도·오답노트는 계속 기억돼요. (/진도 로 확인) 강의가 어렵게 느껴지면 */톤 초등학생도 알게 쉽게* 처럼 원하는 말투를 저장하면 강의도 그 톤으로 나가요.",
  "",
  "명령어(선택): /start · /birth · /saju · /today · /타로 · /궁합 · /학습 · /진도 · /reset · /delete · /privacy · /help",
].join("\n");

const COMPAT_GUIDE = [
  "*궁합*을 볼게요. 상대방 생년월일시를 한 줄로 보내주세요 (내 사주 등록과 같은 형식).",
  "",
  "관계도 같이 적어주면 그 관계에 맞게 풀어드려요:",
  "• `1995-06-20 09:30 남 서울 연인`",
  "• `음력 1992년 3월 5일 시간모름 여 부산 동료`",
  "",
  "관계 키워드: 연인 · 부모/자식 · 형제 · 가족 · 직장상사 · 동료 · 친구 (안 적으면 연인으로 봐요)",
  "",
  "명령어 없이도 돼요 — 두 사람 사주를 한 줄에 같이 넣으면 바로 궁합을 봐드려요:",
  "• `1993-03-15 14:30 여 서울, 1995-06-20 09:30 남 부산 연인`",
  "그만두려면 /reset",
].join("\n");

const TAROT_GUIDE = [
  "🃏 *타로*를 봐드릴게요. 그냥 뭐가 궁금한지 편하게 말해주세요 — 스프레드는 질문에 맞게 알아서 골라 뽑아요.",
  "",
  "• \"타로로 이번 연애 어떻게 흘러갈지 봐줘\" → 관계 스프레드",
  "• \"이직할까 말까 타로로 봐줘\" → 두 선택지 비교",
  "• \"이번 달 흐름 타로로 봐줘\" → 한 달 흐름",
  "• \"고민 있는데 카드 한 장만 뽑아줘\" → 핵심 1장",
  "• \"제대로 깊게 봐줘\" → 켈틱크로스 10장",
  "",
  "뽑은 뒤엔 \"그 카드 무슨 뜻이야?\", \"한 장 더 뽑아줘\"처럼 이어서 물어도 돼요.",
].join("\n");

/** 팔자 → 실제 생일 되짚기 성공 시 등록 안내 문구를 만든다. */
function buildInferHeader(wasRegistered: boolean, inferred: InferBirthResult): string {
  const b = inferred.birthInfo!;
  const lines: string[] = [];
  lines.push(wasRegistered ? "사주를 새로 등록했어요 ✅ (이전 대화 맥락은 초기화)" : "팔자로 등록했어요 ✅");
  lines.push(`이 팔자는 실제로 *${b.year}년 ${b.month}월 ${b.day}일${inferred.weekday ? `(${inferred.weekday})` : ""}*로 보여요. 그 날짜로 대운까지 계산했어요.`);
  if (inferred.otherYears && inferred.otherYears.length > 0) {
    lines.push(`(같은 팔자가 ${inferred.otherYears.join("·")}년에도 있지만, 가장 최근인 ${b.year}년으로 봤어요. 다른 연도면 생년월일시로 알려주세요.)`);
  }
  if (inferred.genderAssumed) {
    lines.push("성별을 안 주셔서 대운은 *남성 기준*으로 잡았어요. 여성이면 팔자 뒤에 '여'를 붙여 다시 보내주세요(대운 방향이 반대예요).");
  }
  if (inferred.hourDropped) {
    lines.push("적어주신 시주가 계산과 안 맞아, 시주는 빼고 등록했어요.");
  }
  return lines.join("\n");
}

/** 생일 입력에서 걷어내고 남은 텍스트가 실제 질문인지 판단한다. 아니면 null. */
function extractQuestion(remainder?: string): string | null {
  if (!remainder) return null;
  const q = remainder.trim();
  // 한글이 하나도 없거나(장소/숫자 찌꺼기) 너무 짧으면 질문이 아니다.
  if (!/[가-힣]/.test(q)) return null;
  if (q.replace(/\s/g, "").length < 2) return null;
  return q;
}

/**
 * 타로 리딩 처리. 새로 뽑기(newDraw)면 질문 결에 맞는 스프레드를 골라 카드를 뽑아 보여주고,
 * 후속 질문이면 방금 뽑은 카드(user.lastTarot)를 그대로 근거로 이어서 답한다.
 * 사주 등록과 무관하게 동작한다(타로는 생일이 필요 없음).
 */
async function handleTarotIntent(
  chatId: number,
  text: string,
  user: UserRecord,
  store: Store,
  opts: { newDraw: boolean },
): Promise<void> {
  const { cleanQuestion, override } = extractVerbosityHint(text);
  const isFreshDraw = opts.newDraw || !user.lastTarot;

  let spreadId: SpreadId;
  let cards: DrawnTarotCard[];
  let evidenceQuestion: string;

  if (isFreshDraw) {
    const drawn = drawForQuestion(cleanQuestion);
    spreadId = drawn.spreadId;
    cards = drawn.cards;
    evidenceQuestion = cleanQuestion;
    // 어떤 카드가 나왔는지 먼저 보여준 뒤, 해석을 스트리밍한다.
    await sendMessage(chatId, describeDrawnCardsShort(spreadId, cards));
    await store.setLastTarot(chatId, { spreadId, question: cleanQuestion, cards, drawnAt: new Date().toISOString() });
  } else {
    spreadId = user.lastTarot!.spreadId;
    cards = user.lastTarot!.cards;
    evidenceQuestion = user.lastTarot!.question; // 이 스프레드를 뽑았던 원래 질문(자리 맥락)
  }

  const tarotEvidence = buildTarotEvidenceText(spreadId, cards, evidenceQuestion);
  const typing = setInterval(() => void sendTyping(chatId), 5000);
  void sendTyping(chatId);
  try {
    const answer = await askTarot({
      tarotEvidence,
      question: cleanQuestion,
      history: user.history,
      chatId,
      verbosityOverride: override,
      isFollowUp: !isFreshDraw,
    });
    await store.appendHistory(chatId, { role: "user", content: cleanQuestion }, { role: "assistant", content: answer });
  } finally {
    clearInterval(typing);
  }
}

// 팔자 등록 시 성별을 안 줬을 때 되묻는 문구. 조용히 남성으로 가정하지 않기 위함.
const GENDER_ASK = [
  "이 사주, *남자예요 여자예요?* 🙏",
  "성별에 따라 *대운(10년 흐름)의 방향이 반대*라, 이것만 알면 흐름까지 정확히 잡아드려요.",
  "",
  "`남` 또는 `여` 라고만 보내주세요.",
].join("\n");

/**
 * 파싱된 팔자(성별 포함)로 등록을 마무리한다. 되짚기 성공하면 대운까지, 실패하면 팔자 그대로.
 * 함께 온 질문(followUp)이 있으면 등록 후 바로 답한다. 새 등록 전용이라 맥락은 새로 시작한다.
 * 팔자 직접입력 경로와 "성별 되묻기" 완료 경로가 공유한다.
 */
async function completePillarsRegistration(
  chatId: number,
  store: Store,
  pillars: StoredPillars,
  opts: { wasRegistered: boolean; followUp: string | null },
): Promise<void> {
  const inferred = inferBirthFromPillars(pillars);
  let newSource: ChartSource;
  let header: string;
  if (inferred.ok) {
    await store.setBirthInfo(chatId, inferred.birthInfo!);
    newSource = birthSource(inferred.birthInfo!);
    header = buildInferHeader(opts.wasRegistered, inferred);
  } else {
    await store.setPillars(chatId, pillars);
    newSource = pillarsSource(pillars);
    header =
      (opts.wasRegistered ? "사주를 새로 등록했어요 ✅ (이전 대화 맥락은 초기화)" : "팔자로 등록했어요 ✅") +
      `\n${describePillars(pillars)}` +
      "\n(이 팔자에 딱 맞는 실제 날짜를 못 찾아서, 팔자 그대로 해석해요 — 대운은 빠져요.)";
  }

  const followUp = opts.followUp;
  if (followUp) {
    await sendMessage(chatId, header);
    const typing = setInterval(() => void sendTyping(chatId), 5000);
    void sendTyping(chatId);
    try {
      const { cleanQuestion, override } = extractVerbosityHint(followUp);
      const answer = await askTeacher({ source: newSource, history: [], question: cleanQuestion, chatId, verbosityOverride: override });
      await store.appendHistory(chatId, { role: "user", content: cleanQuestion }, { role: "assistant", content: answer });
    } finally {
      clearInterval(typing);
    }
    return;
  }
  await sendMessage(chatId, `${header}\n\n${formatChartSummary(newSource)}`);
}

export async function handleMessage(msg: TgMessage, store: Store): Promise<void> {
  const chatId = msg.chat.id;
  const text = (msg.text ?? "").trim();
  if (!text) return;

  try {
    if (ALLOWED_IDS.size > 0 && !ALLOWED_IDS.has(String(msg.from?.id ?? ""))) {
      await sendMessage(chatId, "이 봇은 개인용이라 등록된 사용자만 쓸 수 있어요.");
      return;
    }

    const user = await store.getUser(chatId);
    // 원국 출처: 생년월일시(birth) 또는 만세력 팔자 직접입력(pillars). 등록 전이면 null.
    const source = chartSourceOf(user);

    // ── 명령어 ──
    if (text === "/start") {
      await sendMessage(chatId, START_GUIDE);
      return;
    }
    if (text === "/birth") {
      await sendMessage(chatId, BIRTH_GUIDE);
      return;
    }
    if (text === "/reset") {
      await store.clearHistory(chatId);
      await sendMessage(chatId, "대화 기록을 초기화했어요. 사주 등록은 유지됩니다.");
      return;
    }
    if (text === "/delete") {
      await store.deleteUser(chatId);
      await sendMessage(chatId, "사주 정보와 대화 기록을 모두 삭제했어요. /start 로 다시 시작할 수 있어요.");
      return;
    }
    if (text === "/privacy") {
      await sendMessage(chatId, PRIVACY_TEXT);
      return;
    }
    if (text === "/help") {
      await sendMessage(chatId, HELP_TEXT);
      return;
    }
    if (text === "/saju") {
      if (!source) {
        await sendMessage(chatId, "이건 내 사주 원국이 있어야 보여줄 수 있어요. 먼저 등록해주세요.\n\n" + BIRTH_GUIDE);
        return;
      }
      await sendMessage(chatId, formatChartSummary(source));
      return;
    }
    if (text === "/today" && !source) {
      await sendMessage(chatId, "오늘 일진은 내 사주와 오늘 간지를 대조해야 해서, 먼저 등록이 필요해요.\n\n" + BIRTH_GUIDE);
      return;
    }
    // ── 학습모드: 시작/진도/종료 ──
    // 완전 규칙 기반(LLM 호출 없음) — 강의·출제·채점·오답노트 전부 studyMode.ts가 코드로 처리한다.
    // 진도(user.study)는 history TTL·/reset과 무관하게 유지된다. /delete 때만 삭제.
    if (text === "/학습" || text === "/study" || /^\/(학습|study)\s+\d+$/.test(text)) {
      const jumpMatch = text.match(/\s+(\d+)$/);
      const jumpTo = jumpMatch ? Number(jumpMatch[1]) : undefined;
      const prevState: StudyState | null = user.study ? (user.study as StudyState) : null;
      const reply = startStudy(prevState, jumpTo);
      await store.setStudy(chatId, { ...reply.state, active: true });
      // 톤이 설정돼 있고 새 장 강의가 나왔으면, 기본 강의를 그 톤으로 다시 써서 보낸다(LLM 1회).
      // 실패하면 하드코딩 기본 강의로 폴백(토큰 0). 강의 뒤 안내·첫 문제(tail)는 그대로 붙인다.
      if (reply.state.tone && reply.lesson) {
        const typing = setInterval(() => void sendTyping(chatId), 5000);
        void sendTyping(chatId);
        try {
          const textbookEvidence = buildStudyEvidence(reply.state.chapter);
          const retoned = await askStudyLesson({
            lesson: reply.lesson,
            tone: reply.state.tone,
            textbookEvidence,
          });
          await sendMessage(chatId, `${retoned}\n\n${reply.tail ?? ""}`.trim());
        } catch (err) {
          logError("study.retoneLesson", err);
          await sendMessage(chatId, reply.message);
        } finally {
          clearInterval(typing);
        }
      } else {
        await sendMessage(chatId, reply.message);
      }
      return;
    }
    if (text === "/진도" || text === "/progress") {
      await sendMessage(chatId, formatProgress(user.study ? (user.study as StudyState) : null));
      return;
    }
    // ── 학습 톤 설정: 기본 강의도 원하는 톤·난이도로 (영구 저장) ──
    if (text === "/톤" || text === "/tone") {
      await sendMessage(chatId, formatToneStatus(user.study ? (user.study as StudyState) : null));
      return;
    }
    if (text === "/톤끄기" || text === "/기본톤" || text === "/tone off") {
      const { state, message } = setStudyTone(user.study ? (user.study as StudyState) : null, "");
      await store.setStudy(chatId, { ...state, active: user.study?.active ?? false });
      await sendMessage(chatId, message);
      return;
    }
    if (text.startsWith("/톤 ") || text.startsWith("/tone ")) {
      const tone = text.replace(/^\/(톤|tone)\s+/, "");
      const { state, message } = setStudyTone(user.study ? (user.study as StudyState) : null, tone);
      await store.setStudy(chatId, { ...state, active: user.study?.active ?? false });
      await sendMessage(chatId, message);
      return;
    }
    if (user.study?.active && isStudyExit(text)) {
      await store.setStudy(chatId, { ...user.study, active: false });
      await sendMessage(chatId, "학습모드를 잠깐 접을게요. 진도는 그대로 저장돼 있으니 /학습 으로 언제든 이어서! 📚");
      return;
    }
    // ── 학습모드 진행 중: "더 설명해줘"는 딥다이브 LLM 호출 1회(퀴즈 답 처리보다 먼저 검사) ──
    // 압축 강의·문제 해설은 하드코딩(토큰 0)이지만, 이 트리거만 표·비유·사례분기까지 담은
    // 긴 해설을 만들려고 askStudyExplain을 부른다. 교재 사주(TEXTBOOK_PILLARS)를 근거로 고정.
    if (user.study?.active && !text.startsWith("/") && isDeepExplainRequest(text)) {
      const ctx = deepExplainContext(user.study as StudyState);
      if (!ctx) {
        await sendMessage(chatId, "아직 설명해줄 개념이 없어요. /학습 으로 먼저 시작해주세요!");
        return;
      }
      const typing = setInterval(() => void sendTyping(chatId), 5000);
      void sendTyping(chatId);
      try {
        const textbookEvidence = buildStudyEvidence(ctx.chapter);
        // 답은 askStudyExplain이 스트리밍으로 화면에 직접 표시한다(여기서 재전송하지 않음).
        await askStudyExplain({
          chapterTitle: ctx.chapterTitle,
          concept: ctx.concept,
          baseExplain: ctx.baseExplain,
          textbookEvidence,
          question: text,
          chatId,
        });
      } finally {
        clearInterval(typing);
      }
      return;
    }
    // ── 학습모드 진행 중: 일반 텍스트는 퀴즈 답으로 처리 (슬래시 명령은 통과) ──
    if (user.study?.active && !text.startsWith("/")) {
      const { state, message } = answerStudy(user.study as StudyState, text);
      // 퀴즈 한 세트가 끝나면(quiz=null) 학습모드를 자동으로 접어, 이후 일반 대화가 오답 처리되지 않게 한다.
      const stillActive = state.quiz !== null;
      await store.setStudy(chatId, { ...state, active: stillActive });
      await sendMessage(chatId, stillActive ? message : `${message}\n\n(학습모드를 접었어요 — 이제 일반 질문도 자유롭게. 이어서 하려면 /학습)`);
      return;
    }

    if (text === "/타로" || text === "/tarot") {
      await sendMessage(chatId, TAROT_GUIDE);
      return;
    }
    if (text.startsWith("/타로 ") || text.startsWith("/tarot ")) {
      const q = text.replace(/^\/(타로|tarot)\s+/, "").trim();
      await handleTarotIntent(chatId, q, user, store, { newDraw: true });
      return;
    }
    if (text === "/궁합" || text === "/compat" || text === "/궁합보기") {
      if (!user.birthInfo) {
        const msg = user.pillars
          ? "궁합은 두 사람의 생년월일시로 시기·흐름까지 맞대봐야 해서, 팔자만으로는 볼 수 없어요. 내 사주를 생년월일시로 다시 등록해주세요.\n\n"
          : "궁합은 내 사주와 상대 사주를 맞대봐야 해서, 먼저 내 사주부터 등록해주세요.\n\n";
        await sendMessage(chatId, msg + BIRTH_GUIDE);
        return;
      }
      await store.setPending(chatId, { type: "compat" });
      await sendMessage(chatId, COMPAT_GUIDE);
      return;
    }

    // ── 궁합 대기 중: 이 입력을 상대방 사주로 해석 ──
    if (user.pending?.type === "compat") {
      if (!user.birthInfo) {
        // 대기 중 내 사주가 지워진 비정상 상태 — 안전하게 해제
        await store.setPending(chatId, null);
        await sendMessage(chatId, "내 사주 정보가 없어 궁합을 못 봐요. /birth 로 먼저 등록해주세요.");
        return;
      }
      const parsed = parseBirthInput(text);
      if (!parsed.ok) {
        await sendMessage(chatId, `상대방 정보를 못 읽었어요. ${parsed.error}\n\n${COMPAT_GUIDE}`);
        return;
      }
      const relationType = user.pending.relationType ?? parseRelationType(text) ?? "romantic";
      await store.setPending(chatId, null); // 한 번 처리하면 대기 해제

      const typing = setInterval(() => void sendTyping(chatId), 5000);
      void sendTyping(chatId);
      try {
        const compatEvidence = buildCompatibilityEvidence(user.birthInfo, parsed.birthInfo!, relationType);
        // chatId를 넘기면 답이 스트리밍으로 화면에 직접 표시된다(여기서 재전송하지 않음).
        await askCompatibility({ compatEvidence, chatId });
      } finally {
        clearInterval(typing);
      }
      return;
    }

    // ── 팔자 등록 성별 대기 중: 이 입력에서 성별을 읽어 등록을 마무리한다 ──
    if (user.pending?.type === "pillarsGender") {
      const g = parseBareGender(text);
      if (!g) {
        await sendMessage(chatId, `${GENDER_ASK}\n\n(그만두려면 /reset)`);
        return;
      }
      const pillarsWithGender = { ...user.pending.pillars, gender: g };
      const followUp = user.pending.question ?? null;
      await store.setPending(chatId, null);
      await completePillarsRegistration(chatId, store, pillarsWithGender, {
        wasRegistered: Boolean(user.birthInfo || user.pillars),
        followUp,
      });
      return;
    }

    // ── 뒤늦은 성별 정정("여자야", "나 남성이야") → 등록된 사주 성별만 갱신, 대운 재계산 ──
    // 팔자만 붙여넣으면 성별을 몰라 대운을 남성 기준으로 가정한다. 나중에 "여자야"라고 하면
    // 그걸 새 질문으로 흘려 라우터가 헤매게 두지 말고, 같은 사람의 성별 정정으로 보고 다시 잡아준다.
    // 대화 맥락(history)은 유지해, 정정 직후 원래 궁금하던 걸 이어 물을 수 있게 한다.
    {
      const correctedGender = parseBareGender(text);
      if (correctedGender) {
        const label = correctedGender === "female" ? "여성" : "남성";
        if (user.birthInfo) {
          if (user.birthInfo.gender === correctedGender) {
            await sendMessage(chatId, `네, 이미 ${label} 기준으로 보고 있어요 👍 대운·흐름 다 그 기준이에요. 궁금한 거 이어서 물어보세요.`);
            return;
          }
          await store.updateGender(chatId, correctedGender);
          const updated = { ...user.birthInfo, gender: correctedGender };
          await sendMessage(
            chatId,
            `네, ${label} 기준으로 다시 잡았어요 ✅ 성별이 바뀌면 *대운 방향*이 반대라 인생 흐름이 달라져요.\n\n` +
              `${formatChartSummary(birthSource(updated))}\n\n` +
              "아까 궁금했던 거 그대로 이어서 물어보시면 이 기준으로 답할게요.",
          );
          return;
        }
        if (user.pillars) {
          // 팔자만 등록(생일 못 되짚음)이라 성별로 방향이 갈리는 대운 자체가 없다 — 솔직히 안내.
          await sendMessage(
            chatId,
            `${label}이시군요. 다만 지금은 팔자만 등록돼 있어 성별로 방향이 갈리는 *대운*은 계산에서 빠져 있어요. ` +
              "생년월일시(예: `1993-03-15 14:30 여 서울`)로 등록하면 그 기준 대운까지 잡아드려요.",
          );
          return;
        }
        // 등록 전이면 성별만 받아둘 데가 없다 → 등록 안내로 이어지게 통과시킨다.
      }
    }

    // ── 한 메시지에 두 사람 생년월일시 → 명령어 없이 바로 궁합 (완전 자연어) ──
    // "/궁합"을 누르지 않아도, 두 사람 사주를 한 박스에 넣으면 궁합으로 알아듣는다.
    // 단일 사주 등록(looksLikeBirthInput)보다 먼저 검사해야, 첫 사람만 본인으로 등록되는 걸 막는다.
    if (looksLikeTwoBirths(text)) {
      const two = parseTwoBirthsInput(text);
      if (two.ok) {
        const relationType = two.relationType ?? "romantic";
        const typing = setInterval(() => void sendTyping(chatId), 5000);
        void sendTyping(chatId);
        try {
          const compatEvidence = buildCompatibilityEvidence(two.first!, two.second!, relationType);
          // chatId를 넘기면 답이 스트리밍으로 화면에 직접 표시된다(여기서 재전송하지 않음).
          await askCompatibility({ compatEvidence, chatId });
        } finally {
          clearInterval(typing);
        }
        return;
      }
      // 두 사람처럼 보였는데 못 읽음 → 안내 (각 사람에 성별이 빠졌을 때가 잦다)
      await sendMessage(chatId, `두 분 궁합으로 보려 했는데 못 읽었어요. ${two.error}\n\n두 사람 다 날짜+성별을 넣어주세요. 예:\n\`1993-03-15 14:30 여 서울, 1995-06-20 09:30 남 부산 연인\``);
      return;
    }

    // ── 생년월일시 형태 입력 → 등록/재등록 (등록 여부와 무관하게 처리) ──
    if (looksLikeBirthInput(text)) {
      const parsed = parseBirthInput(text);
      if (parsed.ok) {
        // 이미 등록된 것과 같은 사람이면 "새 등록"이 아니라 "재확인" — 맥락(history)을 지우지 않는다.
        const isSame = isSameBirthInfo(parsed.birthInfo!, user.birthInfo);
        const wasRegistered = Boolean(user.birthInfo);
        if (!isSame) {
          await store.setBirthInfo(chatId, parsed.birthInfo!);
        }

        // 생일과 함께 질문까지 한 번에 보냈으면(예: "95년 8월 23일남자 성격 봐줘")
        // 등록 사실만 한 줄로 알리고 곧바로 그 질문에 답한다.
        const followUp = extractQuestion(parsed.remainder);
        if (followUp) {
          if (!isSame) {
            await sendMessage(chatId, `${describeBirthInfo(parsed.birthInfo!)}로 보고 답할게요.`);
          }
          const typing = setInterval(() => void sendTyping(chatId), 5000);
          void sendTyping(chatId);
          try {
            const { cleanQuestion, override } = extractVerbosityHint(followUp);
            // 답은 askTeacher가 스트리밍으로 화면에 직접 표시한다(여기서 재전송하지 않음).
            const answer = await askTeacher({
              source: birthSource(parsed.birthInfo!),
              history: isSame ? user.history : [],
              question: cleanQuestion,
              chatId,
              verbosityOverride: override,
            });
            await store.appendHistory(chatId, { role: "user", content: cleanQuestion }, { role: "assistant", content: answer });
          } finally {
            clearInterval(typing);
          }
          return;
        }

        if (isSame) {
          await sendMessage(chatId, `네, 등록된 사주 맞아요 ✅\n${describeBirthInfo(parsed.birthInfo!)}`);
          return;
        }

        const prefix = wasRegistered ? "사주를 새로 등록했어요 ✅ (이전 대화 맥락은 초기화)" : "등록했어요 ✅";
        await sendMessage(chatId, `${prefix}\n${describeBirthInfo(parsed.birthInfo!)}\n\n${formatChartSummary(birthSource(parsed.birthInfo!))}`);
        return;
      }
      // 등록 시도로 보이는데 형식이 안 맞으면 안내. 등록 전 사용자에게만 보여준다 —
      // 이미 등록된 사용자가 그냥 연도/성별이 우연히 섞인 질문을 했을 수도 있어서다.
      if (!user.birthInfo) {
        await sendMessage(chatId, `${parsed.error}\n\n${BIRTH_GUIDE}`);
        return;
      }
    }

    // ── 만세력 사주팔자(여덟 글자) 직접 입력 → 등록/재등록 ──
    if (looksLikeFourPillars(text)) {
      const parsed = parseFourPillars(text);
      if (parsed.ok) {
        // 이미 등록된 원국과 같은 사람의 팔자면 "재등록"이 아니라 "재확인" — 맥락을 지우지 않는다.
        const isSame = pillarsMatchSource(parsed.pillars!, source);
        const wasRegistered = Boolean(user.birthInfo || user.pillars);
        const followUp = extractQuestion(parsed.remainder);

        // 재확인: 맥락(history)을 유지한 채 그대로 답하거나 확인만 한다.
        if (isSame && source) {
          if (followUp) {
            await sendMessage(chatId, "네, 등록된 사주 맞아요 ✅");
            const typing = setInterval(() => void sendTyping(chatId), 5000);
            void sendTyping(chatId);
            try {
              const { cleanQuestion, override } = extractVerbosityHint(followUp);
              const answer = await askTeacher({ source, history: user.history, question: cleanQuestion, chatId, verbosityOverride: override });
              await store.appendHistory(chatId, { role: "user", content: cleanQuestion }, { role: "assistant", content: answer });
            } finally {
              clearInterval(typing);
            }
          } else {
            await sendMessage(chatId, "네, 등록된 사주 맞아요 ✅");
          }
          return;
        }

        // 새 등록인데 성별이 없으면: 조용히 남성으로 가정하지 말고 먼저 물어본다.
        // (성별로 대운 방향이 갈려, 여기서 잘못 잡으면 뒤늦게 "여자야" 정정이 필요해진다.)
        if (!parsed.pillars!.gender) {
          await store.setPending(chatId, { type: "pillarsGender", pillars: parsed.pillars!, question: followUp ?? undefined });
          await sendMessage(chatId, GENDER_ASK);
          return;
        }

        await completePillarsRegistration(chatId, store, parsed.pillars!, { wasRegistered, followUp });
        return;
      }
      // 팔자 형태로 보였지만 못 읽은 경우 — 등록 전 사용자에게만 안내한다.
      if (!source) {
        await sendMessage(chatId, `${parsed.error}\n\n${BIRTH_GUIDE}`);
        return;
      }
    }

    // ── 간지를 쓰려다 연·월주까지만 준 경우(예: "갑자년 정축월") → 최소 일주 안내 ──
    // 단, 이론 질문("정축일주가 을미일에 편재/상관 성격을 띠나?")은 가로채지 말고 선생님이 답한다.
    // (이 안내로 return하면 그 메시지가 히스토리에 안 남아 이후 맥락도 끊긴다.)
    if (looksLikePartialPillars(text) && !carriesRealQuestion(text)) {
      await sendMessage(
        chatId,
        [
          "간지로 사주를 보려면 *최소 연·월·일주*가 필요해요.",
          "연·월주만으론 대략 몇 년 몇 월인지까지만 좁혀지고, 정작 '나'를 뜻하는 *일주(日柱)*가 없어 사주가 세워지지 않아요.",
          "",
          "일주(예: `병인일`)까지 넣어주세요. 시주(예: `정묘시`)까지 있으면 실제 생년월일을 되짚어 *대운*까지 계산해드려요.",
          "• `갑자년 정축월 병인일 정묘시`",
          "• `갑자 정축 병인` (시주 모르면 생략)",
        ].join("\n"),
      );
      return;
    }

    // ── 질문 → 사주 선생님(Claude). 사주 등록 여부와 무관하게 답한다 ──
    let question = text;
    let verbosityOverride: "brief" | "normal" | "detailed" | undefined;
    let astrologyEvidence: string | undefined;
    // 잡담(generalChat)만 값싼 모델로. 슬래시 명령·사주 질문은 기본 모델 유지.
    let teacherModel: string | undefined;

    if (text === "/today") {
      // 오늘 일진만 짧게. "오늘/일진"이 들어 있어 teacher가 오늘 데이터를 자동 첨부한다.
      question = "오늘 일진 어때? 핵심만 짧게 알려줘.";
    } else if (text === "/퀴즈") {
      question =
        "지금까지 나눈 대화나 내 사주 계산 데이터 중에서 개념 하나를 골라 복습 문제를 내주세요. " +
        "정답을 바로 알려주지 말고, 문제만 먼저 주고 제가 답해볼 수 있게 기다려주세요. " +
        "제가 다음 메시지로 답하면 그때 채점하고, 틀렸거나 애매하면 원리를 다시 짚어 설명해주세요.";
    } else {
      // ── 자연어 의도 분류. 슬래시 명령이 아닌 자유 텍스트는 전부 여기를 거친다 ──
      // 1단계: *파괴적* 동작(기억 삭제·대화 초기화)만 명시적 키워드로 먼저 확정한다.
      //   되돌릴 수 없는 데이터 삭제는 LLM 오판에 맡기지 않는다. 저장(추가)·조회·보안확인은
      //   되돌릴 수 있거나 읽기 전용이라, 질문/명령 구분이 중요한 만큼 2단계 라우터가 맥락으로 판단한다.
      const keywordIntent = detectIntent(text);

      if (keywordIntent === "resetContext") {
        await store.clearHistory(chatId);
        await sendMessage(chatId, "대화 기록을 초기화했어요. 사주 등록은 유지됩니다.");
        return;
      }
      if (keywordIntent === "memoryDelete") {
        const scope = detectMemoryDeleteScope(text);
        const removed = await store.deleteMemory(chatId, scope);
        await sendMessage(chatId, removed > 0 ? `기억 ${removed}건 지웠어요 ✅` : "지울 만한 저장된 기억이 없었어요.");
        return;
      }

      // 2단계: 나머지는 맥락 인지 라우터로 의도를 확정한다. 최근 대화 + 등록 상태를 함께 보고
      // "그럼 연애는?", "한 장 더", "아까 그 카드", "기억해?(질문)" vs "기억해둬(명령)"까지 자연어로 이해한다.
      const route = await routeMessage({
        text,
        history: user.history,
        keywordHint: keywordIntent,
        hasSaju: Boolean(source),
        hasBirth: Boolean(user.birthInfo),
        hasTarot: Boolean(user.lastTarot),
      });
      const intent = route.intent;

      // ── 보안 정책 확인 ──
      if (intent === "privacyCheck") {
        await sendMessage(chatId, PRIVACY_TEXT);
        return;
      }
      // ── 기억 조회(무엇을 기억하고 있는지 묻는 질문) ──
      if (intent === "memoryLookup") {
        const memories = user.memories ?? [];
        if (memories.length === 0) {
          await sendMessage(chatId, "아직 따로 기억해둔 메모는 없어요. \"이거 기억해둬\"라고 말하면 그때부터 요약해서 기억할게요.");
          return;
        }
        const lines = memories.slice(-10).map((m) => `• ${m.summary}`);
        await sendMessage(chatId, `지금 기억하고 있는 건 이런 거예요 👇\n${lines.join("\n")}`);
        return;
      }
      // ── 기억 저장(저장해달라는 명령일 때만) ──
      if (intent === "memorySave") {
        const typing = setInterval(() => void sendTyping(chatId), 5000);
        void sendTyping(chatId);
        try {
          const { category, summary, sensitive } = await summarizeForMemory(user.history, text);
          await store.addMemory(chatId, { category, summary, sensitive });
          await sendMessage(chatId, `ㅇㅋ 기억해뒀어요 👌\n${summary}`);
        } finally {
          clearInterval(typing);
        }
        return;
      }

      // ── 타로 리딩 (사주 등록과 무관) ──
      if (intent === "tarotReading") {
        await handleTarotIntent(chatId, text, user, store, { newDraw: route.newDraw });
        return;
      }

      if (isSecretaryIntent(intent)) {
        const typing = setInterval(() => void sendTyping(chatId), 5000);
        void sendTyping(chatId);
        try {
          const { cleanQuestion, override } = extractVerbosityHint(text);
          const assistantContext = buildAssistantContext({
            chartSource: source,
            birthInfo: user.birthInfo ?? null,
            detectedIntent: intent,
            memories: user.memories ?? [],
            currentQuestion: cleanQuestion,
          });
          // 답은 askSecretary가 스트리밍으로 화면에 직접 표시한다(여기서 재전송하지 않음).
          const answer = await askSecretary({
            intent: intent as SecretaryIntent,
            question: cleanQuestion,
            assistantContext,
            history: user.history,
            chatId,
            verbosityOverride: override,
          });
          await store.appendHistory(chatId, { role: "user", content: cleanQuestion }, { role: "assistant", content: answer });
        } finally {
          clearInterval(typing);
        }
        return;
      }

      // 나머지(sajuReading/astrologyReading/combinedReading/todayFlow/generalChat) → 기존 askTeacher 경로
      const { cleanQuestion, override } = extractVerbosityHint(text);
      question = cleanQuestion;
      verbosityOverride = override;
      // astrology/combined 의도면 점성술 근거를 추가로 첨부(첫 줄 의도 고지는 secretary 모드 전용,
      // teacher 경로는 기존 대화 톤을 유지한다).
      if ((intent === "astrologyReading" || intent === "combinedReading") && user.birthInfo) {
        astrologyEvidence = buildAstrologyEvidenceText(user.birthInfo);
      }
      // 순수 잡담이면 값싼 모델로 태운다(사주 용어 섞이면 pickTeacherModel이 기본 모델 유지).
      teacherModel = pickTeacherModel(intent, cleanQuestion);
    }

    const typing = setInterval(() => void sendTyping(chatId), 5000);
    void sendTyping(chatId);
    try {
      // 답은 askTeacher가 스트리밍으로 화면에 직접 표시한다(여기서 재전송하지 않음).
      const answer = await askTeacher({
        source,
        history: user.history,
        question,
        chatId,
        verbosityOverride,
        astrologyEvidence,
        modelOverride: teacherModel,
      });
      await store.appendHistory(chatId, { role: "user", content: question }, { role: "assistant", content: answer });
    } finally {
      clearInterval(typing);
    }
  } catch (err) {
    logError("messageHandler", err);
    await sendMessage(chatId, "문제가 생겼어요. 잠시 후 다시 시도해주세요.").catch(() => {});
  }
}
