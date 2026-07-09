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
- **지금 진행 중:** A·C 전체 완료. **B-1 완료.** 사용자 지시로 B 전체를 연속 진행 중. 다음은 B-2(상대 해부).
- **직전 세션이 한 일:** B-1 평생사주 문장 밀도 + PDF 품질 (재기획안 §11 B 성공 기준) —
  1. **코드 확인 먼저:** "평생사주 리포트"(9,900원 유료 간판)는 실제로 `DEPTH_INSTRUCTION.advanced`
     프롬프트다(systemPrompt.ts:740, `ReadingResult.tsx`가 `eyebrow="평생사주 리포트"`로 라우팅).
     "PDF"는 별도 파일 생성이 아니라 `ReadingActions.tsx`의 `window.print()`(모든 `<details>`를
     펼친 뒤 인쇄 다이얼로그)다 — `@media print` 스타일시트가 곧 "PDF 품질".
  2. `systemPrompt.ts` DEPTH_INSTRUCTION.advanced에 **문장 밀도 규칙 추가** — selfDeep/personDeep에는
     이미 있던 "누구에게나 맞는 뻔한 말 금지" 패턴이 advanced에는 없었다. 매 섹션마다 [근거 데이터]의
     구체값(오행 분포·용신/희신·강약·신살·대운 시기 등)을 최소 하나 문장 근거로 직접 연결하라는
     지시 추가(§11 "돈 낼 만한" 기준). 구성(섹션) 추가 아님 — §8 "구성 추가가 아니라 문장 밀도" 원칙 준수.
  3. `index.css` `@media print`: 이번 세션에서 새로 만든 인터랙티브 전용 블록(`.goosebump-check`
     버튼들, `.topic-deep-chips`, `.sidebar-toggle`/`.sidebar-overlay`)이 print CSS에 안 걸려
     있어 인쇄본에 클릭 못 하는 버튼이 그대로 나올 뻔한 걸 발견·수정.
  4. **한계(정직하게 기록):** API 키가 없어 문장 밀도 지시가 실제 생성물에 얼마나 반영되는지는
     못 봄(A-2·A-3와 같은 한계) — 프롬프트 텍스트 자체는 테스트로 검증.
  5. 검증: 테스트 1개 확장(기존 advanced 테스트에 밀도 지시 assertion 추가), 전체 677/677 통과
     (신규 `it` 없음, 기존 테스트 확장이라 카운트 불변), `tsc --noEmit` 클린, `npm run build` 성공.
     **+ Playwright `emulateMedia({media:"print"})`로 실제 계산된 CSS 확인** — goosebump-check/
     topic-deep-chips/sidebar-toggle 모두 `display:none`, trust-badges는 의도대로 계속 보임.
- **다음에 할 일:** B-2(상대 해부 personDeep 문장 밀도 + PDF 품질) — B-1과 같은 패턴(밀도 규칙 +
  print CSS 점검)을 PERSON_DEEP_INSTRUCTION에 적용. 그 다음 B-3(리포트 진행 화면, 시안 ③).
  별도로: API 키 있는 환경에서 A-2 토픽 심화 5종 + B-1 밀도 개선 실제 생성물 육안 검증 필요(누적).
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
- [x] B-1. 평생사주 문장 밀도 + PDF 품질. DEPTH_INSTRUCTION.advanced에 밀도 규칙 추가,
      print CSS에 새 인터랙티브 블록 숨김 처리. 프롬프트·CSS 검증 완료, 실생성 육안 검증은 API 키 필요.
- [ ] B-2. 상대 해부(personDeep) 문장 밀도 + PDF 품질
- [ ] B-3. 리포트 진행 화면 (시안 ③)

### C. 소름 루프  — 성공 기준: 무료 리딩 → 공유까지 동선 완성
- [x] C-1. 소름 엔진 (과거 대운·세운 신호 2~3개 먼저 서술, 기획안 §7).
      `goosebumpEngine.ts`+`GoosebumpCheck.tsx`, 블록 1로 마운트, 브라우저 검증 완료.
- [x] C-2. 공유 카드 (shareImage 재활용). `shareGoosebumpImage.ts` — 한지 팔레트 단일 PNG,
      실제 다운로드까지 브라우저 검증 완료.
