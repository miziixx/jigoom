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
- **지금 진행 중:** A 전체 완료. **C 전체(C-1~C-4) 완료.** 사용자 지시로 이제 B 전체를 연속 진행 중.
  다음은 B-1(평생사주 문장 밀도)부터.
- **직전 세션이 한 일:** C-4 사이드바 (재기획안 §5, C 트랙 마지막) —
  1. `src/lib/profileList.ts` 신규 — **기존 `profile.ts`(단일 "현재 프로필")는 손대지 않고 그 위에
     이름 붙은 여러 명식 목록만 추가**(회귀 위험 최소화: `BirthInfoForm`·`useFortuneStore`·
     `TarotTodayPage`·`ComboPage`가 이미 `profile.ts`를 읽고 쓰므로). `activateProfile(id)`는
     기존 `saveProfile()`을 그대로 호출해 "현재 프로필"을 바꿔치기 — 기존 소비자는 코드 변경 없이
     전환된 명식을 이어받는다.
  2. `src/components/Sidebar.tsx` 신규 — 햄버거 토글 + 오버레이 패널. "저장된 사주 전환"(목록·현재
     사용중 표시·+지금 명식 저장) + 내 기록·이름 감정·작명·어떻게 계산하나요(C-3)·개인정보
     처리방침 링크. 프로필 전환 시 열려 있는 화면에 확실히 반영되도록 `window.location.reload()`.
  3. `Layout.tsx`: flat 9-링크 nav에서 "기록"·"이름 감정·추천"을 제거하고 사이드바로 이전, 핵심
     상품 카드 7개만 남김("홈은 상품 진열만" §5). 푸터의 임시 링크(C-3에서 넣은 것)도 제거 —
     사이드바가 정식 경로.
  4. **스코프에서 뺀 것(정직하게 기록):** §5가 언급한 "설정(테마 등)"은 넣지 않음 — 이 앱에 테마
     기능 자체가 아직 없어서, 빈 설정 페이지를 만드는 대신 없는 채로 둠(반쪽짜리 구현 금지 원칙).
  5. 검증: 테스트 7개 신규(profileList 6·Sidebar 1, 패널은 상태 기반이라 정적 렌더로는 열린
     상태를 검증 못해 브라우저로 보완), **전체 677/677 통과**, `tsc --noEmit` 클린, `npm run build`
     성공. **+ Playwright로 실제: 사이드바 빈 상태 → 사주 제출(저장 체크) → "지금 명식 저장" →
     이름 입력(prompt) → 목록에 "사용중" 배지로 뜨는 것까지 전 과정 스크린샷 확인.**
- **다음에 할 일:** B-1(평생사주 문장 밀도 + PDF 품질) 착수. 그 다음 B-2(상대 해부) → B-3(리포트
  진행 화면).
  별도로: API 키 있는 환경에서 A-2 토픽 심화 5종 실제 생성물 육안 검증 필요(누적된 항목, 아직 미해결).
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
| 2026-07-09 | Sonnet 5 | **C 트랙 완료.** C-4 사이드바: `Sidebar.tsx`+`profileList.ts`(기존 profile.ts 불변, 위에 다중 프로필만 추가), Layout.tsx nav 정리(보조 기능→사이드바 이전), 테스트 7개, 677/677 통과, Playwright로 빈 상태→저장→전환 전 과정 확인 | B-1(평생사주 문장 밀도) 착수, 사용자 지시로 연속 진행 중 |
| 2026-07-09 | Sonnet 5 | C-3 신뢰 배지: `MethodologyPage.tsx`(어떻게 계산하나요, 4대 고전·시간보정·근거공개 설명)+`TrustBadges.tsx`(원국 아래 마운트)+`/methodology` 라우트, 테스트 7개, 670/670 통과, Playwright로 배지·페이지 이동 확인 | C-4(사이드바) → B-1~3, 사용자 지시로 연속 진행 중 |
| 2026-07-09 | Sonnet 5 | C-2 공유 카드: `shareGoosebumpImage.ts` 신규(한지 팔레트 단일 PNG, 그라데이션 없음), shareImage.ts 유틸 export 재사용, GoosebumpCheck에 저장 버튼, Playwright로 실제 PNG 다운로드까지 확인(캔버스라 유닛테스트는 기존 컨벤션대로 없음) | C-3(신뢰 배지) → C-4 → B-1~3, 사용자 지시로 연속 진행 중 |
| 2026-07-09 | Sonnet 5 | C-1 소름 엔진: `goosebumpEngine.ts`(강한 신호만 후보, 빈 배열 허용)+`goosebumpStorage.ts`+`GoosebumpCheck.tsx`(블록 1로 마운트), saju.ts에 `computePastYearRawSignals` 추가, 테스트 22개, 663/663 통과, Playwright로 클릭→답변 전환까지 확인 | C-2(공유 카드) → C-3 → C-4 → B-1~3, 사용자 지시로 연속 진행 중 |
| 2026-07-09 | Sonnet 5 | A-2 파이프라인: analysisMode="topicDeep"+TopicDeepTopic 신규, systemPrompt에 5토픽 전용 5섹션 지시(JudgmentPack domain 필터 재사용, 새 근거 없음), fan-out 제외, 서버측 Haiku 강제, 테스트 10개, 637/637 통과. CTA 클릭 연결·실생성 검증은 미완(제품 결정/API 키 필요) | A-2 UI 연결 또는 A-3 착수 |
| 2026-07-09 | Sonnet 5 | A-1 완료: `BasicReadingSection.tsx` 장착(내 사용 설명서·올해 흐름 캘린더 신규 + InstantSummary 승격), 중복 제거, CSS 추가, 테스트 3개, 627/627 통과, Playwright로 실제 화면 렌더 확인 | A-2 토픽 AI 심화 파이프라인 착수 |
| 2026-07-09 | Sonnet 5 | A-1: `basicReadingRenderer.ts` 신규(무료 기본 리딩 블록 2~6 조립) + 테스트 6개, 전체 624/624 통과·tsc 클린·build 성공 | A-1 UI 장착 또는 A-2 착수 |
| 2026-07-09 | 초기 셋업 | 기획안·시안·레코드 파일 등록, SessionStart 강제 확인 훅 설치 | A-1 룰 렌더러 착수 |
