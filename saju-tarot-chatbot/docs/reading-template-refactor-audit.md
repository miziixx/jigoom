# 리딩 타입별 템플릿 분리 — 구조 감사 보고서

작성일: 2026-07-06 · 코드 수정 없음 (감사만) · 기준: main 최신 (비주얼 개선 8단계 반영 후)

목표: GPT 개선안 1순위인 "리딩 타입별 결과 템플릿 분리"가 현재 코드에서 어떻게 가능한지,
무엇을 유지하고 무엇을 분리해야 하는지, 어떤 순서로 가야 안전한지 판단한다.

---

## 1. 현재 결과 페이지 구조 요약

### 렌더러 3계열 (변경 없음)

| 계열 | 렌더러 | 라우트 | AI 출력 형태 |
|---|---|---|---|
| 통합 리딩 | `ReadingResult.tsx` | /saju /tarot /combo /flow | `# 섹션` + `[소제목]` 텍스트 (정규식 파싱) |
| 오늘 운세 | `FortuneResult.tsx` | /fortune | 구조화 JSON |
| 자체 렌더 | 페이지 내부 | /tarot-today /compatibility /naming | 룰 기반 (작명 AI 해석만 텍스트) |

### 타입 시스템 현황

- `ReadingType = "saju" | "tarot" | "combo" | "today" | "flow"` (`src/types/index.ts:1`)
- `ReadingSession.type`이 세션마다 저장됨 → **템플릿 디스패치에 필요한 키는 이미 존재**
- `ReadingResult`가 타입으로 분기하는 곳은 딱 3군데(콤보 타로 레이어, 타로 히어로, 로딩 문구) —
  나머지는 전 타입이 같은 화면 문법을 공유

### GPT가 말하는 상품 ↔ 현재 타입 매핑

| GPT 상품 | 현재 대응 | 간극 |
|---|---|---|
| 평생사주 | `saju` (질문 없음 + 종합 깊이) | 전용 타입 없음. "인생 지도" 섹션(대운별 흐름 등)은 프롬프트에 없음 |
| 올해운세 | `flow` (흐름 캘린더) | 타입은 있으나 화면이 saju와 동일 문법 |
| 고민리딩 | `saju`/`combo` + 질문 + 상담 컨텍스트 | 타입 구분 없이 question 유무로만 갈림 |
| 오늘운세 | `fortune` (이미 별도 렌더러) | 분리 완료 상태. 구독 화면 보강만 남음 |
| 타로 | `tarot` | 입력 경험은 분리돼 있고 결과만 공통 |
| 작명/궁합 | 이미 자체 렌더러 | 분리 완료 상태 |

**결론: "템플릿 분리"의 실질 대상은 `ReadingResult`가 담당하는 4개 타입(saju/tarot/combo/flow)이며,
그중에서도 saju(→평생사주형)와 flow(→올해운세형)의 분화가 핵심이다.**

---

## 2. 리딩 타입별 문제점 진단

1. **saju와 flow가 완전히 같은 화면**: flow는 `올해의 흐름` 중심으로 나와야 할 상품인데, 화면 순서는
   원국→기본 리포트→AI 섹션 순으로 saju와 동일. 12개월 차트가 섹션 중간에 묻힌다.
2. **질문(고민) 리딩과 프로필(평생) 리딩의 위계가 동일**: `question-core-card`가 위로 오는 처리만 있고,
   히어로 문구·CTA·후속질문 추천이 타입 중립적이라 "무슨 상품을 봤는지" 각인이 약하다.
3. **tarot 결과가 사주 문법을 상속**: 타로는 카드 경험이 핵심인데 결과 화면 골격(목차/섹션 카드)이
   사주 리포트와 같아 카드 → 해석의 연결이 화면 구조로 드러나지 않는다.
4. **CTA/후속 흐름이 전 타입 공통**: ChatFollowUp 유도 문구, ReadingActions 위치가 타입별 기대
   ("올해운세 → 이번 달 보기", "고민리딩 → 이어서 묻기")를 반영하지 않는다.

---

## 3. 유지해야 할 컴포넌트 (분리하면 안 되는 공통 자산)

이번 비주얼 개선으로 이미 "빌딩 블록"화가 상당히 진행됐다. 아래는 그대로 공통 유지:

