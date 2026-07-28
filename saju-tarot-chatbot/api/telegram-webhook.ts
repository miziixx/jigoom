import type { VercelRequest, VercelResponse } from "@vercel/node";
import { waitUntil } from "@vercel/functions";
import type { TgUpdate } from "../bot/telegram.js";
import { handleMessage } from "../bot/messageHandler.js";
import { kvStore, markUpdateProcessed } from "../bot/kvStore.js";
import { logError } from "../bot/logSafe.js";

/**
 * 텔레그램 웹훅 수신 엔드포인트.
 *
 * 롱폴링(bot/index.ts, 24/7 상주 프로세스 필요 — Railway 등에서 계속 과금)을 대신해,
 * 메시지가 실제로 올 때만 실행되는 서버리스 함수로 처리한다. 등록 방법은
 * bot/README.md의 "웹훅 등록(Vercel)" 절 참고.
 *
 * 텔레그램에 200을 '먼저' 돌려주고, 실제 Claude 응답 생성은 waitUntil로 백그라운드에서
 * 끝까지 돌린다(답은 별도 sendMessage/editMessageText 호출로 전송되므로 200을 늦게 줄
 * 이유가 없다). 예전엔 handleMessage가 끝날 때까지 기다린 뒤 200을 줬는데, 사주 리딩은
 * 60초를 넘기기 일쑤라 텔레그램이 "Read timeout expired"로 연결을 끊었고 → 그 순간 서버리스
 * 함수도 중단되어 답이 통째로 유실됐다(= 봇 무응답). 지금은 즉시 ack → 텔레그램은 타임아웃
 * 없이 종료, 생성은 waitUntil이 maxDuration(vercel.json 300초)까지 살려두고 마무리한다.
 */
export default function handler(req: VercelRequest, res: VercelResponse) {
  if (req.method !== "POST") {
    res.status(405).json({ error: "POST 요청만 지원합니다." });
    return;
  }

  const secret = process.env.TELEGRAM_WEBHOOK_SECRET;
  if (secret) {
    const got = req.headers["x-telegram-bot-api-secret-token"];
    if (got !== secret) {
      res.status(401).json({ error: "invalid secret token" });
      return;
    }
  }

  const update = req.body as TgUpdate;

  if (update?.message) {
    const message = update.message;
    const updateId = update.update_id;
    // 응답을 먼저 보내고, 무거운 생성은 백그라운드에서. waitUntil이 함수 수명을
    // 이 Promise가 끝날 때까지(최대 maxDuration) 연장해 준다.
    waitUntil(
      (async () => {
        try {
          // 텔레그램이 응답 지연 시 웹훅을 재시도할 수 있어, 같은 update_id 중복 처리를 막는다.
          // Redis 장애 시엔 안전하게 "새 업데이트로 간주"하고 처리한다(무응답보다 드문 중복이 낫다).
          const isNew = updateId != null ? await markUpdateProcessed(updateId).catch(() => true) : true;
          if (isNew) {
            await handleMessage(message, kvStore);
          }
        } catch (err) {
          logError("telegram-webhook", err);
        }
      })(),
    );
  }

  res.status(200).json({ ok: true });
}
