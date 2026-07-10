# 점술 엔진 정확도·지식 심화 업그레이드 기획 (2026-07)

> 사주·자미두수·궁합·타로·점성술 전 엔진의 **해석 지식 깊이 + 계산 정밀도 + AI 리딩 품질**을 올리는 트랙.
> 사용자 지시(2026-07-10)로 재기획 불변식 중 **"계산 엔진 변경 금지"는 해제** — 단 아래 ADDITIVE ONLY 원칙으로 기존 정확성은 계속 보호한다.
> 진행 기록은 [`redesign-worklog.md`](./redesign-worklog.md)의 "엔진 업그레이드 트랙" 체크리스트에 남긴다.

## §1. 배경 — 확인된 갭 (2026-07-10 탐색)

- **사주**: 4대 고전 심화 필드(격국 classic 상신·성패·파격·종격 / 십성 분포 / 궁통보감 조후 120셀 / 확장 신살)가 `saju.ts`에 **이미 계산**되어 있으나, 대다수 사용자가 보는 **기본 리딩 경로(`compactEvidence.ts` → JudgmentPack)에 전혀 노출되지 않음**. 상문·조객은 원국 위치판정만 있고 세운 미연동. 대운의 순역·용신방향·원국 상호작용 노출이 얕음.
- **자미두수**: iztro에 위임한 natal 차트만 존재. **대한·유년(운 흐름) 전무** — iztro 2.5.8의 `horoscope()` API 미사용. 별 29개 단일 valence 근사, 동궁 주성 조합 해석 없음.
- **궁합**: `compatibilityTiming`이 고정 문장 2블록 수준. 두 사람의 대운/세운 교차 계산 없음. 통관용신·궁통보감 조후 미반영(next_steps "궁합 점수 개선 이후" 후보).
- **타로**: 78장·역방향·엘리멘탈 디그니티는 갖춤. 코트 16 페르소나, 전통 카드 조합 KB, 마이너 56장 개별 심화 없음.
- **점성술**: `astrology_upgrade_plan.md`에 Phase A~D 로드맵 기존재 — **Phase A만 이 트랙에 편입**, C/D는 그 문서 일정대로 분리 유지.
- **검증**: "정확도"가 현재 구조·안전성 검증 위주. 궁통보감 하위순위 셀 미검수(전문가 검수 필요), rule weight 캘리브레이션(next_steps P3) 미착수.

## §2. 불변 원칙 (전 세션 공통)

1. **ADDITIVE ONLY**: `sajuPrecision.test.ts` · `sajuCalculationValidation.test.ts` · `golden.test.ts`(21케이스) · `johuClassicAudit.test.ts` · `sinsalClassic.test.ts`가 잠근 값은 변경 금지. 새 정보는 전부 **새 optional 필드**. 기존 693 테스트 그린 유지.
   - **잠금 갱신 예외 2곳만**: S-2b(golden 기대값 리뷰 갱신), C-3/V-3(캘리브레이션). 반드시 별도 리뷰 커밋으로 전후 기록.
2. 프롬프트/섹션 변경 시 [`validation/reading-quality-validation.md`](./validation/reading-quality-validation.md) 절차. Evidence Gate streaming-first 유지.
3. 공포·단정·의료/법률/투자 금지, 쉬운 말 우선(전문용어는 근거 블록만), "~한 편" 톤 상속.
4. 실생성(LLM) 육안 검증은 `ANTHROPIC_API_KEY` 없는 환경이라 **사용자 환경 백로그**로 이월(기존 패턴).
5. 매 세션: 항목 완료 → `npm test` + `npm run build` → 이 문서 체크리스트 갱신 + worklog 현재상태 덮어쓰기·세션로그 append → 커밋/푸시.
6. 새 지식 테이블(S-2·Z-3·T-2 등)은 **같은 세션에** 완결성 audit 테스트(johuClassicAudit 패턴) + `docs/validation/` 전문가 대조 덤프표를 동시 산출.

## §3. 실행 체크리스트

모델 권장: 🧠 = 도메인 지식 작성이 품질을 좌우 → Opus급 권장 / 🔧 = 배선·플러밍 → Sonnet으로 충분.

### E. 스캐폴드
- [ ] E-0. 🔧 이 문서 + worklog 트랙 병기. (이 커밋)