| 공통 자산 | 이유 |
|---|---|
| `SajuPillarSnapshot` | 원국 항상 노출 — 사용자 이력상 절대 접지 않음 |
| `SajuFactsPanel`, `EventForecastPanel`, `PastValidationPanel` | 계산 즉시 레이어 (모든 사주계 타입 공통) |
| `viz/*` 전체 (레이더/아크/월별차트/카드아트/아이콘/모티프) | 방금 만든 공용 시각화 — 템플릿들이 재사용 |
| `lib/readingText.tsx` 파서 | 섹션/파트 파싱 규칙의 단일 원천 |
| `CalculationEvidenceZone` + `[전문가 근거 보기]` 패턴 | "쉬운 말 먼저, 근거는 접힘" 제품 원칙 |
| `ReadingActions` / `FeedbackBar` / `KeywordCloud` / `ChatFollowUp` | 내보내기·피드백·후속질문 공통 기능 |
| `useReadingStore` 스트리밍/캐시/히스토리 로직 | 화면과 무관한 데이터 흐름 |
| `LoadingNotice`, `DetailLoadingCard`, `reading-typing` 커서 | 스트리밍 UX |

## 4. 분리(추출)해야 할 것

`ReadingResult.tsx`(현재 ~560줄) 내부에서 템플릿별로 순서·강조가 달라져야 할 조각:

| 추출 대상 | 현재 위치 | 템플릿별 차이 |
|---|---|---|
| 히어로(한 줄 결론+요약 그리드) | `SummaryCardGrid` 호출부 | 문구/구성 타입별 상이 |
| 질문 핵심 카드 | `question-core-card` 블록 | 고민리딩=최상단 고정, 평생사주=없음 |
| 분야별 요약 그리드+집계 | `CategorySummaryCard`/`CategoryTally` | 평생사주=분야별 "평생 흐름", 올해운세=올해 흐름 |
| 월별 흐름 차트 존 | `MonthlyFlowOrText` | 올해운세=상단 승격, 평생사주=하단 참고 |
| 섹션 카드 목록+목차 | `bodySections.map` + `ReadingTableOfContents` | 섹션 순서/포함 여부가 템플릿 정의 |
| 오프닝/클로징 점괘 | `reading-oracle--*` | 문구 톤 타입별 |
| 타로 레이어 | `TarotSummaryHero`+`TarotFactsPanel` 블록 | 타로 템플릿=카드가 주인공(최상단) |
| CTA 슬롯 | (현재 없음) | 신규 — 템플릿별 추천 행동/다음 리딩 버튼 |

## 5. 신규 템플릿 구조 제안

```text
src/components/reading/
  ReadingResultBase.tsx      ← 공통 셸: 로딩, 스트리밍, 근거 존, 체크리스트, 레이어 구분선
  blocks/                    ← 4장의 추출 대상들 (순수 프레젠테이션)
  templates/
    LifetimeSajuTemplate.tsx   (type=saju & 질문 없음)
    ConcernReadingTemplate.tsx (type=saju|combo & 질문 있음)
    YearlyFlowTemplate.tsx     (type=flow)
    TarotTemplate.tsx          (type=tarot)
    ComboTemplate.tsx          (type=combo & 질문 없음 — Concern과 병합 가능)
  index.tsx                  ← session.type(+question 유무)로 템플릿 선택, 구버전 세션 폴백
```

- 디스패치 키: `session.type` + `session.question?.trim()` 유무. **새 ReadingType 추가 불필요** (1단계에서는).
- 각 템플릿은 "블록 나열 순서 + 히어로 문구 + 섹션 필터 + CTA 정의"만 담고 로직은 갖지 않는다.
- `HistoryPage`에서 불러온 과거 세션도 같은 디스패치를 타므로 폴백 규칙(모르면 현행 순서)이 필수.

### 템플릿별 화면 뼈대 (프롬프트 변경 없이 가능한 1차 버전)

- **평생사주**: 한 줄 총평 → 원국 → 사주의 큰 구조(기존 SajuFactsPanel 재배치) → 기질/패턴 섹션 →
  분야별 섹션 → 대운 타임라인 승격 → 삶의 전략(기존 `지금 해야 할 것` 재라벨) → CTA(올해운세/심화)
- **올해운세**: 올해 한 줄 총평 → 올해 키워드 → 대운×세운 오버랩(기존 luck-overlap 승격) →
  분야별 요약 → **12개월 차트 상단 승격** → 월별 상세 → 해야 할 것/피할 것 → CTA(이번 달/분야 심화)
- **고민리딩**: 질문 카드 최상단 → 한 줄 결론 → 근거(사주/타로) → 조심할 점 → 지금 행동 →
  이어 물을 질문 추천 → ChatFollowUp 강조
- **타로**: 뽑은 카드 전체(카드 아트) → 한 줄 답변 → 카드별 의미 → 배열 근거 → 조언 → 심화 스프레드 CTA

