# 인사이트 오라클 재기획 — 작업 레코드 (강제 확인/기록 파일)

> **이 파일은 세션마다 자동으로 열립니다.** (루트 `.claude/settings.json` 의 SessionStart 훅)
> 계정이 달라도 이 파일을 통해 이전 작업을 이어받습니다.
> **규칙:** 작업 시작 전 아래 "현재 상태"를 읽고 → 작업 후 반드시 "세션 로그"에 한 줄 추가하고 커밋/푸시.

## 📌 기준 문서 (작업 전 필독)
- 기획안: [`docs/redesign-2026-07.md`](./redesign-2026-07.md)
- 화면 시안(4화면): [`docs/mockups/redesign-mockup.html`](./mockups/redesign-mockup.html)
- **엔진 업그레이드 기획안(2026-07-10 신규 트랙): [`docs/engine-upgrade-2026-07.md`](./engine-upgrade-2026-07.md)**
- 전체 작업 이력(대용량): [`docs/record.md`](./record.md)
- 불변식은 기획안 §12 및 루트 `CLAUDE.md` 참조. **주의: "계산 엔진 변경 금지"는 재기획(UI/제품) 작업에만
  계속 적용되고, 엔진 업그레이드 트랙에서는 사용자가 명시적으로 해제함**(2026-07-10) — 대신 ADDITIVE ONLY
  (잠금 테스트 그린 유지, 새 optional 필드만) 원칙을 따른다. 상세는 엔진 업그레이드 기획안 §2.

---

## 🎯 현재 상태 (Current State)

- **작업 단계:** 재기획(A·B·C + A~C 뒤)은 가격 노출만 남기고 완결. **2026-07-10부터 새 트랙 "엔진
  업그레이드"(사주·자미두수·궁합·타로·점성술 정확도/지식 심화) 진행 중** — 기획안
  [`engine-upgrade-2026-07.md`](./engine-upgrade-2026-07.md), 체크리스트는 아래 "🔮 엔진 업그레이드 트랙".
  사용자가 "계산 엔진 변경 금지"를 이 트랙에 한해 해제(ADDITIVE ONLY로 진행). (참고: main에서 사주 폼·
  리딩 결과 카드의 "박스 안에 박스" 중첩 CSS 완화가 별도로 완료됨 — 커밋 `5515c69`, 이 병합에 포함.)
- **지금 진행 중:** 엔진 업그레이드 트랙 — **신규 구현 항목 전부 완료.** E-0·S-1·S-2a·S-2b·S-3·S-4·S-5·
  Z-1·Z-2·Z-3·Z-4·C-1·C-2·V-1·V-2·T-1·T-2·A-1·T-3a·T-3b (커밋 다수, 782/782 그린, 전부 main 병합·푸시).
  **남은 것은 잠금 예외 2개(C-3 궁합 점수 캘리브레이션·V-3 rule weight 캘리브레이션)뿐 — 둘 다 "실사용
  피드백 후" 착수 조건이라 지금은 보류.** 그 외 누적된 건 아래 실생성(LLM) 육안 검증(API 키 필요)뿐.
  작업 브랜치 `claude/fortune-reading-engine-upgrade-ik50ji` = main = ht4pat 동일 지점.
- **직전 세션이 한 일:** …·A-1·T-3a·T-3b. T-3a/b: 타로 마이너 56장 개별 심화 `src/data/tarotMinorDepth.ts`
  (MINOR_DEPTH: 카드 id→{scene·shadow·advice}, 완드·컵 28 + 소드·펜타클 28 = 56장, 웨이트 통설·참고용) +
  `describeMinorDepth`, `formatTarotCards` 프롬프트·TarotFactsPanel UI 배선. 56장 전수 완결성 audit + 검수 덤프
  `docs/validation/tarot-minor-depth-table.md`. A-1은 점성술 Phase A(품위 인라인·KB 교차검증·덤프). 점수·계산 불변.
- **다음에 할 일:** 엔진 업그레이드 신규 항목 없음. 남은 **C-3·V-3은 실사용 피드백을 받은 뒤** 착수(잠금 예외라
  전후 분포·매치율 기록 필수). 그 전까지 우선순위: **누적 실생성 육안 검증**(A-2 토픽 심화·B-1/B-2 밀도·엔진
  업그레이드 각 항목의 실제 Haiku/Sonnet 생성물)을 `ANTHROPIC_API_KEY` 있는 환경에서
  `docs/validation/reading-quality-validation.md` 절차로 확인. 재기획(§11) 가격 노출은 **스코프 제외**.
  **누적 미해결(API 키 필요):** A-2 토픽 심화 5종·B-1 평생사주 밀도·B-2 상대 해부 밀도·이번 세션의
  후속 질문 채팅 — 전부 프롬프트 텍스트/파이프라인은 테스트로 검증됐지만, 실제 Haiku/Sonnet 생성물을
  육안으로 본 적은 없다(`ANTHROPIC_API_KEY`가 이 환경에 없음). API 키 있는 환경에서
  `docs/validation/reading-quality-validation.md` 절차로 한 번 더 확인 필요.
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
- [x] B-2. 상대 해부(personDeep) 문장 밀도 + PDF 품질. 밀도 규칙을 16섹션 전부로 확장(기존엔 3개만
      적용), print CSS는 B-1에서 이미 해결됨을 확인. 프롬프트 검증 완료, 실생성 육안 검증은 API 키 필요.
