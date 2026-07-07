// 사주 선생님 봇 메시지 처리 로직 — 롱폴링(bot/index.ts)과 웹훅(api/telegram-webhook.ts)이 공유한다.
// 저장소(Store)만 주입받아 동작하므로, 어떤 방식으로 실행되는지는 이 파일이 몰라도 된다.
import { sendMessage, sendTyping, type TgMessage } from "./telegram.js";
import { parseBirthInput, describeBirthInfo } from "./parseBirth.js";
import { formatChartSummary } from "./evidence.js";
import { askTeacher } from "./teacher.js";
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
  "먼저 사주를 등록해주세요.",
  "",
  BIRTH_GUIDE,
  "",
  "등록 후에는 이렇게 물어보세요:",
  "• 나 왜 신약사주야?",
  "• 오늘 일진이 왜 이렇게 흘러가?",
  "• 내 격국이 뭔지, 왜 그렇게 잡히는지 알려줘",
  "• 지장간은 왜 그렇게 배당되는 거야? (내 사주와 무관한 원리 질문도 OK)",
  "",
  "명령어: /saju 원국 요약 · /today 오늘 일진 풀이 · /퀴즈 배운 개념 복습 · /birth 사주 재등록 · /reset 대화 초기화 · /delete 데이터 삭제",
].join("\n");

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
        await sendMessage(chatId, "먼저 사주를 등록해주세요.\n\n" + BIRTH_GUIDE);
        return;
      }
      await sendMessage(chatId, formatChartSummary(user.birthInfo));
      return;
    }

    // ── 사주 미등록: 입력을 생년월일시로 해석 ──
    if (!user.birthInfo) {
      const parsed = parseBirthInput(text);
      if (!parsed.ok) {
        await sendMessage(chatId, `${parsed.error}\n\n${BIRTH_GUIDE}`);
        return;
      }
      await store.setBirthInfo(chatId, parsed.birthInfo!);
      await sendMessage(chatId, `등록했어요 ✅\n${describeBirthInfo(parsed.birthInfo!)}\n\n${formatChartSummary(parsed.birthInfo!)}`);
      return;
    }

    // ── 등록된 상태에서 생년월일 형태 입력이 오면 재등록으로 처리 ──
    if (/(19|20)\d{2}\s*[.\-/년]/.test(text) && /남|여/.test(text)) {
      const parsed = parseBirthInput(text);
      if (parsed.ok) {
        await store.setBirthInfo(chatId, parsed.birthInfo!);
        await sendMessage(
          chatId,
          `사주를 새로 등록했어요 ✅ (이전 대화 맥락은 초기화)\n${describeBirthInfo(parsed.birthInfo!)}\n\n${formatChartSummary(parsed.birthInfo!)}`,
        );
        return;
      }
    }

    // ── 질문 → 사주 선생님(Claude) ──
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
