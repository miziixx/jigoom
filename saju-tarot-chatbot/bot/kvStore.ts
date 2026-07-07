// Upstash Redis(REST API) 기반 저장소 — Vercel 웹훅(서버리스)에서 쓴다.
// 서버리스는 파일시스템이 요청/인스턴스마다 초기화되므로 프로필·대화 기록을 외부에 둬야 한다.
// api/_security.ts의 upstashRateLimit()과 동일한 순수 HTTP REST 방식(호스팅 이식성 유지).
import type { BirthInfo } from "../src/types/index.js";
import { MAX_HISTORY, emptyUser, type ChatTurn, type Store, type UserRecord } from "./storeTypes.js";

function requireEnv(): { url: string; token: string } {
  const url = process.env.UPSTASH_REDIS_REST_URL;
  const token = process.env.UPSTASH_REDIS_REST_TOKEN;
  if (!url || !token) {
    throw new Error(
      "UPSTASH_REDIS_REST_URL / UPSTASH_REDIS_REST_TOKEN 환경변수가 필요합니다. " +
        "웹훅(서버리스) 모드는 파일 저장을 못 쓰므로 Upstash Redis가 필수예요.",
    );
  }
  return { url, token };
}

async function redisPipeline(commands: (string | number)[][]): Promise<unknown[]> {
  const { url, token } = requireEnv();
  const res = await fetch(`${url}/pipeline`, {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify(commands),
  });
  if (!res.ok) throw new Error(`Upstash 요청 실패: ${res.status}`);
  const data = (await res.json()) as Array<{ result: unknown; error?: string }>;
  const firstError = data.find((d) => d.error);
  if (firstError) throw new Error(`Upstash 명령 실패: ${firstError.error}`);
  return data.map((d) => d.result);
}

function userKey(chatId: number): string {
  return `saju-bot:user:${chatId}`;
}

async function readUser(chatId: number): Promise<UserRecord> {
  const [raw] = await redisPipeline([["GET", userKey(chatId)]]);
  if (typeof raw !== "string") return emptyUser();
  try {
    const parsed = JSON.parse(raw) as UserRecord;
    return { birthInfo: parsed.birthInfo ?? null, history: parsed.history ?? [], updatedAt: parsed.updatedAt };
  } catch {
    return emptyUser();
  }
}

async function writeUser(chatId: number, user: UserRecord): Promise<void> {
  user.updatedAt = new Date().toISOString();
  await redisPipeline([["SET", userKey(chatId), JSON.stringify(user)]]);
}

export const kvStore: Store = {
  async getUser(chatId: number): Promise<UserRecord> {
    return readUser(chatId);
  },

  async setBirthInfo(chatId: number, birthInfo: BirthInfo): Promise<void> {
    const user = await readUser(chatId);
    user.birthInfo = birthInfo;
    user.history = []; // 사주가 바뀌면 이전 해석 맥락은 무효
    await writeUser(chatId, user);
  },

  async appendHistory(chatId: number, ...turns: ChatTurn[]): Promise<void> {
    const user = await readUser(chatId);
    user.history.push(...turns);
    if (user.history.length > MAX_HISTORY) {
      user.history = user.history.slice(user.history.length - MAX_HISTORY);
    }
    await writeUser(chatId, user);
  },

  async clearHistory(chatId: number): Promise<void> {
    const user = await readUser(chatId);
    user.history = [];
    await writeUser(chatId, user);
  },

  async deleteUser(chatId: number): Promise<void> {
    await redisPipeline([["DEL", userKey(chatId)]]);
  },
};

/**
 * 텔레그램 웹훅 재시도로 같은 update_id가 두 번 오는 걸 막는다.
 * SET ... NX EX 로 "처음 보는 update_id일 때만 성공"하는 원자적 체크.
 * 반환값 true = 새 업데이트(처리해야 함), false = 중복(건너뛰어야 함).
 */
export async function markUpdateProcessed(updateId: number): Promise<boolean> {
  const [result] = await redisPipeline([["SET", `saju-bot:seen:${updateId}`, "1", "NX", "EX", "3600"]]);
  return result === "OK";
}
