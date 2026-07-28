# 보안 노트 (Security Notes)

이 문서는 앱 보안 감사 결과와 조치 상태를 기록한다. 미래 Claude/Codex 세션은
보안 관련 변경 전에 이 문서를 읽는다.

## 이식성 원칙 (중요)

Vercel 계속 사용 여부가 확정되지 않았다. 따라서 모든 보안 로직은 **특정 호스팅에
종속되지 않게** 작성한다.

- Vercel 전용 미들웨어(`middleware.ts` Edge), `@vercel/*` 런타임 헬퍼(`@vercel/kv` 등)에
  의존하지 않는다.
- 표준 요청 헤더 + `process.env` + 전역 `fetch`만 사용한다.
- 보안 판정 로직은 응답을 직접 쓰지 않고 **판정 결과만 반환**한다. 응답 표현은 얇은
  핸들러(어댑터)가 담당한다.
- 공통 유틸은 `api/_security.ts` 한 곳에 모은다.

## 조치 완료

### P0 — API 남용 방어 (완료)

인증 없는 공개 함수가 스크립트로 무제한 호출되어 LLM 청구서가 폭증하는 것을 막는다.

- `api/_security.ts` (신규): 프레임워크 무관 공통 유틸.
  - `checkSecurity(req)` → `{ ok, status, message, headers }` 판정 반환.
    - Origin/Referer 검증 (자기 도메인 + `ALLOWED_ORIGINS` + localhost만 허용, 헤더 없으면 차단)
    - 본문 크기 상한 200KB
    - rate limit: IP당 1분 12회. 인메모리 슬라이딩 창이 기본,
      `UPSTASH_REDIS_REST_URL`/`UPSTASH_REDIS_REST_TOKEN` env가 있으면 Redis(표준 HTTP REST)로
      자동 승격, 장애/미설정 시 인메모리 폴백.
  - `clampText(v, max)`: 사용자 자유입력 절삭.
- `api/reading.ts` / `api/fortune.ts` / `api/naming.ts`: 진입부에서 `checkSecurity` 호출.
  reading은 추가로 `question`(2000자)·상담 컨텍스트 필드(각 1000자)를 프롬프트 삽입 전 절삭.
  **사주 계산값은 건드리지 않는다.**

한계(정직하게): Origin 헤더는 스푸핑 가능, 인메모리 limit은 인스턴스별 분리라 완벽하지 않다.
"URL만 알면 무제한 호출"은 차단하지만, 완벽을 원하면 Upstash env 설정 + 향후 캡차/토큰.

### P1-2 — /api/health 정보 노출 잠금 (완료)

- `api/_security.ts`의 `hasValidDiagnosticToken(req)`로 판정.
  `HEALTH_TOKEN`(또는 `DIAGNOSTIC_TOKEN`) env가 있고 `x-diagnostic-token` 헤더가 일치할 때만 true.
  상수시간 문자열 비교(`node:crypto` 없이 이식 가능).
- `api/health.ts`: 무인증/불일치 시 `{ status: "ok" }` 최소 응답(정보 노출 0, liveness는 유지),
  인증 시에만 런타임/키 존재/모델/엔진 상세.

## 설계만 (코드 미작성) — PG·회원가입 확정 후 진행

### P1-1 — 결제 서버 검증 (설계 단계)

현재 `src/lib/premium.ts`의 `isPremium()`은 `localStorage` 플래그만 확인 → 콘솔 한 줄로
우회 가능. PG와 회원가입 방식이 아직 확정되지 않았으므로 **지금은 코드를 만들지 않는다.**
아래 방향만 확정해 둔다.

핵심 원칙:

1. 결제 사실은 서버만 안다. 클라이언트 플래그는 UX 힌트일 뿐, 유료 결과 생성 직전 서버가 재검증.
2. 결제 검증도 `_security.ts`처럼 프레임워크 무관 유틸(`api/_entitlement.ts` 등)로 분리.
3. 저장소는 인터페이스로 추상화해 교체 가능하게(Supabase/Upstash/기타 미정).

데이터 흐름:

```
결제 요청 → PG 결제창 → PG 웹훅(서버) → 주문 상태 "paid" 기록
                                             ↓
유료 리딩 요청 → 서버가 entitlement 확인 → 통과해야 LLM 호출
```

구성요소(제안):

- `api/webhook/payment.ts`: PG 웹훅 수신, **서명 검증** 후 주문 `paid` 기록.
- `api/_entitlement.ts`: `hasEntitlement(userToken, product)` 판정 유틸(`_security.ts` 스타일).
- `EntitlementStore` 인터페이스: `getOrder(id)` / `markPaid(id)` — 구현체 교체 가능.
- 리딩 API 진입부: `checkSecurity` 다음에 `hasEntitlement` 확인, 실패 시 402/403.

우회 방지 체크리스트:

- 성공 URL 리다이렉트만으로 해제 금지. 반드시 웹훅 기반 서버 기록.
- 웹훅 서명 검증 필수(위조 결제 차단).
- 유료 결과는 생성 시점에 서버 재검증(클라 플래그 신뢰 금지).
- 주문 ID ↔ 사용자 식별자 바인딩(타인 결과 열람 차단).
- 웹훅 멱등 처리(중복 수신 대비).

PG 도입 시 결정 필요:

- PG 선택(토스페이먼츠 / 포트원 / Stripe) — 웹훅·서명 방식이 갈림.
- 사용자 식별 — 현재 로그인/계정 없음. 최소한의 주문↔기기 바인딩 또는 간이 계정 필요.
- 저장소 — Supabase 확정 시 그걸로, 아니면 Upstash Redis 재활용 가능.

## 관련 환경변수

| 변수 | 필수 | 용도 |
|---|---|---|
| `ANTHROPIC_API_KEY` | 예 | LLM 호출 (서버 전용) |
| `READING_MODEL` | 아니오 | 모델 오버라이드 |
| `ALLOWED_ORIGINS` | 아니오 | 커스텀 도메인 허용 출처 추가 |
| `UPSTASH_REDIS_REST_URL` / `_TOKEN` | 아니오 | 정밀 rate limit 승격 |
| `HEALTH_TOKEN` (또는 `DIAGNOSTIC_TOKEN`) | 아니오 | /api/health 상세 진단 접근 |