### Track 1 — 사주 심화 노출 (최우선)
- [ ] S-1. 🔧 `compactEvidence.ts`에 optional 필드 추가: `structure`(격국 classic), `tenGodProfile`(십성 그룹 분포·dominant·missing), `climateClassic`(궁통보감 1~3순위·충족 여부), `sinsalTop`(핵심 5~7개+gloss). 기존 `chart.*` 읽기 전용, **ruleEngine 미연결**(golden 영향 차단). 성공: 신규 필드 테스트 + 전 테스트 그린.
- [ ] S-2a. 🧠 `ruleEngine.ts` 심화 규칙(격국 성격/파격, 조후 미충족, 십성 편중) + `judgmentTypes.ts`에 `STRUCTURE_SOLID_SUPPORT`/`STRUCTURE_BROKEN_CAUTION`/`CLIMATE_BALANCE_NEEDED`/`TENGOD_SKEW_TRAIT` → judgmentEngine·judgmentPrompt·judgmentValidation·caseScore(CODE_EXPECTATION) 대응.
- [ ] S-2b. 🔧 golden 리뷰 갱신(잠금 예외) + 신규 4~6케이스(파격/조후 미충족/십성 편중) + 네거티브 컨트롤.
- [ ] S-3. 🔧 상문·조객 세운 연동: `YearFlowInfo.sinsalHits?` — 세운 지지가 원국 년지 기준 상문/조객이면 기록. `formatLuckCycles`·월별 서사에 gloss 부기(공포 금지 톤).
- [ ] S-4. 🔧 대운 심화: `LuckCycles.daYunDirection?`(순역), `DaYunInfo.favor?`(용신/기신 — 기존 favor 산식 재사용), `DaYunInfo.interactions?`(대운 지지 vs 원국 합충형파해). `formatLuckCycles` 타임라인 보강.
- [ ] S-5. 🔧 S-1~S-4의 gate/anchor·고급 블록 렌더 정리 + reading-quality 체크리스트 수행 + 필요한 프롬프트 문구 조정.

### Track 2 — 자미두수 운한 + 성계 조합
- [ ] Z-1. 🔧 iztro `horoscope()` 스파이크(반환 구조 실측·문서화) + `ziwei.ts`에 `computeZiweiHoroscope(birth, at?)` — 대한/유년: 간지·명궁 소재궁·사화 붙는 별과 소재궁. `ZiweiChart` 불변. `ziweiHoroscope.test.ts` 스냅샷이 자미 precision lock.
- [ ] Z-2. 🧠 `ziweiInterpretation.ts`에 `deriveZiweiLuckVerdicts` — ① 대한/유년 명궁이 앉은 본명 궁 점수(`scorePalace` 재사용) ② 사화 붙는 별의 소재궁 → 도메인 가감.
- [ ] Z-3. 🧠 동궁 주성 조합 KB `STAR_COMBO_GLOSS` ~45-50 엔트리(실존 동궁 쌍 + 단성 14, 통용 통설, "참고용" 주석). 완결성 audit + 검수 덤프표. 사화비성은 의도적 보류 기재.
- [ ] Z-4. 🔧 배선: crossValidation에 세운↔유년 대조 축(기존 필드 불변), systemPrompt에 `[자미두수 운한 — 계산됨]` formatter + facts 주입, api/reading·useReadingStore 배선. UI는 계산근거 존 텍스트 수준.

### Track 3 — 궁합
- [x] C-1. 🔧 `CompatibilityResult.timingDetail?` — crossHits(A 세운지지↔B 일지/월지 상호), outlook(향후 3년), dayunPhase(대운 favor 동조/엇갈림, S-4 재사용). **점수 불변**. `compatibilityTimingDetail`(saju.ts) 신설, `branchPairRelation` 지지쌍 분류기, 대운 favor는 각 원국 용신/기신을 `computeLuckCycles` 옵션으로 넘겨 산출(useReadingStore와 동일 규칙). CompatibilityPage에 "다가오는 흐름 — 교차 타이밍" 블록·expertEvidence 2줄. 표면 용어 금지 유지. 테스트 5개, 741 그린.
- [x] C-2. 🧠 통관용신·궁통보감 조후를 점수 변경 없이 repairReport/solutionPlan 서술·evidence에 반영. `CompatibilityResult.classicComplement`(headline/johu/mediating/together/evidence) 신설 — `compatibilityClassicComplement`가 이미 계산된 `chart.yongshin.climaticClassic`(1순위 조후 결핍)·`mediating`(통관 bridge)을 상대 fiveElements와 대조. `repairReport.byPerson.together`에 '둘이 같이' 서술 append + expertEvidence 근거 한 줄. 점수 산식 미접촉(간이 johuComplement는 점수용 그대로). CompatibilityPage 렌더, `docs/validation/compat-classic-complement-c2.md` 검수 덤프(V-1 대상 표시). 테스트 5개, 746 그린.
- [ ] C-3. 🔧 (후순위·잠금 예외) 실사용 샘플 10~20쌍 대조 후 가중치 1회 조정, 전후 분포 기록. 피드백 전이면 보류.
- [ ] C-4. (선택) 자미 synastry — 부처궁 주성 대조 1축, Z-3 이후.