- [x] B-3. 리포트 진행 화면 (시안 ③). `ReportProgress.tsx` + `readingProgress.ts`의 depth 버그 수정
      (advanced에서 total 3개 누락되던 것). 브라우저 검증 완료(API 지연시켜 로딩 화면 확보).

### C. 소름 루프  — 성공 기준: 무료 리딩 → 공유까지 동선 완성
- [x] C-1. 소름 엔진 (과거 대운·세운 신호 2~3개 먼저 서술, 기획안 §7).
      `goosebumpEngine.ts`+`GoosebumpCheck.tsx`, 블록 1로 마운트, 브라우저 검증 완료.
- [x] C-2. 공유 카드 (shareImage 재활용). `shareGoosebumpImage.ts` — 한지 팔레트 단일 PNG,
      실제 다운로드까지 브라우저 검증 완료.
- [x] C-3. 신뢰 배지 표면화 (분 단위 보정·4대 고전·근거 공개). `MethodologyPage.tsx`+`TrustBadges.tsx`,
      `/methodology` 라우트, 브라우저 검증 완료.
- [x] C-4. 사이드바 (프로필 전환 포함, 기획안 §5). `Sidebar.tsx`+`profileList.ts`(profile.ts는 불변),
      "설정(테마)"은 테마 기능 자체가 없어 이번 스코프 제외(정직히 기록). 브라우저 검증 완료.

### A~C 뒤
- [x] 토픽 5종 템플릿 확장 — 후속 질문 채팅. `TopicDeepChat.tsx` 재작성(초기 5섹션 + 후속 최대 5회,
      전역 세션 비파괴 컴포넌트 로컬 상태), 토픽별 추천 칩 + 자유 입력. 브라우저 검증 완료.
- [x] 카드 홈 전면 개편 (시안 ①). `dailyGreeting.ts`(일진·절기 계산, 24절기 한글 변환표) +
      `LandingPage.tsx` 전면 재작성(오늘 인사말/오늘의 흐름/토픽 5종/깊게 보기 3종/관계 2종,
      기존 라우트 재사용, 택일 제외, 가격 노출 없음). 브라우저 검증 완료.
- [ ] 가격 노출. **사용자가 명시적으로 스코프 제외 지시**(2026-07-10) — 진행하지 않음, 다시 묻지 말 것.

---

## 🔮 엔진 업그레이드 트랙 체크리스트 (기획안: [`engine-upgrade-2026-07.md`](./engine-upgrade-2026-07.md))

> 진행 원칙·항목 상세·모델 권장(🧠 Opus급 / 🔧 Sonnet)은 기획안 §2~§3 참조. 여기는 진행 표시만.

- [x] E-0. 기획 문서 + worklog 스캐폴드 (이 커밋)
- [x] S-1. CompactEvidence 심화 필드 노출 (ruleEngine 미연결). `structure`/`tenGodProfile`/`climateClassic`/`sinsalTop`
      optional 추가, evidenceIds 비연결 불변식 테스트 포함, 694/694 그린.
- [x] S-2a. ruleEngine 심화 규칙 + JudgmentCode 4종. structure.solid/broken·climate.unmet·tengod.skew,
      solid는 변별 조건(패턴·종격·투출 성격 경향 + 간이 성패 모순 회피) 부여. golden 기대값 갱신 없이
      밴드 내 통과, 701/701 그린.
- [x] S-2b. golden 확장 21→26 (g22 파격+조후 / g23 종강격+편중 / g24 관인상생 solid만 /
      g25 조후만+층위모순회피 / g26 심화 전부 미발동 네거티브) + 심화 네거티브 컨트롤 1개.
      기존 21케이스 기대값은 갱신 불필요(밴드 내)여서 잠금 예외 미사용. 707/707 그린.
- [x] S-3. 상문·조객 세운 연동. `YearFlowInfo.sinsalHits?` 추가, computeLuckCycles 세운 루프에서
      원국 년지 기준 상문(+2)·조객(-2) 판정(원국 위치판정과 별개), formatLuckCycles 태그·공포금지 gloss.
      테스트 3개, 718 그린.
