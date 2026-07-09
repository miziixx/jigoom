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
- **지금 진행 중:** A-1·A-2·A-3 **모두 완료**. 다음은 B(간판 퀄리티) 또는 C(소름 루프) 착수 — §11에
  따라 A 끝났으니 이제 B∥C.
- **직전 세션이 한 일:** A-2 CTA 클릭 연결 + A-3(말풍선 점진 공개 UI) —
  1. **연결 방식 결정:** 클릭 시 전역 세션(store의 currentSession)을 바꾸지 않는다. 대신
     `BasicReadingSection` 내부에서 `streamReading()`을 직접 호출해 컴포넌트 로컬 상태로만
     결과를 들고 있다가 그 자리에 인라인으로 펼친다. 이유: selfDeep처럼 세션 전체를 교체하면
     지금 보고 있는 종합 리딩을 잃는다 — "깊게 보기" 버튼이 전체를 지우면 안 된다고 판단해
     더 안전한 쪽을 택함(제품 결정 필요하다고 남겼던 것을 이번에 직접 판단해 처리).
  2. `src/components/BasicReadingSection.tsx`: 연애/재물/직업/건강/올해 5개 토픽 칩 버튼 추가.
     클릭 → `streamReading({type, question:"", sajuChart, luckCycles, tarotCards(combo만),
     context:{analysisMode:"topicDeep", topic}})` 직접 호출, `onText`로 로컬 state 갱신.
     `DefaultReadingTemplate.tsx`의 마운트 호출에 `type`/`tarotCards` prop 추가로 combo도 지원.
  3. `src/components/TopicDeepChat.tsx` 신규(A-3): 누적 텍스트를 매 렌더 `parseSections`로 다시
     파싱해 도착한 섹션만큼 말풍선으로 쌓고, 5섹션 중 아직 안 온 게 있고 loading 중이면 타이핑
     인디케이터를 붙인다. 별도 스트리밍 상태 추적 없이 순수 함수로 구현(시안 ② 재현).
  4. `src/index.css`: `.topic-deep-chips`(칩 행) / `.topic-deep-chat`·`.topic-deep-msg`·
     `.topic-deep-bubble`·`.topic-deep-typing`(말풍선+타이핑 점 애니메이션) 추가 — 기존
     `--accent`/`--surface`/`--border`/`--text-dim` 변수만 사용, 새 색상·그라데이션 없음.
  5. 검증: `TopicDeepChat.test.tsx` 6개, `BasicReadingSection.test.tsx`에 3개 추가(총 9개 신규).
     **전체 스위트 646/646 통과**, `tsc --noEmit` 클린, `npm run build` 성공.
     **+ Playwright로 실제 `/saju` 폼 제출 → 5개 칩 렌더 확인 → "연애운 더 보기" 클릭 → 실제 요청이
     나가고("생성 중" → "완료") API 키 없는 이 환경에선 404가 오지만 크래시 없이 "요청 실패 (HTTP 404)"
     에러 문구가 깔끔하게 표시되는 것까지 스크린샷으로 확인.** 콘솔에 예상 밖 에러 없음.
  6. **한계(정직하게 기록, A-2 때와 동일):** `ANTHROPIC_API_KEY`가 없는 환경이라 실제 Haiku
     생성물(말풍선 안에 실제로 뭐가 써지는지)은 못 봄 — 에러 경로만 검증됨. API 키가 있는
     환경에서 실제 클릭 → 5개 섹션 생성 → 안전 규칙 준수까지 한 번 더 확인 필요
     (`docs/validation/reading-quality-validation.md` 절차).
- **다음에 할 일:** API 키 있는 환경에서 토픽 심화 5종 실제 생성물 육안 검증(위 6번) 먼저 권장.
  그 다음은 B(평생사주·상대해부 문장 밀도) 또는 C(소름 엔진) 중 택1 — §11은 "A → (B ∥ C)"라
  순서만 정해두고 B/C 사이 우선순위는 안 정함, 다음 세션이 사용자에게 물어볼 것.
- **설계 결정 (다음 세션 참고):** 기획안 §3 문구는 "JudgmentPack → 한국어 렌더"이지만, 실제
  `JudgmentPack.judgments`를 소비하는 렌더러 대신 **기존 5개 엔진을 그대로 재사용**하는 쪽을
  선택함(A-1). 근거: 이 5개 엔진은 이미 `SajuChart`/`LuckCycles`의 계산값에서 판단을 도출하므로
  §3의 실제 기준("판단의 템플릿 렌더 = OK")을 충족하고, §8 각주("6개는 기존 자산 재배치")와도
  일치. `JudgmentPack`은 AI 프롬프트 근거 주입용으로 쓰임 — A-2는 여기서 한 걸음 더 나가 그
  JudgmentPack을 topicDeep의 유일한 근거로 재사용함(도메인 필터만 얹음, 새 근거 계산 없음).
  토픽 심화 결과는 전역 세션을 바꾸지 않고 컴포넌트 로컬 상태로만 관리한다(위 1번) — 이후
  "내 기록"에 저장하고 싶어지면 이 결정을 재검토해야 함(지금은 저장 안 됨, saveToHistory 없음).
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
- [x] A-2. 토픽 AI 심화 파이프라인: topic 템플릿 + Haiku (연애/재물/직업/건강/올해).
      파이프라인 + CTA 클릭 연결(인라인, 세션 비파괴) 완료. 실생성 육안 검증만 API 키 있는 환경에서 별도 필요.
- [x] A-3. 말풍선 점진 공개 / 도착 순 UI (시안 ②). `TopicDeepChat.tsx` — 토픽 심화 결과 전용.

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
| 2026-07-09 | Sonnet 5 | A-2 CTA 연결(세션 비파괴, 인라인 streamReading) + A-3 `TopicDeepChat.tsx`(말풍선 점진 공개) + 칩 5개, CSS 추가, 테스트 9개, 646/646 통과, Playwright로 클릭→요청→에러 처리까지 확인(API 키 없어 생성물 자체는 미검증) | 실생성 육안 검증(API 키 필요) 후 B 또는 C 착수 |
| 2026-07-09 | Sonnet 5 | A-2 파이프라인: analysisMode="topicDeep"+TopicDeepTopic 신규, systemPrompt에 5토픽 전용 5섹션 지시(JudgmentPack domain 필터 재사용, 새 근거 없음), fan-out 제외, 서버측 Haiku 강제, 테스트 10개, 637/637 통과. CTA 클릭 연결·실생성 검증은 미완(제품 결정/API 키 필요) | A-2 UI 연결 또는 A-3 착수 |
| 2026-07-09 | Sonnet 5 | A-1 완료: `BasicReadingSection.tsx` 장착(내 사용 설명서·올해 흐름 캘린더 신규 + InstantSummary 승격), 중복 제거, CSS 추가, 테스트 3개, 627/627 통과, Playwright로 실제 화면 렌더 확인 | A-2 토픽 AI 심화 파이프라인 착수 |
| 2026-07-09 | Sonnet 5 | A-1: `basicReadingRenderer.ts` 신규(무료 기본 리딩 블록 2~6 조립) + 테스트 6개, 전체 624/624 통과·tsc 클린·build 성공 | A-1 UI 장착 또는 A-2 착수 |
| 2026-07-09 | 초기 셋업 | 기획안·시안·레코드 파일 등록, SessionStart 강제 확인 훅 설치 | A-1 룰 렌더러 착수 |
