// 나의 사주 선생님 — 텔레그램 봇 진입점 (롱폴링)
// 실행: TELEGRAM_BOT_TOKEN=... ANTHROPIC_API_KEY=... npm run bot
import { getUpdates, sendMessage, sendTyping, type TgMessage } from "./telegram.js";
import { getUser, setBirthInfo, appendHistory, clearHistory, deleteUser } from "./store.js";
import { parseBirthInput, describeBirthInfo } from "./parseBirth.js";
import { formatChartSummary } from "./evidence.js";
import { askTeacher } from "./teacher.js";

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
  "",
  "명령어: /saju 원국 요약 · /today 오늘 일진 풀이 · /birth 사주 재등록 · /reset 대화 초기화 · /delete 데이터 삭제",
].join("\n");

async function handleMessage(msg: TgMessage): Promise<void> {
  const chatId = msg.chat.id;
  const text = (msg.text ?? "").trim();
  if (!text) return;

  if (ALLOWED_IDS.size > 0 && !ALLOWED_IDS.has(String(msg.from?.id ?? ""))) {
    await sendMessage(chatId, "이 봇은 개인용이라 등록된 사용자만 쓸 수 있어요.");
    return;
  }

  const user = getUser(chatId);

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
    clearHistory(chatId);
    await sendMessage(chatId, "대화 기록을 초기화했어요. 사주 등록은 유지됩니다.");
    return;
  }
  if (text === "/delete") {
    deleteUser(chatId);
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
    setBirthInfo(chatId, parsed.birthInfo!);
    await sendMessage(chatId, `등록했어요 ✅\n${describeBirthInfo(parsed.birthInfo!)}\n\n${formatChartSummary(parsed.birthInfo!)}`);
    return;
  }

  // ── 등록된 상태에서 생년월일 형태 입력이 오면 재등록으로 처리 ──
  if (/(19|20)\d{2}\s*[.\-/년]/.test(text) && /남|여/.test(text)) {
    const parsed = parseBirthInput(text);
    if (parsed.ok) {
      setBirthInfo(chatId, parsed.birthInfo!);
      await sendMessage(chatId, `사주를 새로 등록했어요 ✅ (이전 대화 맥락은 초기화)\n${describeBirthInfo(parsed.birthInfo!)}\n\n${formatChartSummary(parsed.birthInfo!)}`);
      return;
    }
  }

  // ── 질문 → 사주 선생님(Claude) ──
  const question = text === "/today" ? "오늘 일진이 어떻게 흘러가는지, 왜 그렇게 보는지 계산 근거를 짚어가며 자세히 알려주세요." : text;

  const typing = setInterval(() => void sendTyping(chatId), 5000);
  void sendTyping(chatId);
  try {
    const answer = await askTeacher({
      birthInfo: user.birthInfo,
      history: user.history,
      question,
    });
    appendHistory(chatId, { role: "user", content: question }, { role: "assistant", content: answer });
    await sendMessage(chatId, answer);
  } catch (err) {
    console.error("askTeacher 오류:", err);
    await sendMessage(chatId, `답변 생성 중 오류가 났어요: ${err instanceof Error ? err.message : String(err)}`);
  } finally {
    clearInterval(typing);
  }
}

async function main(): Promise<void> {
  console.log("사주 선생님 봇 시작 (롱폴링). 모델:", process.env.BOT_MODEL ?? "claude-opus-4-8");
  let offset = 0;
  for (;;) {
    try {
      const updates = await getUpdates(offset);
      for (const u of updates) {
        offset = u.update_id + 1;
        if (u.message) {
          // 순차 처리 (개인 봇 규모에선 충분). 오류가 폴링 루프를 죽이지 않게 개별 처리.
          await handleMessage(u.message).catch((e) => console.error("메시지 처리 오류:", e));
        }
      }
    } catch (err) {
      console.error("폴링 오류(5초 후 재시도):", err instanceof Error ? err.message : err);
      await new Promise((r) => setTimeout(r, 5000));
    }
  }
}

void main();