### Track 4 — 타로
- [x] T-1. 🧠 `COURT_PERSONA` 16종(인물상·성숙단계·관계 모습·역방향 왜곡상, 웨이트 전통 통설). `src/data/tarotCourtPersona.ts`(4슈트×4계급, courtKey 조회) + `describeCourtPersona`(tarotSymbolism). `formatTarotCards` 프롬프트에 코트 블록(역방향이면 왜곡상) + TarotFactsPanel 인물상 라인. 완결성 audit(KB=덱 코트 16장) + 서술 안전성(공포·단정 금지, Page=시작/King=완성) 테스트 7개, `docs/validation/tarot-court-persona-table.md` 검수 덤프. 점수·계산 불변. 762 그린.
- [x] T-2. 🧠 `src/data/tarotCombos.ts` 51조합(카드 id 쌍·label·signal, 웨이트 통설·참고용) + `detectCardCombos()`(뽑힌 카드 쌍 감지, 정·역 무관) → `formatTarotDiagnostics`에 "카드 조합 신호" 라인 + TarotFactsPanel UI. 완결성 audit(실존 카드 0~77·오름차순·중복 0·감지기 정확성)+서술 안전성 테스트 9개, `docs/validation/tarot-combos-table.md` 검수 덤프. 점수·계산 불변. 771 그린.
- [x] T-3a. 🧠 마이너 심화 1/2: 완드·컵 28장 `depth: { scene; shadow; advice }`. `src/data/tarotMinorDepth.ts`(MINOR_DEPTH id 22~49) + `describeMinorDepth`(tarotSymbolism) → `formatTarotCards` 프롬프트에 현실 장면·그늘·조언 라인 + TarotFactsPanel 장면 라인. 공통 audit(비지 않음·공포금지·메이저 null)+완드컵 28장 매핑 테스트. 점수·계산 불변. 780 그린.
- [ ] T-3b. 🧠 마이너 심화 2/2: 소드·펜타클 28장. 56장 완결성 테스트.

### Track 5 — 검증·캘리브레이션
- [x] V-1. 🧠 전문가 검수 패킷: 궁통보감 하위순위 셀 + 자미 조합 gloss + 확장 신살 판정 기준 + C-2 조후·통관 서술 → `docs/validation/expert-review-packet-2026-08.md`(4범주·항목별 확신도 상/중/하 컬럼·우선 검수 표시·점수 관여 여부 명시·기존 덤프 3문서 링크). 코드 변경 없음, 746 그린 유지.
- [x] V-2. 🔧 golden 21 → 31 (파격·조후 미충족은 S-2b에서, V-2는 운한 교차검증·세운 상문조객 5케이스 g27~g31 + 네거티브 컨트롤). 세운 상문·조객(S-3)·대운 방향/운한 중첩(S-4)은 pack 밖 신호라 golden 러너를 additive 확장(`buildObservationForCase`가 luck 동반 반환, `summarizeJudgmentPack(pack, luck?)`, 새 expectation `requiredYearSinsal`/`forbiddenYearSinsal`/`expectDaYunDirection`/`expectLuckOverlapCombo`)해 관찰. 기대값은 실제 엔진 프로브서 도출(잠금 갱신 예외 미사용, 밴드 내 통과). 네거티브 컨트롤 4종으로 비공허 증명. 755 그린.
- [ ] V-3. 🔧 (잠금 예외) caseValidation 픽스처 22→40+, matchRate·캘리브레이션 리포트 근거 수동 조정 1회, 전후 비교표.

### Track 6 — 점성술
- [x] A-1. 🧠 `astrology_upgrade_plan.md` Phase A만: 전체 프로파일 evidence 전달(봇 `buildAstrologyEvidenceText`가 이미 전체 프로파일+각도+트랜짓+힌트 통째 전달) + gloss KB(`astrologyInterpretation.ts`: PLANET_ROLE·SIGN_STYLE·HOUSE_THEME·ASPECT_GLOSS·DIGNITY_GLOSS·NAKSHATRA_GLOSS). A-1 추가분: ① `placementHint`에 고전 품위 인라인 결합(도미사일/폴 등 → 배치 힌트에 바로), ② KB↔엔진 교차검증 audit(NAKSHATRA_GLOSS=엔진 NAKSHATRAS 27·HOUSE_THEME 1~12·DIGNITY 5상태·모든 산출 행성 PLANET_ROLE), ③ `docs/validation/astrology-gloss-kb.md` 검수 덤프. C/D(외행성 앵글·트랜짓·나밤샤·차트휠 viz)는 그 문서로 복귀. 점수·계산 불변. 776 그린.

## §4. 권장 순서

```
E-0 → S-1 → S-2a → S-2b → Z-1 → Z-2 → S-3 → S-4 → S-5
→ Z-3 → Z-4 → C-1 → C-2 → V-1 → V-2 → T-1 → T-2 → A-1
→ T-3a → T-3b → (피드백 후) V-3 → C-3
보류: C-4, 사화비성, astrology Phase C/D
```

## §5. 리스크

- **Z-1이 관문**: iztro `horoscope()` 반환이 기대와 다르면 그 세션에서 Z-2 설계를 조정하고 여기 기록.
- **S-2는 golden에 닿는 유일한 사주 항목** → S-2a/S-2b 2분할 필수.
- 궁통보감·자미 조합·확장 신살은 "참고용" 주석 유지, V-1 검수 전 단정 서술 금지.
