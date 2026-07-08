// 사주 선생님 봇 메시지 처리 로직 — 롱폴링(bot/index.ts)과 웹훅(api/telegram-webhook.ts)이 공유한다.
// 저장소(Store)만 주입받아 동작하므로, 어떤 방식으로 실행되는지는 이 파일이 몰라도 된다.
import { sendMessage, sendTyping, type TgMessage } from "./telegram.js";
import { parseBirthInput, describeBirthInfo, looksLikeBirthInput, parseRelationType, looksLikeTwoBirths, parseTwoBirthsInput } from "./parseBirth.js";
import { looksLikeFourPillars, looksLikePartialPillars, parseFourPillars, describePillars } from "./parseFourPillars.js";
import { formatChartSummary, buildCompatibilityEvidence, chartSourceOf, computePack, pillarsSource, birthSource, type ChartSource } from "./evidence.js";
import { inferBirthFromPillars, type InferBirthResult } from "./inferBirth.js";
import { askTeacher, askCompatibility } from "./teacher.js";
import { extractVerbosityHint } from "./extractVerbosityHint.js";
import { logError } from "./logSafe.js";
import { detectIntent, isSecretaryIntent } from "./intentDetector.js";
import { buildAssistantContext } from "./assistantContext.js";
import { buildAstrologyEvidenceText } from "./astrologyEvidence.js";
import { askSecretary, type SecretaryIntent } from "./secretary.js";
import { summarizeForMemory, detectMemoryDeleteScope } from "./memoryOps.js";
import type { StoredPillars } from "./parseFourPillars.js";
import type { Store } from "./storeTypes.js";
import type { BirthInfo } from "../src/types/index.js";

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
  "명령어: /saju 원국 요약 · /today 오늘 일진 풀이 · /궁합 상대와 궁합 보기 · /퀴즈 배운 개념 복습 · /birth 사주 등록/재등록 · /reset 대화 초기화 · /delete 데이터 삭제",
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
  "이 봇은 명령어 없이 그냥 말로 걸어도 알아들어요. 예:",
  "• \"나 오늘 왜 이렇게 의욕이 없지?\" → 오늘 흐름/자기분석",
  "• \"이거 기획 좀 정리해줘\" → 기획 정리",
  "• \"이 글 좀 자연스럽게 고쳐줘\" → 글쓰기 도움",
  "• \"이거 먼저 할까 저거 먼저 할까?\" → 판단/결정",
  "• \"1993-03-15 14:30 여 서울, 1995-06-20 09:30 남 부산 연인\" → 두 사람 궁합 (명령어 없이 한 줄에 둘 다 넣으면 자동)",
  "• \"방금 얘기한 거 기억해둬\" / \"이건 저장하지 마\" → 기억 저장/삭제",
  "• \"보안 상태 알려줘\" → /privacy",
  "",
  "명령어(선택): /start · /birth · /saju · /today · /궁합 · /reset · /delete · /privacy · /help",
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

        let newSource: typeof source;
        let header: string;
        if (isSame && source) {
          newSource = source;
          header = "네, 등록된 사주 맞아요 ✅";
        } else {
          // 1순위: 팔자로 실제 생일을 되짚어본다. 되짚으면 대운·사령까지 되살아난다.
          const inferred = inferBirthFromPillars(parsed.pillars!);
          if (inferred.ok) {
            await store.setBirthInfo(chatId, inferred.birthInfo!);
            newSource = birthSource(inferred.birthInfo!);
            header = buildInferHeader(wasRegistered, inferred);
          } else {
            // 되짚기 실패 → 팔자 그대로 해석(대운 제외)
            await store.setPillars(chatId, parsed.pillars!);
            newSource = pillarsSource(parsed.pillars!);
            header =
              (wasRegistered ? "사주를 새로 등록했어요 ✅ (이전 대화 맥락은 초기화)" : "팔자로 등록했어요 ✅") +
              `\n${describePillars(parsed.pillars!)}` +
              "\n(이 팔자에 딱 맞는 실제 날짜를 못 찾아서, 팔자 그대로 해석해요 — 대운은 빠져요.)";
          }
        }

        // 팔자와 함께 질문까지 한 줄로 보냈으면 등록만 알리고 바로 답한다.
        const followUp = extractQuestion(parsed.remainder);
        if (followUp) {
          await sendMessage(chatId, header);
          const typing = setInterval(() => void sendTyping(chatId), 5000);
          void sendTyping(chatId);
          try {
            const { cleanQuestion, override } = extractVerbosityHint(followUp);
            // 답은 askTeacher가 스트리밍으로 화면에 직접 표시한다(여기서 재전송하지 않음).
            const answer = await askTeacher({
              source: newSource,
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
          await sendMessage(chatId, header);
          return;
        }

        await sendMessage(chatId, `${header}\n\n${formatChartSummary(newSource!)}`);
        return;
      }
      // 팔자 형태로 보였지만 못 읽은 경우 — 등록 전 사용자에게만 안내한다.
      if (!source) {
        await sendMessage(chatId, `${parsed.error}\n\n${BIRTH_GUIDE}`);
        return;
      }
    }

    // ── 간지를 쓰려다 연·월주까지만 준 경우(예: "갑자년 정축월") → 최소 일주 안내 ──
    if (looksLikePartialPillars(text)) {
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

    if (text === "/today") {
      // 오늘 일진만 짧게. "오늘/일진"이 들어 있어 teacher가 오늘 데이터를 자동 첨부한다.
      question = "오늘 일진 어때? 핵심만 짧게 알려줘.";
    } else if (text === "/퀴즈") {
      question =
        "지금까지 나눈 대화나 내 사주 계산 데이터 중에서 개념 하나를 골라 복습 문제를 내주세요. " +
        "정답을 바로 알려주지 말고, 문제만 먼저 주고 제가 답해볼 수 있게 기다려주세요. " +
        "제가 다음 메시지로 답하면 그때 채점하고, 틀렸거나 애매하면 원리를 다시 짚어 설명해주세요.";
    } else {
      // ── 자연어 의도 분류 (Step 3). 슬래시 명령이 아닌 자유 텍스트는 전부 여기를 거친다 ──
      const intent = detectIntent(text);

      if (intent === "privacyCheck") {
        await sendMessage(chatId, PRIVACY_TEXT);
        return;
      }
      if (intent === "resetContext") {
        await store.clearHistory(chatId);
        await sendMessage(chatId, "대화 기록을 초기화했어요. 사주 등록은 유지됩니다.");
        return;
      }
      if (intent === "memoryDelete") {
        const scope = detectMemoryDeleteScope(text);
        const removed = await store.deleteMemory(chatId, scope);
        await sendMessage(chatId, removed > 0 ? `기억 ${removed}건 지웠어요 ✅` : "지울 만한 저장된 기억이 없었어요.");
        return;
      }
      if (intent === "memoryLookup") {
        const memories = user.memories ?? [];
        if (memories.length === 0) {
          await sendMessage(chatId, "아직 기억해둔 게 없어요. \"기억해줘\"라고 말하면 그때부터 요약해서 기억할게요.");
          return;
        }
        const lines = memories.slice(-10).map((m) => `• [${m.category}] ${m.summary}`);
        await sendMessage(chatId, `기억하고 있는 것들:\n${lines.join("\n")}`);
        return;
      }
      if (intent === "memorySave") {
        const typing = setInterval(() => void sendTyping(chatId), 5000);
        void sendTyping(chatId);
        try {
          const { category, summary, sensitive } = await summarizeForMemory(user.history, text);
          await store.addMemory(chatId, { category, summary, sensitive });
          await sendMessage(chatId, `기억해뒀어요 ✅ (${category})\n"${summary}"`);
        } finally {
          clearInterval(typing);
        }
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
