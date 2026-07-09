# 인사이트 오라클 재기획 — 작업 레코드 (강제 확인/기록 파일)

> **이 파일은 세션마다 자동으로 열립니다.** (루트 `.claude/settings.json` 의 SessionStart 훅)
> 계정이 달라도 이 파일을 통해 이전 작업을 이어받습니다.
> **규칙:** 작업 시작 전 아래 "현재 상태"를 읽고 → 작업 후 반드시 "세션 로그"에 한 줄 추가하고 커밋/푸시.

## 📌 기준 문서 (작업 전 필독)
- 기획안: [`docs/redesign-2026-07.md`](./redesign-2026-07.md)
- 화면 시안(4화면): [`docs/mockups/redesign-mockup.html`](./mockups/redesign-mockup.html)
- 전체 작업 이력(대용량): [`docs/record.md`](./record.md)
- 불변식은 기획안 §12 및 루트 `CLAUDE.md` 참조 — **재기획으로 계산 엔진/검증 게이트 변경 금지.**

---

## 🎯 현재 상태 (Current State)

- **작업 단계:** A → (B ∥ C)  *(기획안 §11)*
- **지금 진행 중:** A-2 **파이프라인 완료, CTA 클릭 연결 미완**. 다음은 A-2 UI 연결(제품 결정 필요,
  아래 참고) 또는 A-3 착수.
- **직전 세션이 한 일:** A-2 토픽 AI 심화 파이프라인 —
  1. `types/index.ts`: `AnalysisMode`에 `"topicDeep"` 추가, `TopicDeepTopic`("love"|"money"|"career"|
     "health"|"year", JudgmentPack의 domain과 1:1 대응) 신규, `ReadingContext.topic` 추가.
     `basicReadingRenderer.ts`의 `BasicReadingTopic`은 이제 이 타입의 별칭(A-1과 A-2가 같은 토픽 키 공유).
  2. `systemPrompt.ts`: `buildTopicDeepInstruction(topic)` 신규 — selfDeep/personDeep과 같은 패턴으로
     표준 섹션을 5섹션(한 줄 결론/지금 흐름/조심할 것/시기/행동, 1000~2500자)으로 교체. **새 판단
     엔진을 만들지 않음** — 이미 주입돼 있는 JudgmentPack에서 `domain === topic`인 judgments만
     쓰라고 지시할 뿐(판단은 룰 엔진이 이미 계산 완료, AI는 문장화만 — 기획안 §3 원칙 그대로).
     속마음 통합 블록(nowMind/psych/axes/deliberation)은 5섹션 구조와 안 맞아 topicDeep에서 제외.
  3. `readingApi.ts`의 `shouldFanOut()`에 `topicDeep` 추가 — selfDeep/personDeep처럼 fan-out 없이
     통짜 스트림(짧아서 병렬화 불필요).
  4. `api/reading.ts`: `context.analysisMode === "topicDeep"`이면 **서버에서 강제로 Haiku**로
     모델을 override(클라이언트가 보낸 `body.model`을 신뢰하지 않음 — 원가 통제).
  5. 검증: `reading.test.ts`에 9개, `readingApi.test.ts`에 1개 신규(총 10개) — 5개 토픽 각각 올바른
     섹션 구조·domain 필터·분량 지시 확인, topic 없이 topicDeep만 있으면 안전하게 표준으로 폴백,
     타로 타입엔 안 붙음, 속마음 블록 제외, fan-out 안 탐. **전체 스위트 637/637 통과**, `tsc --noEmit`
     클린, `npm run build` 성공.
  6. **한계(정직하게 기록):** 이 환경엔 `ANTHROPIC_API_KEY`가 없어 실제 Haiku 호출로 생성물을
     눈으로 확인하지 못함. `docs/validation/reading-quality-validation.md` 절차(실제 생성 결과
     육안 검증)는 **API 키가 있는 환경에서 별도로 한 번 더 수행 필요** — 결정론적 프롬프트 조립
     (구조·안전 규칙·domain 필터 문구)만 테스트로 검증됨.
  7. **UI 연결 미완(의도적 스코프 경계):** A-1의 `BasicReadingSection`에 있는 `deepDiveCta` 버튼은
     여전히 클릭 불가능한 정적 라벨이다. 실제로 연결하려면 "클릭 시 지금 보고 있는 전체 리딩을
     짧은 토픽 리딩으로 교체할지, 별도 화면/모달로 뺄지" 제품 결정이 필요함(기존 앱은 "자기
     완전분석" 체크박스 → 같은 세션 교체 패턴을 이미 씀 — 참고할 선례는 있음). 기획안 §11도
     "카드 홈 전면 개편·가격 노출은 A~C 뒤"라고 명시해, 이 폴리시는 뒤로 미뤄도 되는 스코프로 판단.
- **다음에 할 일:** A-2 CTA 클릭 연결(위 6번 결정 필요) 또는 A-3(말풍선 점진 공개 UI) 착수.
  API 키가 생기면 `docs/validation/reading-quality-validation.md` 체크리스트로 5개 토픽 실제
  생성물 육안 검증도 해야 함.
