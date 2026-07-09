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
- **지금 진행 중:** A-1 **완료** (모듈+UI 장착+브라우저 검증까지). 다음은 A-2 착수.
- **직전 세션이 한 일:** A-1 UI 장착 —
  1. `src/components/BasicReadingSection.tsx` 신규: 블록 3(내 사용 설명서)·블록 5(올해 흐름
     미니 캘린더)를 새로 그리고, 블록 2(원국 스냅샷)는 기존 `InstantSummary`를 승격해 재사용.
     `DefaultReadingTemplate.tsx`의 `EventForecastPanel` 바로 다음에 마운트해 AI 텍스트 스트리밍
     전/도중에도 항상 보이게 함(로딩과 무관).
  2. 중복 제거: `readingBlocks.tsx`의 `CalculationEvidenceZone`(접힌 "계산 근거" 아코디언)에서
     `InstantSummary` 렌더를 삭제(이제 상단에서 이미 펼쳐 보여줌) — 미사용 `loading` prop도
     `CalculationEvidenceZone` 시그니처와 두 호출부(`DefaultReadingTemplate`·`YearlyFlowTemplate`)
     에서 함께 정리.
  3. 블록 4(분야별 신호)·블록 6(생활 처방)은 이미 `EventForecastPanel`·`SajuFactsPanel`이 상단에서
     보여주고 있어 새 섹션에서 다시 그리지 않음(중복 방지). `YearlyFlowTemplate`(올해운세 전용)은
     자체 12개월 차트가 이미 있어 이 섹션을 마운트하지 않음 — 의도적 스코프 제외.
  4. `src/index.css`에 `.basic-reading-block`/`.basic-reading-month*` 클래스 추가 — 기존
     `--accent`/`--border`/`--surface-alt` 등 기존 변수만 사용, 새 색상·그라데이션 없음(불변식 준수).
  5. 검증: 컴포넌트 테스트 3개 신규(`BasicReadingSection.test.tsx`), 전체 스위트 **627/627 통과**,
     `tsc --noEmit` 클린, `npm run build` 성공. **+ Playwright로 실제 `/saju` 폼 제출 → 결과 화면에서
     세 블록(바로 보는 요약/내 사용 설명서/올해 흐름 미니 캘린더)이 실제 렌더되는 것을 스크린샷으로 확인.**
     한지 팔레트와 시각적으로 일치, 사주 전문용어 표면 노출 없음.
- **다음에 할 일:** A-2 착수 — 토픽 AI 심화 파이프라인 (topic 템플릿 + Haiku, 연애/재물/직업/건강/올해).
- **설계 결정 (다음 세션 참고):** 기획안 §3 문구는 "JudgmentPack → 한국어 렌더"이지만, 실제
  `JudgmentPack.judgments`를 소비하는 렌더러 대신 **기존 5개 엔진을 그대로 재사용**하는 쪽을
  선택함. 근거: 이 5개 엔진은 이미 `SajuChart`/`LuckCycles`의 계산값에서 판단을 도출하므로
  §3의 실제 기준("판단의 템플릿 렌더 = OK")을 충족하고, §8 각주("6개는 기존 자산 재배치")와도
  일치. `JudgmentPack`은 계속 AI 프롬프트 근거 주입용으로만 쓰임 — 재설계 필요시 이 결정을
  재검토할 것.
- **막힌 것/결정 대기:** `main`에 올라간 커밋 하나가 GitHub에서 "Unverified"로 표시됨(SSH 서명 미설정,
  내용엔 문제 없음). amend+force-push로 고칠 수 있지만 이미 푸시된 main 히스토리를 재작성하는
  파괴적 작업이라 사용자 확인 대기 중 — 아직 답 없음. 다음 세션도 이 결정을 사용자에게 다시 강요하지
  말고, 필요하면 한 번만 상기시키고 넘어갈 것.

> 세션을 마칠 때 위 5줄을 **최신 상태로 덮어쓰고**, 아래 세션 로그에 이력 한 줄을 append 하세요.

---

## ✅ 실행 체크리스트 (기획안 §11)

### A. 속도  — 성공 기준: 기본 3초 / 토픽 30초
- [x] A-1. P0 룰 렌더러: 기존 5개 엔진 → 한국어 "기본 리딩" 조립 (무료 7블록, 기획안 §8).
      `src/lib/basicReadingRenderer.ts` + `src/components/BasicReadingSection.tsx`, 브라우저 검증 완료.
- [ ] A-2. 토픽 AI 심화 파이프라인: topic 템플릿 + Haiku (연애/재물/직업/건강/올해)
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
| 2026-07-09 | Sonnet 5 | A-1 완료: `BasicReadingSection.tsx` 장착(내 사용 설명서·올해 흐름 캘린더 신규 + InstantSummary 승격), 중복 제거, CSS 추가, 테스트 3개, 627/627 통과, Playwright로 실제 화면 렌더 확인 | A-2 토픽 AI 심화 파이프라인 착수 |
| 2026-07-09 | Sonnet 5 | A-1: `basicReadingRenderer.ts` 신규(무료 기본 리딩 블록 2~6 조립) + 테스트 6개, 전체 624/624 통과·tsc 클린·build 성공 | A-1 UI 장착 또는 A-2 착수 |
| 2026-07-09 | 초기 셋업 | 기획안·시안·레코드 파일 등록, SessionStart 강제 확인 훅 설치 | A-1 룰 렌더러 착수 |