- [x] S-4. 대운 심화. `LuckCycles.daYunDirection`(양남음녀 순역, 월간↔첫대운 천간 이동으로 판정),
      `DaYunInfo.favor`(luckFavorOf 재사용), `DaYunInfo.interactions`(각 대운 간지 vs 원국, 그동안 current만
      있던 것). natal 블록을 대운 매핑 앞으로 이동. formatLuckCycles 타임라인 보강. 테스트 5개, 723 그린.
- [x] S-5. 프롬프트 반영 정리 + reading-quality 체크리스트. S-1~S-4 심화 근거가 기본(JudgmentPack)·
      고급(raw) 양쪽에 실리고 안전 gloss(상문·조객 공포 금지, 대운 충 '바뀌기 쉬운')가 붙는 것을 렌더링
      확인 → reading.test.ts 프롬프트 테스트 2개로 고정 + `docs/validation/engine-upgrade-s5-prompt-check.md`
      기록. **Track 1(사주) 완료.** 725 그린. (실생성 육안 검증만 API 키 환경 백로그)
- [x] Z-1. iztro horoscope() 스파이크 완료(2.5.8: decadal/yearly = {index=본명궁 인덱스, 간지, mutagen=록권과기
      순 별 4개}, palaces[index].decadal.range=나이구간) + `computeZiweiHoroscope(birth, at)` 래퍼(대한·유년
      간지·명궁 소재궁·사화 붙는 별과 본명 소재궁). `ziweiHoroscope.test.ts` 스냅샷 2생일 lock, 711 그린.
- [x] Z-2. 자미 운한 해석 레이어. `deriveZiweiLuckVerdicts(chart, luck)` — 운한 명궁 소재 본명궁
      =중심 무대(scorePalace 재사용 절반가중) + 사화 붙는 별의 본명 소재궁에 도메인 가감(록권과+/기−).
      표면 '~한 편'·용어 근거만 유지. 테스트 4개, 715 그린.
- [x] Z-3. 동궁 주성 조합 KB. `src/data/ziweiCombos.ts` — iztro 전수 스캔으로 확정한 실존 조합
      단성 14+동궁 24=38 엔트리(통용 통설, 참고용). scorePalace가 동궁 2주성일 때 조합 gloss를
      근거에만 덧붙임(valence 불변→tone 스냅샷 불변). 완결성 audit(KB=iztro 실존 집합) + 해석 테스트,
      `docs/validation/ziwei-combo-table.md` 검수 덤프. 733 그린.
- [x] Z-4. 운한 교차검증·프롬프트·facts 배선. `CrossValidationReport.luckMatches`(세운↔유년 대조,
      기존 matches 불변), `buildCrossValidation`에 `ziweiLuck` 인자 추가, formatCrossValidation에
      '올해 운한 대조' 블록(표면 금지 안내), useReadingStore에서 `computeZiweiHoroscope` 호출·전달.
      테스트 4개, 736 그린. **Track 2(자미두수) 완료.**
- [x] C-1. 궁합 교차 타이밍 엔진 (점수 불변). `CompatibilityResult.timingDetail`(crossHits: 올해 세운지지↔상대
      일지·월지 / outlook: 향후 3년 톤 / dayunPhase: 두 사람 대운 favor 동조·엇갈림, S-4 재사용) 신설,
      `compatibilityTimingDetail`+`branchPairRelation`, CompatibilityPage 렌더+expertEvidence 배선. 점수 불변,
      표면 용어 금지 유지. 테스트 5개, 741 그린.
- [x] C-2. 통관용신·조후 궁합 서술 반영 🧠. `CompatibilityResult.classicComplement`(조후·통관 보완 서술) 신설,
      이미 계산된 `climaticClassic`(1순위 조후 결핍)·`mediating`(통관 bridge)을 상대 오행과 대조. repairReport
      '둘이 같이'에 서술 append + expertEvidence 근거. **점수 산식 미접촉**, 표면 용어 금지 유지. 검수 덤프
      `docs/validation/compat-classic-complement-c2.md`(V-1 대상 표시). 테스트 5개, 746 그린.
- [x] V-1. 전문가 검수 패킷 문서 🧠. `docs/validation/expert-review-packet-2026-08.md` — 4범주(궁통보감
      하위순위 셀·자미 동궁 조합 gloss·확장 신살 판정 기준·C-2 조후/통관 서술)를 확신도 상/중/하 + 우선
      검수 + 점수 관여 여부로 정리, 기존 덤프 3문서 링크. **코드 변경 없음**, 746 그린 유지.
- [x] V-2. golden 21 → 31. 운한 교차검증·세운 상문조객 5케이스(g27~g31) + 네거티브 컨트롤 4. S-3 세운
      상문·조객·S-4 대운 방향/운한 중첩은 pack 밖 신호라 golden 러너를 additive 확장(luck 관찰:
      `buildObservationForCase`·`summarizeJudgmentPack(pack, luck?)`·새 expectation 4종). 기대값은 실제
      프로브서 도출(잠금 갱신 예외 미사용). 755 그린.