프롬프트의 섹션 구조(`# 제목` 화이트리스트)는 그대로 두고 **화면 배치만 바꾸는 것이 1차**.
"대운별 인생 지도" 같은 신규 섹션은 2차(프롬프트 변경, 검증 절차 필요).

## 6. 리팩터링 우선순위 (항상 빌드 가능한 커밋 단위)

1. **블록 추출** — ReadingResult 내부 조각을 `blocks/`로 옮기고 현행 순서 그대로 재조립 (동작 불변, 테스트 그린)
2. **디스패처 도입** — 모든 타입이 아직 같은 기본 템플릿을 쓰는 상태로 `templates/index` 추가
3. **YearlyFlowTemplate** — 가장 간극이 작음(12개월 차트 승격 + 히어로 문구). flow만 분화
4. **ConcernReadingTemplate** — 질문 세션 분화 + CTA/후속질문 추천
5. **LifetimeSajuTemplate** — saju 무질문 분화 (화면 재배치까지만)
6. **TarotTemplate** — 카드 중심 재배치
7. **(별도 결정) 프롬프트 확장** — 평생사주 신규 섹션, 올해운세 좋은 달/주의 달 요약 등.
   `docs/validation/reading-quality-validation.md` 절차 + 골든 테스트 갱신 필수
8. **(별도 결정) 상품/구독 노출 범위** — 가격·무료/유료 구분은 사용자 결정 사항

## 7. 위험한 변경 지점

| 위험 | 내용 | 완화 |
|---|---|---|
| 스트리밍 fan-out | saju/combo는 front/back 두 스트림이 **고정 섹션 순서**로 합쳐짐 (`readingApi.ts`). 화면 순서는 자유지만 **프롬프트 섹션 순서를 바꾸면 fan-out 결합이 깨짐** | 1차에서는 프롬프트 불변. 화면 배치만 변경 |
| 히스토리 호환 | localStorage에 저장된 과거 세션이 새 디스패처를 탄다 | 알 수 없는 조합은 현행 기본 템플릿 폴백 |
| 결과 캐시 | `resultCache`가 타입+기간 키로 캐시 — 템플릿은 렌더만 바꾸므로 안전하지만, 타입 정의를 바꾸면 캐시 키가 흔들림 | ReadingType 추가/변경 금지(1차) |
| 내보내기 | exportMarkdown/shareImage는 세션 데이터 기반이라 화면 재배치에 안전. 단, 마크다운 목차 순서는 화면과 달라질 수 있음 | 수용 or 템플릿 순서를 export에도 전달 |
| 테스트 | `ReadingResult.test.tsx` 15개가 현행 DOM 구조에 결합 | 블록 추출 단계에서 셀렉터 유지, 템플릿별 테스트 신설 |
| 후속질문 | followup은 섹션 구조가 없는 자유 텍스트 — 템플릿이 followup 메시지를 깨지 않아야 함 | ChatFollowUp 블록은 공통 셸에 유지 |
| 원국 노출 원칙 | 모든 사주계 템플릿에서 `SajuPillarSnapshot`은 접지 않고 상단 유지 | 템플릿 리뷰 체크리스트에 명시 |

## 8. 테스트해야 할 페이지/케이스

- `#/saju` 질문 없음(평생사주형) / 질문+상담 컨텍스트(고민리딩형) / depth=light
- `#/flow` (올해운세형 — 12개월 차트 승격 확인, 스트리밍 중간 상태 포함)
- `#/tarot` (스프레드 3종), `#/combo` (질문 유무)
- `#/history`에서 개편 이전 저장 세션 재열람 (폴백 템플릿)
- 후속 질문 5회 제한 흐름, 재생성(캐시 무시) 흐름
- 내보내기 3종(PDF 프린트 프리뷰 / 마크다운 / 이미지 ZIP)
- `npm test` 기존 356개 + 템플릿별 신규 테스트, `npm run build` 번들 경고 악화 여부

---

## 9. 판단 요약

- 템플릿 분리는 **가능하고, 지금 구조에서 자연스럽다** — session.type 키가 이미 있고, 이번 비주얼
  개선으로 화면 조각이 블록화돼 있어 추출 비용이 크게 줄었다.
- **1차 범위(프롬프트 불변, 화면 재배치만)**로 한정하면 위험이 낮다. 신규 섹션(대운 인생 지도 등)과
  상품/구독 구조는 별도 결정 후 2차로.
- 권장 착수 순서: flow(올해운세) → 고민리딩 → 평생사주 → 타로. flow가 가장 작고 상품 간극이 크다.
