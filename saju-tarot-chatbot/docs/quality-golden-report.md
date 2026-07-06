# 사주 리딩 엔진 — 품질/회귀 인프라 작업 리포트

- 대상 앱: `saju-tarot-chatbot`
- 브랜치: `claude/saju-tarot-chatbot-update-p68ez1`
- 생성일: 2026-07-06
- 최종 상태: **전체 41 files / 338 tests 통과, `npm run build` 성공**

---

## 1. Quality Dashboard 검증 결과

| 확인 항목 | 결과 | 근거 |
|---|---|---|
| `/_internal/quality` 로컬 접근 | ✅ | 라우트 등록(App.tsx), dev에서 접근 허용, 렌더 테스트로 "AI Engine Health" 카드 표시 확인 |
| quality event 실제 저장 | ✅ | 실제 엔진 `computeSajuChart → buildReadingJudgmentPack`로 만든 진짜 pack을 통과시켜 저장 확인 |
| 로깅 실패 ≠ 리딩 실패 | ✅ | 3중 방어(logReading·store hook·qualityStorage 전부 throw 금지), 서버 gateReasonCodes도 try/catch |
| PII 미저장 | ✅ | 이름·생년(1988)·질문 원문·일간이 이벤트에 없음을 회귀 테스트로 고정 |
| npm test / build | ✅ | 통과 (기존 500kB chunk 경고만) |

**결론: 문제 없음.** 검증 강화 커밋 `2dd93c5`.

> 경계: rewrite/fallback 실제 발생은 LLM 출력에 의존하므로 브라우저 pack에는 확정되지 않는다. 대시보드는 서버 `gate.status`로 그 신호를 받는다.

---

## 2. Golden Test Cases 추천 구조 (구현 완료)

**핵심 원리**: `BirthInfo + referenceDate → computeSajuChart → computeLuckCycles → buildReadingJudgmentPack` 는 **LLM 없이 완전 결정론적**. golden은 이 JudgmentPack만 비교하고 LLM 문장은 고정하지 않는다.

**위치**: `src/lib/goldenCases/`

```
src/lib/goldenCases/
  goldenTypes.ts     # GoldenCase 스키마
  goldenRunner.ts    # pack 생성 + 요약 + 허용범위 검사 (순수)
  goldenCases.ts     # 21개 케이스 (실제 엔진 출력에서 도출)
  golden.test.ts     # it.each 드라이버 + 네거티브 컨트롤
  README.md          # 기대값 갱신 절차
```

**비교 기준 매핑**

| 요청 기준 | 검사 방식 |
|---|---|
| judgment codes | 필수(부분집합 ⊆) / 금지(배타) — 무해한 추가는 통과 |
| domain coverage | 핵심 도메인 필수 + 최소 개수 |
| forbiddenClaims 없음 | `validateJudgmentPack(pack).ok` (구조 결함 0) |
| confidence range | 넓은 밴드(overall 55~88, code별 예시) — 산식 급변만 감지 |
| contradiction 처리 | 알려진 집합 밖이면 실패 + 개수 상한 |
| fallback/rewrite | 구조상 rewrite 강제 없음(`structurallyValid`) — 실제 LLM 발생은 optional 단계로 분리 |
| 주요 evidence ids | 안정적 핵심 id 소수만 필수 |

---

## 3. 새 파일 / 수정 파일 목록

**신규 (Golden)**
- `src/lib/goldenCases/goldenTypes.ts`
- `src/lib/goldenCases/goldenRunner.ts`
- `src/lib/goldenCases/goldenCases.ts`
- `src/lib/goldenCases/golden.test.ts`
- `src/lib/goldenCases/README.md`

**수정 파일: 없음** — 계산 엔진(`saju.ts`)·`eventEngine`·`judgmentEngine` 무변경. golden은 순수 관찰자.

> 참고: 앞선 단계에서 만든 Quality Dashboard(`src/lib/quality/*`, `QualityDashboardPage.tsx`)와 배선(readingApi/useReadingStore/api/reading)은 이미 커밋됨.

---

## 4. 테스트 방식

- `npm test`에 포함. **네트워크·API 키 불필요**, 완전 결정론.
- `it.each(goldenCases)`로 케이스당 1 테스트, 내부 다중 assert.
- 실패 시 케이스 id + 사유(누락 code / 도메인 부족 / confidence 이탈 / 허용 밖 모순 등)를 그대로 출력.
- 기대값 갱신: 엔진을 의도적으로 바꿔 값이 달라지면 `summarizeJudgmentPack`으로 현재 요약 확인 후 `goldenCases.ts` 리뷰·갱신.

---

## 5. 회귀 감지 기준 (FAIL 조건)

- 필수 judgment code 누락 → 룰이 조용히 죽음
- forbidden-claim 구조 위반 → **안전장치 퇴보**
- 도메인 커버리지 하락
- confidence 밴드 이탈 → 산식 드리프트
- 허용 밖 contradiction 등장 / 개수 초과
- 필수 evidence id 누락 → evidence 배선 끊김

---

## 6. 위험한 과검출 / 미검출 가능성

**과검출(brittle) + 완화**
- confidence 정확값 → 넓은 밴드로 완화
- evidence id 전체 고정 → 의미상 핵심 소수만 고정
- contradiction 정확집합 → allowedSet + maxCount + 의도적 갱신

**미검출(under-detection) + 완화**
- 부분집합 검사라 "잘못된 판단 1개 추가"는 못 잡음 → 케이스별 `forbiddenJudgmentCodes` + 도메인 상한
- **LLM 문장 품질 퇴보는 이 레이어가 못 잡음** → 별도 optional LLM-sample 단계로 명시 분리
- **네거티브 컨트롤 6종**으로 "검사가 공허하지 않음"을 코드로 증명

---

## 7. 테스트 결과

| 스위트 | 결과 |
|---|---|
| Golden (`golden.test.ts`) | 31 tests 통과 (21 케이스 + 4 메타 + 6 네거티브 컨트롤) |
| Quality (`quality.test.ts`) | 27 tests 통과 (실제 엔진 PII 검증 포함) |
| **전체** | **41 files / 338 tests 통과** |
| Build | ✅ 성공 (기존 500kB chunk 경고만) |

---

## 관련 커밋 (브랜치 `claude/saju-tarot-chatbot-update-p68ez1`)

| 커밋 | 내용 |
|---|---|
| `9691e7a` | 사례 기반 검증 엔진 (Case Validation Engine P2) |
| `7fb4e92` | AI Quality Dashboard (개발자 전용 Observability Layer) |
| `2dd93c5` | Quality 로깅 실제 엔진 검증 (PII 미저장 확인) |
| `741bcf8` | Golden Test Cases (리딩 엔진 회귀 테스트 기반) |

---

## 다음 후보 (승인 시 진행)

- (a) LLM 출력 샘플 비교 optional 단계 설계 (문장 품질·실제 rewrite/fallback)
- (b) 회귀 발생 시 Quality Dashboard / Case Validation과 연계해 원인 룰 자동 표기
