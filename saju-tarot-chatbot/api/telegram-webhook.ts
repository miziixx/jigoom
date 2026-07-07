import type { VercelRequest, VercelResponse } from "@vercel/node";
import type { TgUpdate } from "../bot/telegram.js";
import { handleMessage } from "../bot/messageHandler.js";
import { kvStore, markUpdateProcessed } from "../bot/kvStore.js";

/**
 * 텔레그램 웹훅 수신 엔드포인트.
 *
 * 롱폴링(bot/index.ts, 24/7 상주 프로세스 필요 — Railway 등에서 계속 과금)을 대신해,
 * 메시지가 실제로 올 때만 실행되는 서버리스 함수로 처리한다. 등록 방법은
 * bot/README.md의 "웹훅 등록(Vercel)" 절 참고.
 *
 * Claude 응답 생성까지 이 함수 안에서 끝까지 기다린 뒤 반환한다(텔레그램에 보낼 답을
 * 별도 sendMessage 호출로 보내야 하므로). 그래서 vercel.json에 넉넉한 maxDuration을
 * 잡아둔다 — api/reading.ts와 동일하게 300초.
 */
export default async function handler(req: VercelRequest, res: VercelResponse) {
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
    try {
      // 텔레그램이 응답 지연 시 웹훅을 재시도할 수 있어, 같은 update_id 중복 처리를 막는다.
      // Redis 장애 시엔 안전하게 "새 업데이트로 간주"하고 처리한다(무응답보다 드문 중복이 낫다).
      const isNew = update.update_id != null ? await markUpdateProcessed(update.update_id).catch(() => true) : true;
      if (isNew) {
        await handleMessage(update.message, kvStore);
      }
    } catch (err) {
      console.error("웹훅 메시지 처리 오류:", err);
    }
  }

  res.status(200).json({ ok: true });
}