- [x] C-3. 신뢰 배지 표면화 (분 단위 보정·4대 고전·근거 공개). `MethodologyPage.tsx`+`TrustBadges.tsx`,
      `/methodology` 라우트, 브라우저 검증 완료.
- [x] C-4. 사이드바 (프로필 전환 포함, 기획안 §5). `Sidebar.tsx`+`profileList.ts`(profile.ts는 불변),
      "설정(테마)"은 테마 기능 자체가 없어 이번 스코프 제외(정직히 기록). 브라우저 검증 완료.

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
| 2026-07-09 | Sonnet 5 | B-1: DEPTH_INSTRUCTION.advanced에 문장 밀도 규칙 추가("뻔한 말 금지+근거 직접 연결"), print CSS에 새 인터랙티브 블록(goosebump/topic-chips/sidebar) 숨김 처리, 677/677 통과, Playwright emulateMedia로 print 계산값 확인 | B-2(상대 해부) 착수, 사용자 지시로 연속 진행 중 |
| 2026-07-09 | Sonnet 5 | **C 트랙 완료.** C-4 사이드바: `Sidebar.tsx`+`profileList.ts`(기존 profile.ts 불변, 위에 다중 프로필만 추가), Layout.tsx nav 정리(보조 기능→사이드바 이전), 테스트 7개, 677/677 통과, Playwright로 빈 상태→저장→전환 전 과정 확인 | B-1(평생사주 문장 밀도) 착수, 사용자 지시로 연속 진행 중 |
| 2026-07-09 | Sonnet 5 | C-3 신뢰 배지: `MethodologyPage.tsx`(어떻게 계산하나요, 4대 고전·시간보정·근거공개 설명)+`TrustBadges.tsx`(원국 아래 마운트)+`/methodology` 라우트, 테스트 7개, 670/670 통과, Playwright로 배지·페이지 이동 확인 | C-4(사이드바) → B-1~3, 사용자 지시로 연속 진행 중 |
| 2026-07-09 | Sonnet 5 | C-2 공유 카드: `shareGoosebumpImage.ts` 신규(한지 팔레트 단일 PNG, 그라데이션 없음), shareImage.ts 유틸 export 재사용, GoosebumpCheck에 저장 버튼, Playwright로 실제 PNG 다운로드까지 확인(캔버스라 유닛테스트는 기존 컨벤션대로 없음) | C-3(신뢰 배지) → C-4 → B-1~3, 사용자 지시로 연속 진행 중 |
| 2026-07-09 | Sonnet 5 | C-1 소름 엔진: `goosebumpEngine.ts`(강한 신호만 후보, 빈 배열 허용)+`goosebumpStorage.ts`+`GoosebumpCheck.tsx`(블록 1로 마운트), saju.ts에 `computePastYearRawSignals` 추가, 테스트 22개, 663/663 통과, Playwright로 클릭→답변 전환까지 확인 | C-2(공유 카드) → C-3 → C-4 → B-1~3, 사용자 지시로 연속 진행 중 |
| 2026-07-09 | Sonnet 5 | A-2 파이프라인: analysisMode="topicDeep"+TopicDeepTopic 신규, systemPrompt에 5토픽 전용 5섹션 지시(JudgmentPack domain 필터 재사용, 새 근거 없음), fan-out 제외, 서버측 Haiku 강제, 테스트 10개, 637/637 통과. CTA 클릭 연결·실생성 검증은 미완(제품 결정/API 키 필요) | A-2 UI 연결 또는 A-3 착수 |
| 2026-07-09 | Sonnet 5 | A-1 완료: `BasicReadingSection.tsx` 장착(내 사용 설명서·올해 흐름 캘린더 신규 + InstantSummary 승격), 중복 제거, CSS 추가, 테스트 3개, 627/627 통과, Playwright로 실제 화면 렌더 확인 | A-2 토픽 AI 심화 파이프라인 착수 |
| 2026-07-09 | Sonnet 5 | A-1: `basicReadingRenderer.ts` 신규(무료 기본 리딩 블록 2~6 조립) + 테스트 6개, 전체 624/624 통과·tsc 클린·build 성공 | A-1 UI 장착 또는 A-2 착수 |
| 2026-07-09 | 초기 셋업 | 기획안·시안·레코드 파일 등록, SessionStart 강제 확인 훅 설치 | A-1 룰 렌더러 착수 |
