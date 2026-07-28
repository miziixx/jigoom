# Phase 2 — 상대 완전분석 구체 실행 플랜

> 대상: `saju-tarot-chatbot`. 기준: `main`(HEAD `16a504d`, Phase 1 selfDeep + 궁합 정확도 반영 완료).
> 원 계획서(`persondeepanalysisplan.md`) 4장을 **실제 코드에 맞춰** 구체화한 착수용 문서.
> 확정 결정: 진입 UI = 궁합 페이지 토글 · 타로 오버레이 = v1 스캐폴딩만(노출 후속).

---

## 0. 전제로 깔린 아키텍처 사실 (원 계획서엔 없던 것)

| 사실 | 근거 | 영향 |
|---|---|---|
| 궁합은 `ReadingType`이 아님 (`saju\|tarot\|combo\|today\|flow`) | `types/index.ts:1` | 상대 완전분석은 궁합이 아니라 **saju 리딩 + `analysisMode:"personDeep"`** 으로 얹어야 selfDeep과 같은 AI 서술을 얻음 |
| 궁합은 AI 파이프라인 안 탐 — `computeCompatibility` 직접 호출 후 결정론 렌더 | `CompatibilityPage.tsx` (generate 호출 없음) | 궁합 UI에 "완전분석 토글"을 달되, 그 경로는 기존 궁합과 달리 **AI 리딩을 새로 태우는** 별도 흐름 |
| 리딩 파이프라인은 **단일 주체**(birthInfo 1개 → chart 1개) | `useReadingStore.ts:128` | 상대(B)를 주체로 태우고, 나(A)는 **부가 근거**로 넣음(§3) |
| `roleChemistry`(`saju.ts:2500`)·`compatibilityRepairReport`(`saju.ts:2742`) **export 안 됨** | grep | 선행: export화 |
| `buildPsychLayer/CapacityAxes/NowMind/Deliberation` 전부 단일 chart·export됨 | `psychLayer.ts:188` 등 | 상대 원국(chartB)에 **그대로 적용 가능** — 상대 작동방식의 재료 |
| Phase 1 selfDeep 패턴이 이미 존재 | `selfDeep.ts`, `SELF_DEEP_INSTRUCTION`(`systemPrompt.ts:747`), 주입부(`:1094`) | Phase 2는 이 구조의 **상대판 대칭 복제** |

## 1. 설계 원칙 — 분류기 함정 회피 (명문화)

> **상대 작동방식 taxonomy(좋아할 때/불안할 때/거절/질투/미련·식을 때)는 새 분류기 엔진이 아니다.**
> Phase 1의 `deriveShadow`가 그랬듯, 이미 계산된 `buildPsychLayer(chartB)`·`buildCapacityAxes(chartB)`·
> `roleChemistry(A,B)` 신호를 **규칙으로 파생**한다. 새 결정론 계산 0개. 새 파일은 `personDeep.ts` 하나
> (= `selfDeep.ts`의 상대판). 결정론 점수 로직(saju/궁합)은 불변.

안전 레일 전면 유지: 무단정·무공포·무진단명·사주 용어 표면 노출 금지, 근거는 전문가 근거 보기에만.

## 2. 파일별 작업 (selfDeep 대칭 구조)