- [x] T-1. 타로 코트 페르소나 16종 🧠. `src/data/tarotCourtPersona.ts`(COURT_PERSONA 4슈트×4계급, 인물상·
      성숙단계·관계 모습·역방향 왜곡상, 웨이트 통설·참고용) + `describeCourtPersona`, `formatTarotCards`
      프롬프트 + TarotFactsPanel UI 배선. 완결성 audit(KB=덱 코트 16장, 허수·누락 0)+서술 안전성 테스트 7,
      `docs/validation/tarot-court-persona-table.md` 검수 덤프. 점수·계산 불변. 762 그린.
- [x] T-2. 타로 조합 KB + 감지기 🧠. `src/data/tarotCombos.ts` 51조합(카드 쌍→조합 신호, 웨이트 통설·참고용)
      + `detectCardCombos()`(정·역 무관 쌍 감지), `formatTarotDiagnostics` '카드 조합 신호' 라인 + TarotFactsPanel
      UI 배선. 완결성 audit(실존 카드·중복 0·감지기 정확성)+서술 안전성 테스트 9, `docs/validation/tarot-combos-table.md`
      검수 덤프. 점수·계산 불변. 771 그린.
- [x] A-1. 점성술 Phase A (기존 astrology_upgrade_plan 편입) 🧠. 전체 프로파일 evidence 전달·gloss KB는 봇
      경로에 기구현(`buildAstrologyEvidenceText`+`astrologyInterpretation.ts`). A-1 추가: 고전 품위 인라인 결합
      (`placementHint`), KB↔엔진 교차검증 audit(NAKSHATRA=엔진 27·하우스 1~12·품위 5·모든 산출 행성 role),
      `docs/validation/astrology-gloss-kb.md` 검수 덤프. C/D는 그 문서 복귀. 점수·계산 불변. 776 그린.
- [x] T-3a. 마이너 심화 1/2 — 완드·컵 28장 🧠. `src/data/tarotMinorDepth.ts`(MINOR_DEPTH id 22~49, scene/
      shadow/advice) + `describeMinorDepth`, `formatTarotCards` 프롬프트·TarotFactsPanel UI 배선. audit(안전성
      +완드컵 28 매핑). 점수·계산 불변. 780 그린.
- [x] T-3b. 마이너 심화 2/2 — 소드·펜타클 28장 + 56장 완결성 테스트 🧠. `MINOR_DEPTH`에 소드(50~63)·펜타클
      (64~77) 추가 → 마이너 56장 완비. 전수 완결성 테스트(MINOR_DEPTH=덱 마이너 id 정확 일치·코트 포함),
      검수 덤프 `docs/validation/tarot-minor-depth-table.md`. 점수·계산 불변. 782 그린.
- [ ] V-3. rule weight 캘리브레이션 (잠금 예외 ②, 피드백 후)
- [ ] C-3. 궁합 점수 캘리브레이션 (잠금 예외 ②, 피드백 후)
- 보류: C-4 자미 synastry, 사화비성, astrology Phase C/D

---

## 🚫 불변식 (건드리면 안 되는 것 — 기획안 §12)
- 계산 엔진(`saju.ts`·eventEngine)·궁합 점수·검증 게이트 로직은 변경 금지.
  ※ 단, **엔진 업그레이드 트랙(2026-07-10~)에 한해 사용자 지시로 해제** — ADDITIVE ONLY(새 optional 필드만,
  잠금 테스트 `sajuPrecision`/`sajuCalculationValidation`/`golden`/`johuClassicAudit`/`sinsalClassic` 그린 유지).
  UI/제품(재기획) 목적의 엔진 변경은 여전히 금지.
- Evidence Gate: 스트리밍 1차 + 실패 시에만 재생성 (버퍼링 복귀 금지).
- 쉬운 말 우선 + 전문가 근거 접힘 보존 / 공포·단정·의료·법률·투자 결론 금지.
- 원국 스냅샷 즉시 노출 유지 (재접힘 금지).
- 색감: 한지 팔레트 유지, 그라데이션 금지.
- 프롬프트·섹션 구조 변경 시 `docs/validation/reading-quality-validation.md` 절차 준수.

---

## 🗒️ 세션 로그 (최신이 위로 — 매 세션 한 줄 이상 필수)

