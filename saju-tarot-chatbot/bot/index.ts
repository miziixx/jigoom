// 나의 사주 선생님 — 롱폴링 진입점 (Railway 등 24/7 상주 프로세스 / 로컬 테스트 공용).
// 롱폴링은 텔레그램에 HTTP 응답 시한(웹훅 60초)이 없어서, 긴 사주 리딩(60~120초)도
// 중간에 안 끊기고 끝까지 전달된다. 실행: TELEGRAM_BOT_TOKEN=... ANTHROPIC_API_KEY=... npm run bot
//
// 저장소는 환경변수로 자동 선택한다:
//   · UPSTASH_REDIS_REST_URL/TOKEN 이 있으면 → Upstash(kvStore). 웹훅 모드와 같은 DB라
//     이전에 등록해둔 사주/대화가 그대로 이어지고, 재배포해도 데이터가 유지된다. (Railway 권장)
//   · 없으면 → 로컬 파일(fileStore). 단, Railway처럼 디스크가 초기화되는 곳에선 재배포 시 리셋됨.
//
// 주의: 텔레그램은 웹훅과 롱폴링을 동시에 못 쓴다. 웹훅이 등록된 상태(setWebhook)면
// getUpdates가 409로 계속 실패한다 — 롱폴링으로 옮길 땐 먼저 deleteWebhook 하자.
import { webcrypto } from "node:crypto";
// 일부 Node 런타임(예: Railway의 Node 18)엔 전역 crypto(Web Crypto)가 없어서, 이를
// 참조하는 코드(예: 예전 teacher.ts, 일부 src/lib 유틸)가 'crypto is not defined'로
// 죽을 수 있다. 프로세스 시작 시 한 번 폴리필해, 어떤 경로에서도 이 에러가 안 나게 한다.
if (!(globalThis as { crypto?: unknown }).crypto) {
  (globalThis as { crypto?: unknown }).crypto = webcrypto;
}

import { getUpdates } from "./telegram.js";
import { handleMessage } from "./messageHandler.js";
import { fileStore } from "./fileStore.js";
import { kvStore } from "./kvStore.js";
import type { Store } from "./storeTypes.js";
import { logError } from "./logSafe.js";

const useUpstash = Boolean(process.env.UPSTASH_REDIS_REST_URL && process.env.UPSTASH_REDIS_REST_TOKEN);
const store: Store = useUpstash ? kvStore : fileStore;

async function main(): Promise<void> {
  console.log(
    `사주 선생님 봇 시작 (롱폴링). 저장소: ${useUpstash ? "Upstash Redis" : "로컬 파일"}, 모델: ${process.env.BOT_MODEL ?? "claude-sonnet-5"}`,
  );
  let offset = 0;
  for (;;) {
    try {
      const updates = await getUpdates(offset);
      for (const u of updates) {
        offset = u.update_id + 1;
        if (u.message) {
          // 순차 처리 (개인 봇 규모에선 충분). 오류가 폴링 루프를 죽이지 않게 개별 처리.
          await handleMessage(u.message, store).catch((e) => logError("bot/index handleMessage", e));
        }
      }
    } catch (err) {
      logError("bot/index polling(5초 후 재시도)", err);
      await new Promise((r) => setTimeout(r, 5000));
    }
  }
}

void main();