- **설계 결정 (다음 세션 참고):** 기획안 §3 문구는 "JudgmentPack → 한국어 렌더"이지만, 실제
  `JudgmentPack.judgments`를 소비하는 렌더러 대신 **기존 5개 엔진을 그대로 재사용**하는 쪽을
  선택함(A-1). 근거: 이 5개 엔진은 이미 `SajuChart`/`LuckCycles`의 계산값에서 판단을 도출하므로
  §3의 실제 기준("판단의 템플릿 렌더 = OK")을 충족하고, §8 각주("6개는 기존 자산 재배치")와도
  일치. `JudgmentPack`은 AI 프롬프트 근거 주입용으로 쓰임 — A-2는 여기서 한 걸음 더 나가 그
  JudgmentPack을 topicDeep의 유일한 근거로 재사용함(도메인 필터만 얹음, 새 근거 계산 없음).
- **막힌 것/결정 대기:** 없음.
- **결정 완료(다시 묻지 말 것):** main의 일부 커밋이 GitHub에서 "Unverified"로 표시되는 건
  (SSH 서명 미설정, 내용엔 문제 없음) 사용자가 **"그냥 둬"로 확정**함(2026-07-09). 이 저장소
  stop-hook이 세션마다 서명 경고를 다시 띄우더라도, 이미 사용자가 명시적으로 결정한 사안이니
  **다음 세션은 이걸 다시 사용자에게 묻지 말고 조용히 무시할 것.** amend+force-push 등 main
  히스토리 재작성은 하지 않는다.

> 세션을 마칠 때 위 5줄을 **최신 상태로 덮어쓰고**, 아래 세션 로그에 이력 한 줄을 append 하세요.

---

## ✅ 실행 체크리스트 (기획안 §11)

### A. 속도  — 성공 기준: 기본 3초 / 토픽 30초
- [x] A-1. P0 룰 렌더러: 기존 5개 엔진 → 한국어 "기본 리딩" 조립 (무료 7블록, 기획안 §8).
      `src/lib/basicReadingRenderer.ts` + `src/components/BasicReadingSection.tsx`, 브라우저 검증 완료.
- [~] A-2. 토픽 AI 심화 파이프라인: topic 템플릿 + Haiku (연애/재물/직업/건강/올해).
      **파이프라인 완료**(types·systemPrompt·fan-out 제외·서버 Haiku 강제 + 테스트 10개),
      **CTA 클릭 연결·실생성 육안 검증 미완**(제품 결정/API 키 필요, 위 "다음에 할 일" 참고).
- [ ] A-3. 말풍선 점진 공개 / 도착 순 UI (시안 ②)

### B. 간판 퀄리티  — 성공 기준: "돈 낼 만한" 육안 검증
- [ ] B-1. 평생사주 문장 밀도 + PDF 품질
- [ ] B-2. 상대 해부(personDeep) 문장 밀도 + PDF 품질
- [ ] B-3. 리포트 진행 화면 (시안 ③)

### C. 소름 루프  — 성공 기준: 무료 리딩 → 공유까지 동선 완성
- [ ] C-1. 소름 엔진 (과거 대운·세운 신호 2~3개 먼저 서술, 기획안 §7)
- [ ] C-2. 공유 카드 (shareImage 재활용)
- [ ] C-3. 신뢰 배지 표면화 (분 단위 보정·4대 고전·근거 공개)
- [ ] C-4. 사이드바 (프로필 전환 포함, 기획안 §5)

> A~C 뒤: 토픽 5종 템플릿 확장 · 카드 홈 전면 개편 · 가격 노출.

---

## 🚫 불변식 (건드리면 안 되는 것 — 기획안 §12)
- 계산 엔진(`saju.ts`·eventEngine)·궁합 점수·검증 게이트 로직은 변경 금지.
- Evidence Gate: 스트리밍 1차 + 실패 시에만 재생성 (버퍼링 복귀 금지).
- 쉬운 말 우선 + 전문가 근거 접힘 보존 / 공포·단정·의료·법률·투자 결론 금지.
- 원국 스냅샷 즉시 노출 유지 (재접힘 금지).
- 색감: 한지 팔레트 유지, 그라데이션 금지.
- 프롬프트·섹션 구조 변경 시 `docs/validation/reading-quality-validation.md` 절차 준수.

---

## 🗒️ 세션 로그 (최신이 위로 — 매 세션 한 줄 이상 필수)

| 날짜 | 작업자(계정/모델) | 한 일 | 다음 할 일 |
|---|---|---|---|
| 2026-07-09 | Sonnet 5 | A-2 파이프라인: analysisMode="topicDeep"+TopicDeepTopic 신규, systemPrompt에 5토픽 전용 5섹션 지시(JudgmentPack domain 필터 재사용, 새 근거 없음), fan-out 제외, 서버측 Haiku 강제, 테스트 10개, 637/637 통과. CTA 클릭 연결·실생성 검증은 미완(제품 결정/API 키 필요) | A-2 UI 연결 또는 A-3 착수 |
| 2026-07-09 | Sonnet 5 | A-1 완료: `BasicReadingSection.tsx` 장착(내 사용 설명서·올해 흐름 캘린더 신규 + InstantSummary 승격), 중복 제거, CSS 추가, 테스트 3개, 627/627 통과, Playwright로 실제 화면 렌더 확인 | A-2 토픽 AI 심화 파이프라인 착수 |
| 2026-07-09 | Sonnet 5 | A-1: `basicReadingRenderer.ts` 신규(무료 기본 리딩 블록 2~6 조립) + 테스트 6개, 전체 624/624 통과·tsc 클린·build 성공 | A-1 UI 장착 또는 A-2 착수 |
| 2026-07-09 | 초기 셋업 | 기획안·시안·레코드 파일 등록, SessionStart 강제 확인 훅 설치 | A-1 룰 렌더러 착수 |
