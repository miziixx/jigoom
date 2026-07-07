// 사주 선생님 봇 메시지 처리 로직 — 롱폴링(bot/index.ts)과 웹훅(api/telegram-webhook.ts)이 공유한다.
// 저장소(Store)만 주입받아 동작하므로, 어떤 방식으로 실행되는지는 이 파일이 몰라도 된다.
import { sendMessage, sendTyping, type TgMessage } from "./telegram.js";
import { parseBirthInput, describeBirthInfo, looksLikeBirthInput, parseRelationType } from "./parseBirth.js";
import { formatChartSummary, buildCompatibilityEvidence } from "./evidence.js";
import { askTeacher, askCompatibility } from "./teacher.js";
import type { Store } from "./storeTypes.js";

// 개인 봇 보호: 지정하면 이 텔레그램 사용자 ID만 사용 가능 (쉼표 구분)
const ALLOWED_IDS = new Set(
  (process.env.TELEGRAM_ALLOWED_USER_IDS ?? "")
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

const COMPAT_GUIDE = [
  "*궁합*을 볼게요. 상대방 생년월일시를 한 줄로 보내주세요 (내 사주 등록과 같은 형식).",
  "",
  "관계도 같이 적어주면 그 관계에 맞게 풀어드려요:",
  "• `1995-06-20 09:30 남 서울 연인`",
  "• `음력 1992년 3월 5일 시간모름 여 부산 동료`",
  "",
  "관계 키워드: 연인 · 부모/자식 · 형제 · 가족 · 직장상사 · 동료 · 친구 (안 적으면 연인으로 봐요)",
  "그만두려면 /reset",
].join("\n");

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
    if (text === "/saju") {
      if (!user.birthInfo) {
        await sendMessage(chatId, "이건 내 사주 원국이 있어야 보여줄 수 있어요. 먼저 등록해주세요.\n\n" + BIRTH_GUIDE);
        return;
      }
      await sendMessage(chatId, formatChartSummary(user.birthInfo));
      return;
    }
    if (text === "/today" && !user.birthInfo) {
      await sendMessage(chatId, "오늘 일진은 내 사주와 오늘 간지를 대조해야 해서, 먼저 등록이 필요해요.\n\n" + BIRTH_GUIDE);
      return;
    }
    if (text === "/궁합" || text === "/compat" || text === "/궁합보기") {
      if (!user.birthInfo) {
        await sendMessage(chatId, "궁합은 내 사주와 상대 사주를 맞대봐야 해서, 먼저 내 사주부터 등록해주세요.\n\n" + BIRTH_GUIDE);
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
        const answer = await askCompatibility({ compatEvidence });
        await sendMessage(chatId, answer);
      } finally {
        clearInterval(typing);
      }
      return;
    }

    // ── 생년월일시 형태 입력 → 등록/재등록 (등록 여부와 무관하게 처리) ──
    if (looksLikeBirthInput(text)) {
      const parsed = parseBirthInput(text);
      if (parsed.ok) {
        const wasRegistered = Boolean(user.birthInfo);
        await store.setBirthInfo(chatId, parsed.birthInfo!);

        // 생일과 함께 질문까지 한 번에 보냈으면(예: "95년 8월 23일남자 성격 봐줘")
        // 등록 사실만 한 줄로 알리고 곧바로 그 질문에 답한다.
        const followUp = extractQuestion(parsed.remainder);
        if (followUp) {
          await sendMessage(chatId, `${describeBirthInfo(parsed.birthInfo!)}로 보고 답할게요.`);
          const typing = setInterval(() => void sendTyping(chatId), 5000);
          void sendTyping(chatId);
          try {
            const answer = await askTeacher({ birthInfo: parsed.birthInfo!, history: [], question: followUp });
            await store.appendHistory(chatId, { role: "user", content: followUp }, { role: "assistant", content: answer });
            await sendMessage(chatId, answer);
          } finally {
            clearInterval(typing);
          }
          return;
        }

        const prefix = wasRegistered ? "사주를 새로 등록했어요 ✅ (이전 대화 맥락은 초기화)" : "등록했어요 ✅";
        await sendMessage(chatId, `${prefix}\n${describeBirthInfo(parsed.birthInfo!)}\n\n${formatChartSummary(parsed.birthInfo!)}`);
        return;
      }
      // 등록 시도로 보이는데 형식이 안 맞으면 안내. 등록 전 사용자에게만 보여준다 —
      // 이미 등록된 사용자가 그냥 연도/성별이 우연히 섞인 질문을 했을 수도 있어서다.
      if (!user.birthInfo) {
        await sendMessage(chatId, `${parsed.error}\n\n${BIRTH_GUIDE}`);
        return;
      }
    }

    // ── 질문 → 사주 선생님(Claude). 사주 등록 여부와 무관하게 답한다 ──
    let question = text;
    if (text === "/today") {
      question = "오늘 일진이 어떻게 흘러가는지, 왜 그렇게 보는지 계산 근거를 짚어가며 자세히 알려주세요.";
    } else if (text === "/퀴즈") {
      question =
        "지금까지 나눈 대화나 내 사주 계산 데이터 중에서 개념 하나를 골라 복습 문제를 내주세요. " +
        "정답을 바로 알려주지 말고, 문제만 먼저 주고 제가 답해볼 수 있게 기다려주세요. " +
        "제가 다음 메시지로 답하면 그때 채점하고, 틀렸거나 애매하면 원리를 다시 짚어 설명해주세요.";
    }

    const typing = setInterval(() => void sendTyping(chatId), 5000);
    void sendTyping(chatId);
    try {
      const answer = await askTeacher({ birthInfo: user.birthInfo, history: user.history, question });
      await store.appendHistory(chatId, { role: "user", content: question }, { role: "assistant", content: answer });
      await sendMessage(chatId, answer);
    } finally {
      clearInterval(typing);
    }
  } catch (err) {
    console.error("메시지 처리 오류:", err);
    await sendMessage(chatId, `문제가 생겼어요: ${err instanceof Error ? err.message : String(err)}`).catch(() => {});
  }
}
