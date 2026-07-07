# 명리 4대 고전 엔진 반영 (진행 문서)

작성일: 2026-07-07
목적: 계산 엔진(`src/lib/saju.ts`)에 명리학 4대 고전의 실제 이론을 더 정밀하게 반영한다.
이 문서는 **여러 세션/계정이 이어서 작업**할 수 있도록 작성된 진행 기록이다. 작업은 작게 쪼개 커밋하고, 각 단계 완료 시 이 문서의 상태를 갱신한다.

## 배경
경쟁 서비스가 "명리 4대 고전(자평진전·연해자평·궁통보감·삼명통회)"을 근거로 신뢰를 내세우는 것을 보고,
우리도 마케팅 카피가 아니라 **계산 로직 자체**를 고전 이론에 맞게 정밀화하기로 함.
추가로 "직접 가서 사주 본 듯한" 상담 느낌(대면 상담 톤/구성)을 리딩에 강화한다.

## 현재 수준 → 목표
| 고전 | 이론 | 현재 | 목표 | 담당 Phase |
|------|------|------|------|-----------|
| 자평진전 子平眞詮 | 격국론(상신·성패) | 2/5 | 4/5 | A |
| 연해자평 淵海子平 | 십성론(지장간 가중) | 4/5 | 5/5 | B |
| 궁통보감 窮通寶鑑 | 조후론(120조합) | 1/5 | 4/5 | C ★리스크 |
| 삼명통회 三命通會 | 신살 확장 | 3/5 | 4/5 | D |

## 핵심 제약 (반드시 준수)
- **ADDITIVE ONLY.** 기존 필드/값을 바꾸지 않는다. 새 optional 필드만 추가.
- `src/lib/sajuPrecision.test.ts`, `src/lib/sajuCalculationValidation.test.ts`가 잠근 값
  (pillars, five-elements, luck, `gyeokguk.name/basisKind/basisStem`, `yongshin.climatic.element`,
  대운/세운 tenGod 등)은 **그대로 통과해야 한다.**
- 특히 궁통보감 결과는 `yongshin.climatic`(간이, 잠금됨)을 덮지 말고 **새 필드 `yongshin.climaticClassic`**로.
- 단계마다: 새 테스트 추가 → `npm test` → `npm run build` → `docs/record.md` 기록.

## 작업 순서와 상태
### Phase 0 — 타입 추가 · ✅ 완료
`src/types/index.ts`:
- `ClimaticClassicInfo`(궁통보감 조후), `YongshinCandidates.climaticClassic?`
- `GyeokgukClassicInfo`(상신·성패·종격), `GyeokgukInfo.classic?`
- `HiddenTenGodBreakdown`, `SajuChart.hiddenTenGods?`, `SajuChart.tenGodDistribution?`

### Phase B — 연해자평 지장간 십성 분포 · ✅ 완료
`src/lib/saju.ts`:
- `HIDDEN_PHASE_WEIGHT`(정기1.0/중기0.5/여기0.3)
- `computeHiddenTenGods(dayGan, zhis)` → 지지별 지장간 위상별 십성
- `computeTenGodDistribution(dayGan, gans, zhis)` → 십성 세기 분포(천간1.0 + 지장간 가중)
- `TENGOD_GROUP`, `tenGodGroupTotals(dist)` → 비겁/식상/재성/관성/인성 그룹 합계
- `assembleChart`에서 `hiddenTenGods`, `tenGodDistribution` 세팅.

### Phase A — 자평진전 상신·성격/파격·종격 · ✅ 완료(코드)
`src/lib/saju.ts`:
- `SANGSHIN_RULE`(격별 상신 후보 그룹), `GROUP_ELEMENT_OF`(그룹→오행)
- `assessJonggyeok(strength, groupTotals)` → 종재/종살/종아/종왕/종강격
- `assessGyeokgukClassic(dayGan, baseTenGod, strength, dist, groupTotals)` → `GyeokgukClassicInfo`
  - 상신 판정, 성격 패턴(살인상생·식신제살·상관생재·상관패인·식신생재·재생관·관인상생),
    파격 요인(상관견관·정관봉상관·재다신약·탐재괴인·칠살무제·효신탈식·녹인무의), 성패 종합.
- `assembleChart`에서 `gyeokguk.classic` 세팅.
- ⚠️ 상신/파격 규칙은 심효첨·서락오 통설 기반. 관법 이견 있어 "참고용" 문구 유지.

