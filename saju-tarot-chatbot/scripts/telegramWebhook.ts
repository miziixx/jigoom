// 텔레그램 봇 웹훅 진단·수리 도구.
//
// "봇이 먹통이다 / 엉뚱한 데 연결돼 있다" 를 고칠 때 쓴다. 텔레그램에게 지금 웹훅이
// 어디로 걸려 있고 마지막 에러가 뭔지 직접 물어보고, 필요하면 올바른 URL로 다시 건다.
//
// 실행 (saju-tarot-chatbot/ 에서):
//   TELEGRAM_BOT_TOKEN=<봇토큰> npx tsx scripts/telegramWebhook.ts info
//   TELEGRAM_BOT_TOKEN=<봇토큰> npx tsx scripts/telegramWebhook.ts me
//   TELEGRAM_BOT_TOKEN=<봇토큰> TELEGRAM_WEBHOOK_SECRET=<시크릿> \
//     npx tsx scripts/telegramWebhook.ts set https://<내-vercel-도메인>/api/telegram-webhook
//   TELEGRAM_BOT_TOKEN=<봇토큰> npx tsx scripts/telegramWebhook.ts delete
//
// npm 스크립트로도: `npm run webhook:info` / `npm run webhook:set -- <url>` 등.

const TOKEN = process.env.TELEGRAM_BOT_TOKEN;
if (!TOKEN) {
  console.error(
    "TELEGRAM_BOT_TOKEN 환경변수가 필요합니다.\n" +
      "예)  TELEGRAM_BOT_TOKEN=123456:ABC... npx tsx scripts/telegramWebhook.ts info",
  );
  process.exit(1);
}
const API = `https://api.telegram.org/bot${TOKEN}`;

async function call(method: string, params?: Record<string, unknown>): Promise<any> {
  const res = await fetch(`${API}/${method}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(params ?? {}),
  });
  const json = (await res.json()) as { ok: boolean; result?: unknown; description?: string };
  if (!json.ok) throw new Error(`Telegram ${method} 실패: ${json.description}`);
  return json.result;
}

function fmtDate(epochSec?: number): string {
  if (!epochSec) return "-";
  return new Date(epochSec * 1000).toISOString();
}

async function showInfo(): Promise<void> {
  const info = await call("getWebhookInfo");
  console.log("── 현재 웹훅 상태 ──────────────────────────────");
  console.log("연결된 URL           :", info.url || "(없음 — 웹훅 미등록 = 롱폴링 대기 상태)");
  console.log("대기 중인 메시지 수   :", info.pending_update_count ?? 0);
  console.log("서버 IP              :", info.ip_address ?? "-");
  console.log("마지막 에러 시각      :", fmtDate(info.last_error_date));
  console.log("마지막 에러 메시지    :", info.last_error_message ?? "(없음)");
  console.log("마지막 동기화 에러    :", info.last_synchronization_error_message ?? "(없음)");
  console.log("최대 커넥션          :", info.max_connections ?? "-");
  console.log("허용 업데이트        :", JSON.stringify(info.allowed_updates ?? []));
  console.log("──────────────────────────────────────────────");

  if (!info.url) {
    console.log("\n진단: 웹훅이 안 걸려 있습니다. Vercel 웹훅으로 쓰려면 `set <url>` 로 등록하세요.");
  } else if (info.last_error_message) {
    console.log(
      "\n진단: 텔레그램이 웹훅 URL을 호출했지만 실패하고 있습니다 (위 '마지막 에러 메시지' 참고).\n" +
        "  · 401/secret token → Vercel의 TELEGRAM_WEBHOOK_SECRET 과 setWebhook 때 넣은 값이 다름\n" +
        "  · 404 / Not Found  → URL 오타이거나 그 배포가 사라짐 (도메인 확인 후 `set` 다시)\n" +
        "  · timeout / 502·503 → 함수가 죽거나 환경변수(TOKEN·UPSTASH·ANTHROPIC) 누락으로 500\n" +
        "  · SSL/DNS 계열     → 도메인이 더 이상 그 호스트를 안 가리킴",
    );
  } else if ((info.pending_update_count ?? 0) > 0) {
    console.log("\n진단: 에러는 없는데 메시지가 쌓여 있습니다. 함수가 응답은 하지만 느리거나 방금 복구된 상태일 수 있어요.");
  } else {
    console.log("\n진단: 웹훅은 정상으로 보입니다. 그래도 무응답이면 배포/환경변수(ANTHROPIC_API_KEY 등)를 확인하세요.");
  }
}

async function setWebhook(url: string): Promise<void> {
  if (!url || !/^https:\/\//.test(url)) {
    console.error("사용법: set https://<도메인>/api/telegram-webhook  (https 필수)");
    process.exit(1);
  }
  const secret = process.env.TELEGRAM_WEBHOOK_SECRET;
  const params: Record<string, unknown> = {
    url,
    allowed_updates: ["message"],
    drop_pending_updates: true, // 밀려 있던 옛 메시지는 버리고 깨끗하게 시작
  };
  if (secret) params.secret_token = secret;
  else console.warn("⚠️  TELEGRAM_WEBHOOK_SECRET 이 없어 secret 없이 등록합니다. Vercel 쪽도 secret 미설정이어야 합니다.");
  await call("setWebhook", params);
  console.log("✅ 웹훅 등록 완료:", url);
  console.log("");
  await showInfo();
}

async function deleteWebhook(): Promise<void> {
  await call("deleteWebhook", { drop_pending_updates: false });
  console.log("✅ 웹훅 해제 완료 (이제 롱폴링으로 로컬 테스트 가능).");
}

async function showMe(): Promise<void> {
  const me = await call("getMe");
  console.log("봇 확인 OK →", `@${me.username}`, `(id ${me.id}, name "${me.first_name}")`);
}

async function main(): Promise<void> {
  const [cmd, arg] = process.argv.slice(2);
  switch (cmd) {
    case "info":
      await showInfo();
      break;
    case "set":
      await setWebhook(arg);
      break;
    case "delete":
      await deleteWebhook();
      break;
    case "me":
      await showMe();
      break;
    default:
      console.log(
        "사용법:\n" +
          "  info                       현재 웹훅이 어디 걸려 있고 왜 죽었는지 진단\n" +
          "  me                         봇 토큰이 유효한지 확인\n" +
          "  set <https://.../api/telegram-webhook>   웹훅을 그 URL로 등록\n" +
          "  delete                     웹훅 해제 (롱폴링 테스트용)",
      );
      process.exit(cmd ? 1 : 0);
  }
}

void main().catch((err) => {
  console.error("에러:", err instanceof Error ? err.message : err);
  process.exit(1);
});
