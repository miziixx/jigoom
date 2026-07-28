/**
 * API 남용 방어 공통 보안 유틸 (P0) — 프레임워크 무관 구현.
 *
 * 설계 원칙(이식성):
 *  - Vercel 전용 타입/미들웨어/런타임 헬퍼(@vercel/*)에 의존하지 않는다.
 *  - 표준 요청 헤더와 process.env, 전역 fetch만 사용한다.
 *  - 응답을 직접 쓰지 않고 "판정 결과(SecurityDecision)"만 반환한다.
 *    → 응답 방식이 다른 어떤 serverless(Vercel/Netlify/Cloudflare/자체 Node)로도 이식 가능.
 *
 * 목적: 인증이 없는 공개 함수(/api/reading 등)가 스크립트로 무제한 호출되어
 * LLM 청구서가 폭증하는 것을 막는다.
 *
 * 2단계 rate limit:
 *  1) 즉시 방어(외부 의존 없음): 인스턴스 메모리 슬라이딩 창.
 *  2) 정밀 방어(옵션): UPSTASH_REDIS_REST_URL/TOKEN 이 있으면 Redis(REST, 표준 HTTP)로
 *     자동 승격. Upstash는 특정 호스팅에 묶이지 않는 순수 HTTP API라 이식성을 해치지 않는다.
 *     장애/미설정 시 1)로 안전 폴백.
 */

// ── 요청 추상화 (특정 프레임워크 타입에 의존하지 않는 최소 형태) ──
export interface SecurityRequestLike {
  headers: Record<string, string | string[] | undefined>;
  body?: unknown;
  socket?: { remoteAddress?: string };
}

export interface SecurityDecision {
  /** true면 통과. false면 status/message로 거절 응답을 구성하면 된다. */
  ok: boolean;
  status?: number;
  message?: string;
  /** 거절 시 함께 내려줄 응답 헤더(예: Retry-After). */
  headers?: Record<string, string>;
}

// ── 튜닝 값 ─────────────────────────────────────────────────
const WINDOW_MS = 60_000; // 1분 창
// IP당 1분 허용 횟수. 리딩 하나가 앞/뒤 fan-out 2회 + 각 파트별 이어쓰기(continue) 최대 6회
// (readingApi.ts MAX_CONTINUATIONS)까지 별도 HTTP 호출을 낼 수 있어, 이론상 한 번의 고급(advanced)
// 리딩만으로도 최대 (1+6)*2 = 14회까지 소모될 수 있다. 12로는 그 정상 흐름조차 429로 막을 수 있어
// 여유를 두고 40으로 올린다.
const MAX_REQ_PER_WINDOW = 40;
export const MAX_QUESTION_LEN = 2000; // 질문/고민 텍스트 상한
export const MAX_CONTEXT_FIELD_LEN = 1000; // 상담 컨텍스트 개별 필드 상한
export const MAX_BODY_BYTES = 200_000; // 요청 본문 전체 상한(≈200KB)

// ── 헤더 접근 헬퍼 ─────────────────────────────────────────
function header(req: SecurityRequestLike, name: string): string {
  const v = req.headers[name] ?? req.headers[name.toLowerCase()];
  if (Array.isArray(v)) return v[0] ?? "";
  return typeof v === "string" ? v : "";
}

// ── 클라이언트 IP 추출 (표준 프록시 헤더 우선) ──────────────
function getClientIp(req: SecurityRequestLike): string {
  const xff = header(req, "x-forwarded-for");
  if (xff) return xff.split(",")[0].trim();
  const real = header(req, "x-real-ip");
  if (real) return real;
  return req.socket?.remoteAddress ?? "unknown";
}

// ── Origin/Referer 검증 ─────────────────────────────────────
/**
 * 허용 호스트: 요청이 도착한 호스트(자기 자신) + ALLOWED_ORIGINS(쉼표구분) + 로컬 개발.
 * VERCEL_URL 이 있으면 편의상 함께 허용하되, 없어도 동작하므로 종속성이 아니다.
 * 브라우저 same-origin 요청은 Origin/Referer가 자기 호스트라 통과한다.
 * Origin/Referer가 전혀 없는 순수 스크립트 호출은 차단한다.
 */