### Phase D — 삼명통회 신살 확장 · ✅ 완료(코드+테스트)
`src/lib/saju.ts` `computeSinsal`에 append + `SINSAL_GLOSS` 항목 추가:
- **구현**: 태극귀인(일간→지지), 삼기귀인(천상 갑무경/지하 을병정/인중 임계신, 세 천간 모두 존재 시),
  관귀학관(관성 양간의 장생지 — CHANGSHENG로 파생), 재고귀인(재성 오행 묘고 — ELEMENT_TOMB로 파생),
  격각살(일지·시지 지지 순서상 2칸 차이).
- 관귀학관·재고귀인은 하드코딩 대신 **오행 파생**으로 계산해 12운성 테이블과 내부 일관성 유지.
- 테스트: `src/lib/sinsalClassic.test.ts`, `sajuFeatures.test.ts` KNOWN 집합에 신규 이름 추가.
- ⚠️ **의도적 보류**(판본 차이로 정확성 리스크): **복성귀인**(일간→지지 표 이견 큼), **현침살**(뾰족획 글자셋 이견 + 과다발화 우려). 추후 검증된 출처 확보 시 추가.
- ⚠️ 상문/조객은 **세운(년지 상대)** 신살 → 원국이 아니라 대운/세운 경로에 넣어야 함(미구현, 별도 과제).

### Phase C — 궁통보감 조후 120조합 · ✅ 완료(코드+테스트)
`src/lib/saju.ts`:
- `JOHU_CLASSIC: Record<일간(10), Record<월지(12), string[]>>` — 120셀 전부 채움(테스트로 완결성 검증).
  각 셀 = 우선순위 조후용신 천간 목록(한글). 예: 갑 사월 → `["계","정","경"]`.
  **서락오 정리 궁통보감(欄江網) 통용본 기준.** 판본·유파 이견 가능 → "참고용" 명시.
- `climaticClassicYongshin(dayGan, monthZhi, gans, zhis)` → `ClimaticClassicInfo`
  (priorityStems/Elements, presentStems, missingStems, primaryElement, satisfied, note, source).
- `assembleChart`에서 `yongshin.climaticClassic` 세팅. **기존 `climatic`(간이 화/수)은 불변** → 잠금 테스트 통과.
  `method`에 " + 궁통보감 조후" 부기.
- 테스트: `johuClassic.test.ts`(임 자월=무·병 spot-check, present/missing, climatic 공존 회귀 가드). 총 439 통과.
- ⚠️ **정확성 주의**: 120셀은 통용본을 전사한 것으로, 1순위 조후는 대체로 안정적이나 2·3순위·일부 셀은
  참고서마다 차이가 있을 수 있음. 실서비스 노출 전 명리 전문가 검수 권장(리스크 최상).

### 대면 상담 느낌 강화 · ⬜ 예정
`src/prompts/systemPrompt.ts`(및 필요 시 fortunePrompt): "직접 찾아가 상담받은 듯한" 톤/구성.
- 첫머리에서 사람을 먼저 읽어주는 도입, 상담사가 말 걸듯 이어가는 흐름, 되묻고 짚어주는 어조.
- 단, CLAUDE.md 규칙 유지: 겁주기·단정 금지, 생활 언어 우선, 근거는 detail에.

### 배선 + 테스트 + 검증 · ⬜ 예정
- `src/prompts/systemPrompt.ts`(근거 라인 빌더 ~353-388), `src/lib/compactEvidence.ts`,
  `src/components/SajuFactsPanel.tsx`에 새 필드 노출.
- 새 테스트: `sajuGyeokgukClassic.test.ts`, `hiddenTenGods.test.ts`, `sinsalClassic.test.ts`, `johuClassic.test.ts`.
  - `johuClassic.test.ts`는 기존 `yongshin.climatic.element` 잠금값이 그대로임을 **회귀 가드**로 assert.
- `docs/validation/saju-calculation-validation.md`에 단계별 주의 노트 추가.

## 커밋 전략
작게 쪼개서 각 Phase를 별도 커밋으로. 커밋 메시지는 한국어, 무엇을·왜를 명확히.
Vercel 배포 이메일: `daily.zia@gmail.com` (main 푸시 전 `git config user.email` 확인).