| # | 파일 | 작업 | selfDeep 대응 |
|---|---|---|---|
| 2-1 | `src/lib/saju.ts` | `roleChemistry`·`compatibilityRepairReport`에 `export` 추가 (로직 불변) | — (선행 전제) |
| 2-2 | `src/types/index.ts` | `AnalysisMode += "personDeep"`, `PartnerBehaviorCheck` 타입, `ReadingContext.partnerCheck?`·`counterpart?` | `SelfBehaviorCheck` |
| 2-3 | `src/lib/personDeep.ts` **(신규)** | `computePersonProfile(chartB, chartA, relationType)` → taxonomy(좋아할때/불안할때/거절/질투/미련·식을때, 끌리는지점/부담지점, **말·행동 불일치**) 규칙 파생 · `deriveShadow(chartB)` 재사용 · `buildConfidenceTiers` 상대 확장(출생시간+행동데이터 유무) · `buildPersonDeepEvidence(...)` 직렬화(+타로 주입 자리) | `selfDeep.ts` 통째 |
| 2-4 | `src/prompts/systemPrompt.ts` | `PERSON_DEEP_INSTRUCTION`(16항목) · `analysisMode==="personDeep"` 분기 · `buildPersonDeepEvidence` 주입 · `formatPartnerCheck` | `SELF_DEEP_INSTRUCTION`(747), 주입부(1094) |
| 2-5 | `src/lib/readingApi.ts` | personDeep도 fan-out 제외(통짜 생성) | `shouldFanOut` selfDeep 처리 |
| 2-6 | `src/pages/CompatibilityPage.tsx` | **완전분석 토글**(프리미엄 게이팅) + **상대 행동체크 입력** + 토글 ON → `startReading({type:"saju", birthInfo:상대, context:{analysisMode:"personDeep", counterpart:<A근거>, partnerCheck}})` | `ContextPicker.tsx` 토글+행동체크 |
| 2-7 | `src/components/PersonDeepTeaser.tsx` **(신규)** | 무료 미리보기(끌리는 지점 한 줄 + 신뢰도 요약) | `SelfDeepTeaser.tsx` |
| 2-8 | `src/lib/premium.ts` | `PREMIUM_FEATURES += "상대 완전분석"` | 이미 `"자기 완전분석"` |
| 2-9 | `src/index.css` | 토글·행동체크·미리보기 스타일 | selfDeep 스타일 재사용 |
| 2-10 | (v1 스캐폴딩) `tarot.ts` | `drawSpread` 재사용 자리만; 실제 카드 UI는 후속 | 신규 계산 없음 |

## 3. "나(A)"를 파이프라인에 넣는 방법 — P2 채택

리딩은 단일 주체라 상대(B)를 주체로 태우면 A가 안 들어감.

- **P2(채택): 클라이언트 조립.** `CompatibilityPage`가 이미 A·B를 가짐 → 거기서
  `computePersonProfile(chartA, chartB, …)`를 계산·직렬화해 `context.counterpart`(pre-built 근거 문자열)로
  넘기고, `systemPrompt`는 그 블록을 **주입만**. 궁합의 "클라이언트가 계산" 구조와 정합, 파이프라인 수술 최소.
- P1(대안, 미채택): facts에 `counterpartBirth` 추가해 서버에서 `roleChemistry` 계산. selfDeep과 더 대칭이나
  facts 플러밍 추가 필요.

## 4. 출력 구조 — `PERSON_DEEP_INSTRUCTION` (16항목)

원 계획서 4-3의 "그 사람 완전 분석" 16항목을 `# 제목` 16개로 고정. 핵심 차별 섹션:
**말과 행동 불일치**, **끌리는 지점 vs 부담 지점**, **식을 때/미련의 행동**.
규칙: 궁합 점수 언급 금지, 상대 행동체크 입력과 대조해 서술, 진단명·사주용어·공포·단정 금지
(selfDeep 규칙 그대로). 무료 미리보기 vs 유료 전체 차이 분명히.

## 5. 실행 순서 & 검증

1. 2-1 export → 2-2 types
2. 2-3 `personDeep.ts` + 유닛/골든 테스트 (taxonomy 결정론 스냅샷, **비대칭 주의**: A→B ≠ B→A)
3. 2-4 프롬프트 → 2-5 fan-out 제외 → 임시 스크립트로 16블록 순서·중복 없음 확인
4. 2-6~2-9 UI → 2-10 타로 스캐폴딩
5. 게이트마다: `npx tsc -b` · `npm test`(606 유지 + 신규) · `npm run build`
6. 스테이징(sajutarot-one.vercel.app, API 키 필요) 실사용: 16블록 나오는지, 상대 작동방식이 "이 사람만"인지,
   행동체크가 해석에 반영되는지, 무료 티저 vs 유료 차이

## 6. 범위 밖 (유지)
- 육효/주역, 결정론 점수 로직 변경, 실결제 연동(별건).
- 타로 오버레이 실제 노출은 v1 밖(스캐폴딩만).
