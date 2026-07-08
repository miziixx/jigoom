// 나의 사주 선생님 — 로컬/개발용 진입점 (롱폴링).
// 프로덕션은 웹훅(api/telegram-webhook.ts, Vercel 서버리스)을 쓴다 — 24/7 상주 서버 비용이 없다.
// 이 파일은 로컬에서 빠르게 테스트하고 싶을 때만 쓴다:
// 실행: TELEGRAM_BOT_TOKEN=... ANTHROPIC_API_KEY=... npm run bot
//
// 주의: 텔레그램은 웹훅과 롱폴링을 동시에 못 쓴다. 웹훅이 등록된 상태(setWebhook)면
// 이 스크립트를 돌려도 getUpdates가 계속 실패한다. 로컬 테스트 전엔 deleteWebhook부터 하자.
import { getUpdates } from "./telegram.js";
import { handleMessage } from "./messageHandler.js";
import { fileStore } from "./fileStore.js";
import { logError } from "./logSafe.js";

async function main(): Promise<void> {
  console.log("사주 선생님 봇 시작 (롱폴링, 로컬 테스트용). 모델:", process.env.BOT_MODEL ?? "claude-opus-4-8");
  let offset = 0;
  for (;;) {
    try {
      const updates = await getUpdates(offset);
      for (const u of updates) {
        offset = u.update_id + 1;
        if (u.message) {
          // 순차 처리 (개인 봇 규모에선 충분). 오류가 폴링 루프를 죽이지 않게 개별 처리.
          await handleMessage(u.message, fileStore).catch((e) => logError("bot/index handleMessage", e));
        }
      }
    } catch (err) {
      logError("bot/index polling(5초 후 재시도)", err);
      await new Promise((r) => setTimeout(r, 5000));
    }
  }
}

void main();
