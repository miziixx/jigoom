# Golden Test Cases — 사주 리딩 엔진 회귀 테스트

모델/프롬프트/룰 변경 시 리딩 품질이 퇴보했는지 자동 감지하는 결정론 회귀 테스트.

## 무엇을 비교하나

LLM 문장 전체를 고정하지 않는다. 계산→근거→룰→판단으로 나온 **JudgmentPack**만 비교한다.

- `BirthInfo + referenceDate → computeSajuChart → computeLuckCycles → buildReadingJudgmentPack`
- 이 경로는 **LLM 없이 항상 같은 결과**를 낸다 (결정론).
- 실제 LLM rewrite/fallback·문장 품질은 결정론 범위 밖 → 별도 optional 단계로 분리.

## 비교 기준 (허용범위 회귀검사)

| 기준 | 방식 |
|---|---|
| judgment codes | 필수(부분집합) / 금지(배타) — 무해한 추가는 통과 |
| domain coverage | 핵심 도메인 필수 + 최소 개수 |
| forbiddenClaims | `validateJudgmentPack.ok` (구조 결함 0) |
| confidence | 넓은 밴드 — 산식 급변만 감지 |
| contradiction | 알려진 집합 밖이면 실패 + 개수 상한 |
| rewrite/fallback | 구조상 rewrite 강제 안 됨(`structurallyValid`) |
| evidence ids | 안정적 핵심 id 소수만 필수 |

엄격한 snapshot이 아니라 **허용 범위를 둔 regression check**다. 미세 튜닝은 통과, 퇴보는 감지.

## 파일

- `goldenTypes.ts` — GoldenCase 스키마
- `goldenRunner.ts` — pack 생성 + 요약 + 검사 (순수, 계산 로직 미수정)
- `goldenCases.ts` — 21개 케이스 (실제 엔진 출력에서 도출)
- `golden.test.ts` — vitest 드라이버 + 네거티브 컨트롤

## 실행

```bash
npm test               # 전체
npx vitest run src/lib/goldenCases
```

## 엔진을 의도적으로 바꿔 기대값이 달라졌을 때

1. 실패한 케이스의 사유를 확인한다 (테스트가 누락 code/도메인/confidence 이탈을 그대로 출력).
2. 변경이 **의도된 개선**인지 리뷰한다. (룰이 조용히 죽은 게 아닌지 반드시 확인)
3. 맞으면 `goldenCases.ts`의 해당 기대값을 갱신한다. `summarizeJudgmentPack`으로 현재 요약을 확인할 수 있다.

## 하지 않는 것

- 계산 엔진(`saju.ts`), `eventEngine` 수정
- LLM 호출 / 실제 문장 스냅샷
- confidence 정확값 고정 (밴드만)