function isAllowedOrigin(req: SecurityRequestLike): boolean {
  const selfHost = header(req, "host").toLowerCase();
  const allowed = new Set<string>();
  if (selfHost) allowed.add(selfHost);
  // 플랫폼이 제공하면 사용, 없으면 무시(하드 종속성 아님).
  const platformUrl = process.env.VERCEL_URL || process.env.DEPLOY_URL || process.env.URL;
  if (platformUrl) allowed.add(platformUrl.toLowerCase().replace(/^https?:\/\//, "").replace(/\/$/, ""));
  for (const o of (process.env.ALLOWED_ORIGINS ?? "").split(",")) {
    const h = o.trim().toLowerCase().replace(/^https?:\/\//, "").replace(/\/$/, "");
    if (h) allowed.add(h);
  }

  const source = header(req, "origin") || header(req, "referer");
  if (!source) return false; // 브라우저 요청이면 최소 Referer는 붙는다

  let host: string;
  try {
    host = new URL(source).host.toLowerCase();
  } catch {
    return false;
  }
  if (host.startsWith("localhost") || host.startsWith("127.0.0.1")) return true;
  return allowed.has(host);
}

// ── rate limit: 인스턴스 메모리 슬라이딩 창 ──────────────────
const hits = new Map<string, number[]>();

function inMemoryRateLimit(ip: string): boolean {
  const now = Date.now();
  const arr = (hits.get(ip) ?? []).filter((t) => now - t < WINDOW_MS);
  arr.push(now);
  hits.set(ip, arr);
  if (hits.size > 5000) {
    for (const [k, v] of hits) {
      if (v.every((t) => now - t >= WINDOW_MS)) hits.delete(k);
    }
  }
  return arr.length <= MAX_REQ_PER_WINDOW;
}

// ── rate limit: Upstash Redis (표준 HTTP REST, env 있을 때만) ─
async function upstashRateLimit(ip: string): Promise<boolean | null> {
  const url = process.env.UPSTASH_REDIS_REST_URL;
  const token = process.env.UPSTASH_REDIS_REST_TOKEN;
  if (!url || !token) return null; // 미설정 → 인메모리 폴백

  const key = `rl:${ip}:${Math.floor(Date.now() / WINDOW_MS)}`;
  try {
    const res = await fetch(`${url}/pipeline`, {
      method: "POST",
      headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
      body: JSON.stringify([
        ["INCR", key],
        ["EXPIRE", key, Math.ceil(WINDOW_MS / 1000)],
      ]),
    });
    if (!res.ok) return null; // Redis 장애 시 요청을 막지 않고 인메모리 폴백
    const data = (await res.json()) as Array<{ result?: number }>;
    const count = data?.[0]?.result ?? 0;
    return count <= MAX_REQ_PER_WINDOW;
  } catch {
    return null; // 네트워크 실패 → 인메모리 폴백
  }
}

// ── 본문 크기 상한 ──────────────────────────────────────────
function bodyTooLarge(req: SecurityRequestLike): boolean {
  const len = Number(header(req, "content-length") || 0);
  if (len && len > MAX_BODY_BYTES) return true;
  if (typeof req.body === "string" && req.body.length > MAX_BODY_BYTES) return true;
  return false;
}

/**
 * 모든 방어 검사를 순서대로 수행하고 판정만 반환한다(응답은 호출부가 구성).
 *
 * 사용 예(Vercel/Express 스타일):
 *   const verdict = await checkSecurity(req);
 *   if (!verdict.ok) return sendDenied(res, verdict);
 */
export async function checkSecurity(req: SecurityRequestLike): Promise<SecurityDecision> {
  if (!isAllowedOrigin(req)) {
    return { ok: false, status: 403, message: "허용되지 않은 요청 출처입니다." };
  }
  if (bodyTooLarge(req)) {
    return { ok: false, status: 413, message: "요청이 너무 큽니다." };
  }
  const ip = getClientIp(req);
  const viaRedis = await upstashRateLimit(ip);
  const ok = viaRedis === null ? inMemoryRateLimit(ip) : viaRedis;
  if (!ok) {
    return {
      ok: false,
      status: 429,
      message: "요청이 너무 잦습니다. 잠시 후 다시 시도해 주세요.",
      headers: { "Retry-After": String(Math.ceil(WINDOW_MS / 1000)) },
    };
  }
  return { ok: true };
}

/** 문자열 필드를 상한 길이로 절삭한다(요청을 막지 않고 방어적으로 자름). */
export function clampText(v: unknown, max: number): string | undefined {
  if (typeof v !== "string") return undefined;
  return v.length > max ? v.slice(0, max) : v;
}

// ── 진단 엔드포인트 접근 제어 ────────────────────────────────
/** 길이가 같을 때 타이밍 차이를 줄이는 문자열 비교(약한 토큰용, node:crypto 없이 이식 가능). */
function constantTimeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

/**
 * /api/health 같은 진단 엔드포인트에서 상세 정보를 보여줘도 되는지 판정한다.
 *
 * - HEALTH_TOKEN(또는 DIAGNOSTIC_TOKEN) env가 없으면 항상 false → 최소 정보만 노출(안전 기본값).
 * - env가 있고 요청 헤더(x-diagnostic-token / x-health-token)가 일치하면 true.
 *
 * 표준 헤더 + env만 사용하므로 Vercel 밖에서도 그대로 동작한다.
 */
export function hasValidDiagnosticToken(req: SecurityRequestLike): boolean {
  const expected = process.env.HEALTH_TOKEN || process.env.DIAGNOSTIC_TOKEN;
  if (!expected) return false;
  const provided = header(req, "x-diagnostic-token") || header(req, "x-health-token");
  return provided.length > 0 && constantTimeEqual(provided, expected);
}