| 날짜 | 작업자(계정/모델) | 한 일 | 다음 할 일 |
|---|---|---|---|
| 2026-07-10 | Opus 4.8 | **[별개 트랙: 텔레그램 봇] 타로 추가 + 100% 자연어 맥락 라우팅 + "기억해?" 오인 수정.** (재기획 UI/엔진 트랙과 무관 — "현재 상태" 미변경) `bot/`에 타로 리딩 신규(`tarotReading.ts` 스프레드 자동선택·카드 뽑기·근거 직렬화, teacher `askTarot`, `/타로`), 후속 질문 맥락용 `UserRecord.lastTarot`(store 3곳), 맥락 인지 라우터(`smartRouter.ts`: 최근 대화+등록상태로 의도 확정, 파괴적 삭제·초기화만 키워드 선처리, haiku 폴백), intentDetector `tarotReading` 규칙. 후속: "내 사주 기억해?"(질문)가 memorySave로 오인되던 버그 수정(질문/명령 분리). 상세 `docs/record.md` "텔레그램 봇" 절. bot 95 통과·build 클린. main 병합 | 봇 실제 텔레그램 왕복 육안검증(토큰/API키 필요) |
| 2026-07-10 | Opus 4.8 | **엔진 업그레이드 T-3b — 타로 마이너 심화 2/2(소드·펜타클 28장), 마이너 56장 완비 → 엔진 업그레이드 신규 항목 전부 완료.** `MINOR_DEPTH`에 소드(50~63)·펜타클(64~77) 추가로 마이너 56장 scene/shadow/advice 완비. 56장 전수 완결성 테스트(MINOR_DEPTH=덱 마이너 id 22~77 정확 일치·허수/누락 0·코트 포함) 2개, 검수 덤프 `docs/validation/tarot-minor-depth-table.md`(56장 표). 점수·계산 불변. 782/782, tsc/build 클린. 남은 것은 잠금 예외 C-3·V-3(피드백 후)뿐 | (피드백 후) C-3·V-3 캘리브레이션 / 그 전엔 실생성 육안 검증 |
| 2026-07-10 | Opus 4.8 | **엔진 업그레이드 T-3a — 타로 마이너 심화 1/2(완드·컵 28장).** `src/data/tarotMinorDepth.ts` 신설(MINOR_DEPTH: 카드 id→{scene 현실장면·shadow 그늘·advice 조언}, 완드 22~35+컵 36~49 = 28장, 웨이트 통설·참고용) + `describeMinorDepth`(tarotSymbolism, 마이너만). `formatTarotCards` 프롬프트에 현실 장면·그늘·조언 라인, TarotFactsPanel에 장면 라인 배선. audit(scene/shadow/advice 비지않음·공포금지·메이저 null·완드컵 28 전수 매핑) 테스트 4개. 점수·계산 불변. 780/780, tsc/build 클린 | T-3b(소드·펜타클 28 + 56장 완결성) |
| 2026-07-10 | Opus 4.8 | **엔진 업그레이드 A-1 — 점성술 Phase A 편입·강화.** 전체 프로파일 evidence 전달·gloss KB(PLANET_ROLE·SIGN_STYLE·HOUSE_THEME·ASPECT_GLOSS·DIGNITY_GLOSS·NAKSHATRA_GLOSS)는 봇 경로(`buildAstrologyEvidenceText`+`astrologyInterpretation.ts`)에 기구현 확인. A-1 추가: ① `placementHint`가 고전 품위(도미사일/엑잘/디트리먼트/폴)를 배치 힌트에 인라인 결합(별도 dignities 목록 유지), ② KB↔엔진 교차검증 audit 5종(NAKSHATRA_GLOSS=엔진 NAKSHATRAS 27 정확 일치·HOUSE_THEME 1~12·DIGNITY 5상태·계산 프로파일 모든 행성 PLANET_ROLE·품위 인라인 실림), ③ 검수 덤프 `docs/validation/astrology-gloss-kb.md`. NAKSHATRAS export. C/D(외행성 앵글·트랜짓·나밤샤·차트휠)는 astrology_upgrade_plan 복귀. 점수·계산 불변. 776/776, tsc/build 클린 | T-3a/b(타로 마이너 56장 심화 🧠) |
| 2026-07-10 | Opus 4.8 | **엔진 업그레이드 T-2 — 타로 카드 조합 KB 51종.** `src/data/tarotCombos.ts` 신설(카드 id 쌍→조합 신호 51개, 관계·전환·회복·시작·갈등·판단·코트 카테고리, 라이더-웨이트 통설·참고용) + `detectCardCombos()`(뽑힌 카드들 안 실존 쌍 감지, 정·역 무관·자리순 결정론). `formatTarotDiagnostics`에 '카드 조합 신호(참고용)' 라인 + TarotFactsPanel 조합 리스트 UI 배선. 완결성 audit(모든 조합 실존 카드 0~77·서로 다름·오름차순·중복 0 + 감지기 있는쌍/없는쌍/복수/단일 + 서술 안전성) 테스트 9개, 검수 덤프 `docs/validation/tarot-combos-table.md`. 점수·계산 불변(설명 텍스트 전용). 771/771, tsc/build 클린 | A-1(점성술 Phase A 🧠) → T-3a/b(마이너 심화) |
| 2026-07-10 | Opus 4.8 | **엔진 업그레이드 T-1 — 타로 코트 페르소나 16종(Track 4 착수).** `src/data/tarotCourtPersona.ts` 신설(COURT_PERSONA 4슈트×4계급=16, 인물상·성숙단계·관계 모습·역방향 왜곡상, 라이더-웨이트 통설·참고용). `describeCourtPersona`(tarotSymbolism)로 `formatTarotCards` 프롬프트에 코트 블록(역방향이면 왜곡상)+TarotFactsPanel 인물상 라인 배선. 완결성 audit(KB=덱 코트 16장, 허수·누락 0)+서술 안전성(공포·단정 금지, Page=시작/King=완성 성숙 축) 테스트 7개, 검수 덤프 `docs/validation/tarot-court-persona-table.md`. 점수·계산 불변(설명 텍스트 전용). 762/762, tsc/build 클린 | T-2(타로 조합 KB+감지기 🧠) → A-1(점성술) |
| 2026-07-10 | Opus 4.8 | **엔진 업그레이드 V-2 — golden 26→31 확장.** 운한 교차검증·세운 상문조객 5케이스(g27 진년 상문·순행 / g28 진년 상문·역행 / g29 신년 조객·역행 / g30 신년 조객·순행 / g31 오년 미발동+운한 amplify-good 네거티브). S-3 세운 상문·조객·S-4 대운 방향/운한 중첩은 JudgmentPack 밖 신호라 golden 러너를 **additive 확장**: `buildObservationForCase`(pack+luck 동반 반환)·`summarizeJudgmentPack(pack, luck?)`(currentYearSinsalHits/daYunDirection/luckOverlapCombo 관찰)·새 expectation 4종(`requiredYearSinsal`/`forbiddenYearSinsal`/`expectDaYunDirection`/`expectLuckOverlapCombo`). 기대값은 실제 엔진 프로브서 도출(잠금 갱신 예외 미사용). 네거티브 컨트롤 4로 비공허 증명, README 갱신. 755/755, tsc/build 클린 | T-1(타로 코트 페르소나 16 🧠) → T-2(타로 조합 KB) |
| 2026-07-10 | Opus 4.8 | **엔진 업그레이드 V-1 — 전문가 검수 패킷(docs-only).** `docs/validation/expert-review-packet-2026-08.md` 신설 — 4범주(A 궁통보감 조후 하위순위 셀 / B 자미 동궁 조합 gloss / C 확장 신살 판정 기준 / D C-2 궁합 조후·통관 서술)를 확신도 상/중/하 컬럼·우선 검수 표시·점수 관여 여부로 정리하고, 기존 덤프 3문서(johu-classic-table·ziwei-combo-table·compat-classic-complement-c2) 링크. 우선 검수 셀/조합/신살 콕 집음(귀문↔원진 겹침, 현침 2개 규칙, 관귀학관·복성귀인 도출식, 일월동궁 등). **코드 변경 없음**, 746/746 유지. (climaticClassic은 점수 미관여임을 코드로 재확인해 A범주 표기 정정) | V-2(golden 21→30+ 확장) → T-1/T-2(타로) |
| 2026-07-10 | Opus 4.8 | **엔진 업그레이드 Track 3(궁합) 완료 — C-2(고전 보완 서술).** `CompatibilityResult.classicComplement`(headline/johu/mediating/together/evidence) 신설 — 이미 계산된 `chart.yongshin.climaticClassic`(궁통보감 1순위 조후 결핍)·`mediating`(통관 bridge)을 상대 fiveElements와 대조해 "상대가 계절 치우침/대립 기운을 채워준다" 서술. `compatibilityClassicComplement` 신설, `repairReport.byPerson.together`에 '둘이 같이' 서술 append + expertEvidence 근거 한 줄, CompatibilityPage 렌더. **점수 산식 미접촉**(간이 johuComplement는 점수용 그대로), 표면 용어 금지 유지. 검수 덤프 `docs/validation/compat-classic-complement-c2.md`(V-1 대상 확신도 표). 테스트 5개, 746/746, tsc/build 클린 | V-1(전문가 검수 패킷 🧠) → V-2(golden 확장) → T-1/T-2 |
| 2026-07-10 | Opus 4.8 | **엔진 업그레이드 Track 3 착수 — C-1(궁합 교차 타이밍).** `CompatibilityResult.timingDetail` 신설(crossHits: 한 사람 올해 세운지지↔상대 원국 일지·월지 신호 / outlook: 향후 3년 톤 / dayunPhase: 두 사람 현재 대운 favor 동조·엇갈림, S-4 재사용). `compatibilityTimingDetail`+`branchPairRelation`(지지쌍 분류기) 신설, 대운 favor는 각 원국 용신/기신을 `computeLuckCycles` 옵션으로 넘겨 산출. CompatibilityPage "다가오는 흐름 — 교차 타이밍" 블록+expertEvidence 2줄. **점수·기존 timing 불변**, 표면 용어 금지 유지. 테스트 5개, 741/741, tsc/build 클린. (작업 브랜치 ik50ji = main·ht4pat 동일 지점) | C-2(통관용신·조후 궁합 서술 🧠) → V-1 → V-2 → T-1/T-2 |
| 2026-07-10 | Fable 5 / Opus 4.8 | **엔진 업그레이드 Track 1(사주) 완료 + Track 2 착수 — S-3·S-4·S-5(커밋 3개).** S-3 상문·조객 세운 연동(`YearFlowInfo.sinsalHits`), S-4 대운 심화(`daYunDirection` 순역·`DaYunInfo.favor`·대운별 `interactions`, natal 블록 이동), S-5 프롬프트 반영 검증(심화 근거가 기본 JudgmentPack·고급 raw 양쪽에 실리고 공포금지 gloss 부착 확인, reading.test 2개+검증문서). 725/725, tsc/build 클린. 이후 main 병합·푸시 | Z-3(자미 성계 조합 KB)→Z-4(운한 배선)→C-1(궁합 교차 타이밍) |
| 2026-07-10 | Fable 5 / Opus 4.8 | **엔진 업그레이드 트랙 착수 — E-0·S-1·S-2a·S-2b·Z-1·Z-2 완료(커밋 6개).** 기획안 신규(`engine-upgrade-2026-07.md`, 22항목·모델 권장). 사주: CompactEvidence에 4대 고전 심화 필드(격국classic·십성분포·궁통보감조후·핵심신살) 노출→ruleEngine 심화 규칙 4종(structure.solid/broken·climate.unmet·tengod.skew)+JudgmentCode 4개→golden 21→26(심화 회귀+네거티브). 자미: iztro horoscope() 스파이크+`computeZiweiHoroscope`(대한·유년, ziweiHoroscope.test 잠금)+`deriveZiweiLuckVerdicts`(운한 명궁 무대+사화 도메인 가감). 715/715, tsc/build 클린 | S-3(상문·조객 세운 연동)→S-4(대운 심화)→S-5→Z-3→Z-4 |
| 2026-07-10 | Sonnet 5 | **입력 폼·리딩 결과 카드 중첩 완화(사용자 스크린샷 신고).** `/saju` 폼의 "선택 설정"/"분야·말투·해석 깊이"(`.consultation-panel`, `BirthInfoForm`/`ContextPicker`/`TarotSpreadPicker`/`ComboPage` 공유)를 박스→상단 구분선으로, 리딩 결과 섹션 카드 내부 `[한 줄 결론]` 등 하위 파트(`.reading-part`, `readingBlocks.tsx`)를 박스→점선 구분선으로 CSS만 변경(구조·계산·색감 불변). 손볼 범위는 AskUserQuestion으로 "가볍게 CSS만" 확인 후 진행. 693/693 통과, build 성공, 커밋 `5515c69`, main에 fast-forward 병합·푸시(`19fe62c`) | (이후 엔진 업그레이드 트랙이 이 위에서 이어짐) |
| 2026-07-10 | Sonnet 5 | **카드 홈 전면 개편(시안 ①) — §11 "A~C 뒤" 항목 완료.** `dailyGreeting.ts` 신규(출생정보 없이 일진·절기 계산, lunar-javascript 한자 절기명을 24종 한글 변환표로 보완, 타입 선언에 `getPrevJieQi` 추가), `LandingPage.tsx` 전면 재작성(인사말/오늘의 흐름/토픽5/깊게보기3/관계2, 택일·가격 제외), 테스트 9개, 693/693 통과, Playwright로 실제 홈 화면·라우팅 확인 | 가격 노출은 사용자 지시로 스코프 제외(다시 묻지 말 것), 남은 건 실생성 육안 검증뿐 |
| 2026-07-10 | Sonnet 5 | **토픽 5종 템플릿 확장 — 후속 질문 채팅.** `TopicDeepChat.tsx` 전면 재작성(초기 5섹션 후 최대 5회 후속 질문을 컴포넌트 로컬 상태로 자체 관리, 전역 세션 비파괴), 토픽별 추천 칩+자유 입력, `BasicReadingSection.tsx` 단순화, Playwright로 5섹션 도착→후속 칩 클릭→말풍선→카운터 감소 전 과정 확인 | 카드 홈 전면 개편(시안 ①) 착수, 사용자 지시로 연속 진행 중 |
| 2026-07-09 | Sonnet 5 | **B-3 완료 — A·B·C 트랙 전부 완료.** `ReportProgress.tsx`(시안 ③) + `readingProgress.ts` depth 버그 수정(advanced total 11→14) + 섹션 앵커 보강 + 회귀 1건 발견·수정, 테스트 12개, 688/688 통과, Playwright로 API 지연시켜 실제 로딩 화면·print 숨김 확인 | §11 "A~C 뒤" 항목 착수 여부 확인 필요, 실생성 육안 검증 누적 |
| 2026-07-09 | Sonnet 5 | B-2: PERSON_DEEP_INSTRUCTION 밀도 규칙을 3섹션→16섹션 전체로 확장, print CSS는 CompatibilityPage가 ReadingActions/전역 CSS 재사용해 B-1에서 이미 해결됨 확인, 678/678 통과 | B-3(리포트 진행 화면) 착수, 사용자 지시로 연속 진행 중 |
| 2026-07-09 | Sonnet 5 | B-1: DEPTH_INSTRUCTION.advanced에 문장 밀도 규칙 추가("뻔한 말 금지+근거 직접 연결"), print CSS에 새 인터랙티브 블록(goosebump/topic-chips/sidebar) 숨김 처리, 677/677 통과, Playwright emulateMedia로 print 계산값 확인 | B-2(상대 해부) 착수, 사용자 지시로 연속 진행 중 |
| 2026-07-09 | Sonnet 5 | **C 트랙 완료.** C-4 사이드바: `Sidebar.tsx`+`profileList.ts`(기존 profile.ts 불변, 위에 다중 프로필만 추가), Layout.tsx nav 정리(보조 기능→사이드바 이전), 테스트 7개, 677/677 통과, Playwright로 빈 상태→저장→전환 전 과정 확인 | B-1(평생사주 문장 밀도) 착수, 사용자 지시로 연속 진행 중 |
| 2026-07-09 | Sonnet 5 | C-3 신뢰 배지: `MethodologyPage.tsx`(어떻게 계산하나요, 4대 고전·시간보정·근거공개 설명)+`TrustBadges.tsx`(원국 아래 마운트)+`/methodology` 라우트, 테스트 7개, 670/670 통과, Playwright로 배지·페이지 이동 확인 | C-4(사이드바) → B-1~3, 사용자 지시로 연속 진행 중 |
| 2026-07-09 | Sonnet 5 | C-2 공유 카드: `shareGoosebumpImage.ts` 신규(한지 팔레트 단일 PNG, 그라데이션 없음), shareImage.ts 유틸 export 재사용, GoosebumpCheck에 저장 버튼, Playwright로 실제 PNG 다운로드까지 확인(캔버스라 유닛테스트는 기존 컨벤션대로 없음) | C-3(신뢰 배지) → C-4 → B-1~3, 사용자 지시로 연속 진행 중 |
| 2026-07-09 | Sonnet 5 | C-1 소름 엔진: `goosebumpEngine.ts`(강한 신호만 후보, 빈 배열 허용)+`goosebumpStorage.ts`+`GoosebumpCheck.tsx`(블록 1로 마운트), saju.ts에 `computePastYearRawSignals` 추가, 테스트 22개, 663/663 통과, Playwright로 클릭→답변 전환까지 확인 | C-2(공유 카드) → C-3 → C-4 → B-1~3, 사용자 지시로 연속 진행 중 |
| 2026-07-09 | Sonnet 5 | A-2 파이프라인: analysisMode="topicDeep"+TopicDeepTopic 신규, systemPrompt에 5토픽 전용 5섹션 지시(JudgmentPack domain 필터 재사용, 새 근거 없음), fan-out 제외, 서버측 Haiku 강제, 테스트 10개, 637/637 통과. CTA 클릭 연결·실생성 검증은 미완(제품 결정/API 키 필요) | A-2 UI 연결 또는 A-3 착수 |
| 2026-07-09 | Sonnet 5 | A-1 완료: `BasicReadingSection.tsx` 장착(내 사용 설명서·올해 흐름 캘린더 신규 + InstantSummary 승격), 중복 제거, CSS 추가, 테스트 3개, 627/627 통과, Playwright로 실제 화면 렌더 확인 | A-2 토픽 AI 심화 파이프라인 착수 |
| 2026-07-09 | Sonnet 5 | A-1: `basicReadingRenderer.ts` 신규(무료 기본 리딩 블록 2~6 조립) + 테스트 6개, 전체 624/624 통과·tsc 클린·build 성공 | A-1 UI 장착 또는 A-2 착수 |
| 2026-07-09 | 초기 셋업 | 기획안·시안·레코드 파일 등록, SessionStart 강제 확인 훅 설치 | A-1 룰 렌더러 착수 |
