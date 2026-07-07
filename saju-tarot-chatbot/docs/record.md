# 사주타로 챗봇 작업 기록

작성일: 2026-07-04

## 프로젝트

- GitHub 저장소: `miziixx/myapps`
- 작업 대상 앱: `saju-tarot-chatbot`
- 주요 목표: 사주/타로 웹앱을 더 깊고 이해하기 쉬운 리딩 서비스로 개선

## 지금까지 한 일

### 1. 사주 풀이 구조 개선

- 사주 계산 로직은 유지하고, 사용자에게 보이는 풀이 문장을 쉬운 생활 언어로 바꾸는 방향으로 정리했다.
- 전문 용어는 본문에 그대로 던지지 않고, `전문가 근거 보기` 영역에 보존하는 구조를 만들었다.
- 각 섹션을 다음 흐름으로 정리하도록 프롬프트를 강화했다.
  - 한 줄 결론
  - 쉬운 풀이
  - 왜 그렇게 보는지
  - 현실에서 나타나는 모습
  - 조심할 점
  - 활용 방법 / 보완 방법
  - 오늘 바로 할 수 있는 행동
  - 전문가 근거 보기
- 나이는 `마흔`, `쉰`, `아흔` 같은 한글 표현 대신 `40세`, `50세`, `90세`처럼 숫자로 쓰도록 규칙을 추가했다.

### 2. 사주 결과 속도와 완결성 개선

- 긴 사주 리딩을 한 번에 생성하지 않고 앞부분/뒷부분으로 나눠 병렬 생성하는 구조를 적용했다.
- 앞부분:
  - 첫 점괘
  - 질문 중심 핵심
  - 분야별 요약
  - 성격
  - 직업
  - 재물
  - 애정
- 뒷부분:
  - 건강
  - 인생의 큰 흐름
  - 올해의 흐름
  - 지금 해야 할 것과 피해야 할 것
  - 마지막 점괘
- 생성이 중간에 끊겼을 때 이어서 생성해 `마지막 점괘`까지 완결되도록 하는 구조를 유지했다.

### 3. 질문 답변 구조 개선

- 사용자가 사주 입력 시 질문을 쓰면 `질문 중심 핵심` 섹션에서 먼저 답하도록 했다.
- 이 섹션은 결과 초반, 첫 점괘 바로 아래 카드로 표시된다.
- 질문 답변은 단정 대신 선택 기준, 현실 신호, 바로 할 행동 중심으로 나오게 했다.
- 후속 질문은 최대 5개까지 가능하게 했다.

### 4. 사주 시각화와 결과 저장 기능

- 사주 원국, 오행, 흐름, 월별 실행 캘린더 등을 한눈에 볼 수 있도록 화면 구성을 강화했다.
- PDF 저장, 마크다운 저장, 이미지 ZIP 저장 방향을 잡고 기능 흐름을 반영했다.
- 챗봇에서 주고받은 내용도 저장 파일에 포함될 수 있도록 방향을 잡았다.

### 5. 월별/연간 흐름 개선

- 올해 1월부터 12월까지 모두 해석하도록 프롬프트를 강화했다.
- 월별 흐름을 `흐름 캘린더` 메뉴로 더 명확히 표현했다.
- 월별 실행 캘린더는 결과 상단에서 볼 수 있도록 유지했다.
- 상반기/하반기 리포트는 별도 상품보다는 `올해 운세 리포트` 안에 포함하는 방향으로 정리했다.

### 6. 건강/컨디션 풀이 개선

- 건강은 의학적 진단처럼 말하지 않도록 제한했다.
- 대신 생활 리듬, 컨디션, 스트레스가 몸에 나타나는 방식, 취약 부위 키워드 중심으로 표현하게 했다.
- 신체 키워드는 수면, 목·어깨, 소화, 체온·순환, 눈 피로, 허리·하체 등 생활 관리 관점으로만 다루도록 했다.

### 7. 궁합 기능 개선

- 궁합을 단순 점수 중심에서 관계 리포트 구조로 확장했다.
- 추가된 요소:
  - 관계 종합
  - 두 사람 원국 요약
  - 관계 핵심 카드
  - 일지 중심 관계 자리
  - 서로에게 어떤 존재로 느껴지는지
  - 관계 목적별 궁합
  - 시기 흐름
  - 조심할 반복 패턴
  - 오래 가는 운영법
  - 개선할 수 있는 방향
  - 전문가 근거 보기
- 관계 유형 선택을 추가했다.
  - 연인·배우자
  - 부모·자식
  - 형제·자매
  - 가족
  - 사장·직원
  - 동료·동업자
  - 친구
  - 앙숙·불편한 사람
- 선택한 관계 유형에 따라 문구와 조언이 바뀌도록 했다.

### 8. 타로 기능 개선

- 속마음 앱의 타로 상징 구조를 참고해 사주타로 챗봇에 이식했다.
- `tarotSymbolism.ts`를 추가했다.
- 카드별로 다음 요소를 리딩 근거에 포함한다.
  - 상징 원형
  - 상징 키워드
  - 그림 단서
  - 숫자/단계 의미
  - 슈트 의미
  - 관계 적용
- 타로 조합 진단을 추가했다.
  - 정방향/역방향 비율
  - 메이저 카드 비율
  - 반복 슈트
  - 시작 카드에서 마지막 카드로 이어지는 흐름 축
- 결과 화면의 뽑힌 카드 영역도 카드별 근거 그리드로 개선했다.

### 9. 메뉴 정리

- `오늘`과 `운세` 메뉴가 헷갈릴 수 있어 `오늘 운세`로 합쳤다.
- 기존 `/today` 주소는 `/fortune`으로 이동하도록 정리했다.
- `흐름` 메뉴는 `흐름 캘린더`로 이름과 설명을 바꿨다.

### 10. 개인정보/안전 안내

- 개인정보 안내 페이지를 만들고, 입력 폼과 푸터에서 접근할 수 있게 했다.
- 생년월일 원본은 AI로 보내지 않고, 브라우저에서 계산된 사주 결과와 질문만 전송한다는 방향을 명시했다.
- Anthropic 같은 외부 AI 제공자 안내를 투명하게 표현하는 방향으로 정리했다.
- 사주/타로 결과는 의학, 법률, 투자, 결혼, 이직 같은 중대한 결정의 단독 근거로 쓰지 않도록 안내했다.

### 11. 배포와 GitHub

- 여러 차례 커밋을 `main` 브랜치에 푸시했다.
- 주요 커밋:
  - `Remove unsupported Anthropic assistant prefill`
  - `Clarify late-night birth calculation basis`
  - `Prioritize question answers and improve compatibility view`
  - `Expand compatibility analysis factors`
  - `Add relationship contexts to compatibility`
  - `Clarify daily fortune and strengthen tarot readings`
  - `Port richer tarot symbolism`
- Vercel 배포 문제도 함께 확인했다.
  - 무료 배포 한도 초과 문제
  - 커밋 author email 문제
  - 배포 시간/커밋 반영 여부 확인 방법

### 12. 개인 생활 처방 추가

- 전체 사주 결과 상단에 `내 생활 처방` 카드를 추가했다.
- 계산된 오행 분포와 용신/희신 후보를 바탕으로 다음 항목을 보여준다.
  - 고유 색
  - 고유 숫자
  - 맞는 방향
  - 잘 맞는 장소
  - 자연 키워드
  - 운동
  - 건강 체크 포인트
  - 일하는 방식
  - 회복 루틴
- 물의 흐름이 부족한 사람에게 바다 배경화면, 물컵, 물가 산책을 제안하는 식의 재미있고 실생활에 바로 쓰는 미션을 추가했다.
- 결과 맨 아래에도 `마지막 생활 정리` 카드를 추가해 색·숫자·방향·장소·건강 체크·운동·바로 실행 3개를 다시 보여준다.
- 이 항목은 절대적인 행운 예언이 아니라, 사주에서 보완하면 좋은 흐름을 생활 선택지로 번역한 것이다.
- 마크다운 저장 파일에도 생활 처방 정보가 포함되도록 했다.
- AI 프롬프트의 근거 데이터에도 생활 처방을 넣어, 본문 조언에서 색·숫자·방향·장소·운동을 자연스럽게 활용할 수 있게 했다.
- 건강은 질병 진단이 아니라 머리, 눈, 간 피로감, 소화, 허리, 하체, 호흡 같은 컨디션 체크 키워드로 표현하도록 했다.

### 13. 궁합 입력 UX 정리

- 궁합 입력에서 출생 시간이 `시`만 들어가던 문제를 고쳐 `시간:분`을 함께 받을 수 있게 했다.
- 궁합 입력도 사주 명식 입력과 최대한 같은 방식으로 맞췄다.
  - 분 직접 입력
  - 23:00 전후 기준 선택
  - 출생지 보정 선택
  - 시간 모름 안내
- 기존 궁합 관계 유형 버튼이 너무 많아 화면이 복잡했으므로, 관계 유형 선택을 드롭다운으로 정리했다.
- 관계 유형에서 `앙숙·불편한 사람` 옵션은 제거했다.

### 14. 궁합 풀이 밀도 강화

- 궁합의 `관계 목적별 궁합`과 `세부 흐름`이 점수와 짧은 한 줄만 보여 너무 부족해 보이던 문제를 개선했다.
- 각 항목에 현실에서 나타나는 모습과 조율 방법을 추가했다.
- 점수 아래에 긴 설명과 행동 리스트가 카드 형태로 보이게 했다.
- 계산 점수 구조는 유지하고, 사용자에게 보이는 해석 밀도를 높였다.

### 15. 궁합에서 나/상대 구분 강화

- 궁합 입력 카드를 `나`와 `상대`로 명확히 나눴다.
- 결과의 두 사람 원국 요약도 `나`와 `상대` 배지로 표시한다.
- 두 카드의 색상과 테두리를 다르게 해서 누가 누구인지 바로 구분되게 했다.

### 16. 사주 원국 저장 설정 추가

- 사주 원국 입력 폼에 `이 사주 원국을 이 기기에 저장하기` 체크박스를 추가했다.
- 체크하면 입력한 생년월일시/성별/출생지/23시 기준이 브라우저 localStorage 프로필에 저장된다.
- 저장된 원국이 있으면 다음 조회 시 입력 폼에 자동으로 채워진다.
- 저장 체크를 끄고 조회하면 기존 저장 원국을 삭제한다.
- 서버 저장이 아니라 사용자 기기 브라우저 저장 방식이다.
- 체크한 상태에서 사주/흐름/오늘 흐름 리딩을 생성하면 해당 리딩도 `기록` 페이지에 자동 저장된다.

### 17. 궁합 보완 리포트 추가

- 궁합 결과가 여전히 점수와 짧은 요약 중심이라 사용자가 보기에는 뭉뚱그려지고 디테일이 부족하다는 피드백이 있었다.
- 계산 로직과 점수 산식은 유지하고, `computeCompatibility`의 해석 레이어에 `repairReport`를 추가했다.
- 궁합 결과 상단에 `관계 보완 리포트`를 새로 보여준다.
- 특히 점수가 낮거나 부딪힘 신호가 많은 관계일수록 보완 중심으로 더 자세히 나온다.
- 추가된 구조:
  - 관계 보완 헤드라인
  - 왜 이런 흐름이 생기는지
  - 갈등이 커지는 순서와 회복법
  - `나`, `상대`, `둘이 같이`로 구분한 조율법
  - 실제 대화 문장 예시
  - 하지 않는 편이 좋은 반응
  - 7일 조율 플랜
- 이 기능은 룰 기반 해석 레이어라 API 비용을 추가로 쓰지 않는다.
- 전문가 용어는 본문에 그대로 던지지 않고, 필요한 계산 근거는 기존 `전문가 근거 보기`에 남기는 방향을 유지했다.
- 관련 커밋: `6023716` `Deepen compatibility repair report`

## 검증한 것

- `npm test -- --run` 통과
- `npm run build` 통과
- 빌드 시 큰 번들 경고는 있었지만 실패는 아니었다.
- 사주타로 챗봇 쪽 작업 파일만 커밋했고, 옆 프로젝트 `sokmaeum` 변경분은 건드리지 않았다.

## 타로 리딩 응답 튜닝 (과한 답변 완화)

문제: 순수 타로 리딩(`type: "tarot"`)이 사주 원국 없이도 종합 사주풀이 프로필
(`DEFAULT_STANDARD_INSTRUCTION`, 11개 섹션·4200~5200자)을 그대로 적용받아,
카드로 뒷받침되지 않는 생애 전반·재물·연간 운세까지 채우면서 질문에 비해 답변이 과했다.

변경: `src/prompts/systemPrompt.ts`에 `TAROT_FOCUSED_INSTRUCTION` 추가.
- 순수 타로는 이제 항상(깊이 선택 여부 무관) 이 지시를 사용.
- 사주 기반 생애 섹션을 억지로 채우지 말라고 명시.
- 섹션을 `첫 점괘 / 질문 중심 핵심 / 카드가 그리는 흐름 / 지금 해야 할 것과 피해야 할 것 / 마지막 점괘`로 집중.
- 뽑힌 모든 카드와 조합 진단(정/역·메이저 비율·반복 슈트·흐름 축)을 근거로 하나의 이야기로 엮게 함.
- 분량 1800~2800자로 조정. 고위험 판단은 선택 기준으로만.
- 사주+타로 통합(`combo`)은 사주 근거가 있으므로 종전대로 종합 프로필 유지.
- `src/prompts/reading.test.ts`에 타로 전용 테스트 2개 추가.

## 오늘/흐름 리딩도 과한 답변 점검·정리

타로 튜닝 후 다른 리딩 종류도 같은 계열 문제가 있는지 전반 점검했다.
- `saju`/`combo`: 사주 근거가 있으므로 종합 생애 리딩 유지 (의도된 동작).
- `today`/`flow`: "간결하게 ~섹션 위주로"라는 약한 안내만 있고, 시스템 프롬프트는 11개 섹션 전부를
  요구해서, 오늘/흐름 질문에도 종합 생애 리딩이 붙어 과해질 수 있었다.
- `fortune`(오늘 운세): 고정 JSON 스키마라 과할 여지 없음 — 이상 없음.

변경(`src/prompts/systemPrompt.ts`):
- `today` 안내를 명시적 섹션 화이트리스트로 변경(첫 점괘 / 질문 중심 핵심 / 올해의 흐름(오늘·이번 주) /
  지금 해야 할 것과 피해야 할 것 / 마지막 점괘). 생애 섹션 배제. 1200~2000자.
- `flow` 안내를 명시적 섹션 화이트리스트로 변경(첫 점괘 / 질문 중심 핵심 / 올해의 흐름(1~12월) /
  인생의 큰 흐름 / 지금 해야 할 것과 피해야 할 것 / 마지막 점괘). 생애 섹션 배제.
- `src/prompts/reading.test.ts`에 today/flow 섹션 범위 테스트 2개 추가. (총 124 테스트 통과)

## 타로 근거 신뢰도 강화 — 엘리멘탈 디그니티(원소 조합 규칙)

타로 근거는 사주와 달리 "예측 적중"이 아니라 투명성·추적성·규칙성에서 신뢰가 나온다.
기존 조합 진단(정/역 비율·메이저 비율·반복 슈트·흐름 축)은 통계뿐이라, 전통 타로의
규칙 기반 근거를 하나 추가했다.

변경(`src/lib/tarotSymbolism.ts`):
- 슈트→원소 매핑: 완드=불, 컵=물, 소드=공기, 펜타클=흙, 메이저=별도.
- `elementalRelation`: 두 원소의 강화/약화/중립 판정.
  같은 원소·능동끼리(불-공기)·수용끼리(물-흙)=강화, 정반대(불-물, 공기-흙)=약화, 나머지=중립.
  메이저는 흐름을 압도하는 강한 카드로 보아 강화 처리.
- `describeElementalDignities`: 뽑힌 배열의 원소 분포 + 인접 자리 강화/약화 관계 +
  종합 판단(몰림/엇갈림/기복) + 중심·빠진 에너지를 근거 텍스트로 직렬화.

프롬프트(`src/prompts/systemPrompt.ts`):
- 타로 리딩 메시지에 `[원소 조합(엘리멘탈 디그니티) — 계산됨]` 근거 블록 추가.
- 카드 조합 해석 안내에 "강화=한 방향으로 실림 / 약화=힘이 부딪힘·샘, 중심·빠진 에너지를
  질문의 강한/약한 영역으로 연결하고 이 근거를 '왜 그렇게 보는지'·'전문가 근거 보기'에 명시" 지시 추가.

테스트: `src/lib/tarotSymbolism.test.ts` 신규(8개), 프롬프트 배선 테스트 추가. 총 132개 통과.

## 타로 근거 시각화 — TarotFactsPanel

카드→해석 추적성을 높이기 위해, 결과 상단에 있던 인라인 "뽑힌 카드" 그리드를
전용 컴포넌트 `TarotFactsPanel`로 승격하고 원소/디그니티 근거를 시각화했다.

- `src/components/TarotFactsPanel.tsx` 신규.
  - 카드별: 자리·정/역방향·슈트·원소(+뜻)·원형·핵심 상징.
  - 배열 근거 칩: 정/역 비율, 메이저 비율, 원소 분포.
  - 인접 자리 관계를 강화/약화/중립으로 색 구분해 리스트로 표시(strengthen=accent, weaken=red).
  - 중심 에너지/빠진 에너지 요약 문구.
- `src/components/ReadingResult.tsx`: 인라인 블록 제거하고 `<TarotFactsPanel>` 사용.
  더 이상 쓰지 않는 describeTarotSymbolism·tarotSuitOf import 정리.
- `src/index.css`: `.tarot-facts__*` 스타일 추가(칩/관계 리스트/에너지 요약, color-mix로 강화·약화 테두리).
- 테스트: `src/components/TarotFactsPanel.test.tsx` 신규(2). 총 135개 통과.

## 사주 풀이 섹션 간 내용 중복 방지

풀이 섹션들 사이에 같은 내용이 반복된다는 지적. 구조적 중복 지점을 점검하고
프롬프트에 `[중복 방지 — 섹션 담당 구분]` 규칙을 추가했다(`src/prompts/systemPrompt.ts`).

식별된 주요 중복:
- 직업과 돈 ↔ 재물 흐름 (돈 얘기가 양쪽에)
- 각 섹션 [오늘 바로 할 수 있는 행동] ↔ '지금 해야 할 것과 피해야 할 것' (행동 반복)
- 타고난 성격과 기질의 대인관계 ↔ 애정과 관계
- 인생의 큰 흐름 ↔ 올해의 흐름
- 분야별 요약 한 줄 ↔ 각 섹션 [한 줄 결론], [한 줄 결론] ↔ [쉬운 풀이] 첫 문장

적용한 레인 구분:
- 직업과 돈 = 일·커리어 (돈은 '버는 방식'만) / 재물 흐름 = 돈 관리·축적·소비만.
- 성격 섹션은 기질 중심, 구체적 관계 해석은 애정과 관계로 이관.
- 인생의 큰 흐름 = 여러 해 시기 구분 / 올해의 흐름 = 1~12월 세부.
- 각 섹션 행동은 고유 행동만, '지금 해야 할 것'은 복사 말고 우선순위·타이밍으로 통합.
- 분야별 요약 코멘트와 [한 줄 결론]은 다른 각도로, [한 줄 결론]을 [쉬운 풀이]에서 되풀이 금지.

깊이·근거는 그대로 유지(줄이는 게 아니라 반복만 제거). 테스트 1개 추가, 총 136개 통과.

## '오늘 써먹는 내 기운' 개인화 + 오늘(일진)화

기존 생활 처방(`lifestyleGuide.ts`)은 기준 오행 1개 → 5종 고정 테이블 매칭이라,
같은 기운이면 같은 문구 + 날짜와 무관(오늘 아님)했다. 두 축으로 강화:

더 개인화:
- 보조 기운(secondaryElement): 희신 첫 후보 → 없으면 두 번째로 약한 오행.
- 과하면 부담 기운(avoidElement): 기신 후보 반영, caution 문구에 균형 조언으로 삽입.
- 신강/신약을 basisReason에 반영("채우기보다 덜어내기" 등).
- 보조 기운의 대표 색·장소·운동을 기준 기운 목록에 섞어, 같은 기준이라도 사람마다 갈리게.

더 오늘화:
- `buildLifestyleGuide(chart, { todayGanZhi })` 옵션 추가.
- 오늘 일진 천간 오행과 내 보완 기운의 상생/상극으로 boost/temper/steady 판정.
  boost=필요 기운이 살아나는 날, temper=과열·소모 주의, steady=무난. 날짜마다 달라진다.
- headline/note/오늘 한 가지 행동을 관계에 맞게 생성. 단정적 길흉 금지.

배선: systemPrompt(근거 직렬화에 오늘 기운·보조·부담 추가), ReadingResult('오늘 써먹는 내 기운'
카드에 오늘 일진 블록·보조 기운 노출), exportMarkdown, index.css(오늘 블록 색상: boost 초록/
temper 주황/steady 보라). 테스트 `lifestyleGuide.test.ts` 신규(4). 총 140개 통과.

## 이름 감정(작명) 메뉴 추가 — 룰 기반 MVP

작명 기능을 '이름 감정'부터 시작(생성/추천은 한자 DB가 무거워 후속). 기존 사주 엔진 재사용.

- `src/lib/naming.ts` 신규 — 결정론적 계산:
  - 발음오행: 한글 초성 → 오행(목 ㄱㅋ / 화 ㄴㄷㄹㅌ / 토 ㅇㅎ / 금 ㅅㅈㅊ / 수 ㅁㅂㅍ),
    인접 음절 상생/상극 흐름 → 순조로움/무난함/다소 부딪힘.
  - 사주 궁합: buildLifestyleGuide의 보완 기운(basisElement)을 이름 소리가 담는지·상생하는지,
    기신으로 쏠리는지 → 좋음/보통/주의.
  - 수리(선택): 한자 획수를 주면 사격(원격·형격·이격·정격) + 81수 길흉 참고 계산.
  - evaluateName: 위 셋을 종합해 overall(좋음/보통/주의) + headline.
  - 단정 금지, "나쁜 이름" 표현 금지. 참고 자료 톤.
- `src/components/NamingResult.tsx`, `src/pages/NamingPage.tsx` 신규. BirthInfoForm 재사용.
- 라우트 `/naming`, 네비 '이름 감정', 랜딩 카드 추가. `src/index.css` 스타일.
- 테스트 `src/lib/naming.test.ts` 신규(7). 총 147개 통과. 브라우저로 폼·결과 렌더 확인.

후속 후보: (1) AI 해석 레이어(감정 근거를 문장으로), (2) 이름 생성/추천(인명용 한자 DB),
(3) 발음오행 학파 옵션(전통 vs 상용).

## 이름 감정 AI 해석 레이어 추가

룰 기반 이름 감정 계산 결과를 사용자가 이해하기 쉬운 리포트 문장으로 풀어주는 AI 해석 레이어를 붙였다.

- `api/naming.ts` 신규:
  - 기존 사주/타로 리딩 API와 분리된 이름 감정 전용 API.
  - 클라이언트에서 계산된 `NameEvaluation`만 받는다.
  - 생년월일 원본은 서버로 보내지 않는다.
- `src/prompts/namingPrompt.ts` 신규:
  - 발음오행, 사주 보완 기운, 수리 결과만 근거로 쓰도록 지시.
  - 제공되지 않은 한자 뜻, 자원오행, 획수 정보는 만들지 못하게 제한.
  - "나쁜 이름", "불행한 이름" 같은 단정과 공포 표현을 금지.
  - 출력 구조: 한 줄 결론 / 쉬운 풀이 / 현실에서 느껴지는 인상 / 보완하면 더 좋아지는 점 / 이름을 쓸 때의 팁 / 전문가 근거 보기.
- `src/lib/namingApi.ts` 신규:
  - `/api/naming` 호출과 오류 메시지 정리.
- `NamingPage`, `NamingResult`:
  - 계산 결과는 즉시 표시하고, AI 이름 해석 리포트는 별도 카드에서 로딩 후 표시한다.
  - API 실패 시 계산 결과는 유지하고 오류만 보여준다.
- 테스트 `src/prompts/namingPrompt.test.ts` 신규:
  - 단정 금지/근거 제한 규칙 확인.
  - 이름 감정 메시지에 생년월일 원본이 들어가지 않는지 확인.

## 후보 이름 비교 기능 추가

작명 확장 2단계로 후보 이름 여러 개를 한 번에 비교하는 기능을 추가했다.

- `src/lib/naming.ts`
  - `score`를 `NameEvaluation`에 추가했다. 사용자에게 절대 점수처럼 보이기 위한 값이 아니라 후보 정렬용 내부 기준이다.
  - `compareNames(chart, candidates)` 추가:
    - 후보별 `evaluateName` 실행
    - 사주 보완 적합도, 발음오행 조화, 선택 획수 수리까지 반영해 정렬
    - 추천 후보와 비교 요약 반환
- `src/pages/NamingPage.tsx`
  - 후보 이름 여러 개 입력 영역 추가.
  - 줄마다 `이름 | 성·이름 획수` 형식으로 입력 가능.
  - 획수를 모르면 이름만 입력해도 비교 가능.
  - 후보 비교가 입력되면 단일 이름 입력보다 후보 비교를 우선한다.
  - API 비용을 줄이기 위해 AI 해석은 추천 1순위 후보에만 생성한다.
- `src/components/NamingComparison.tsx` 신규:
  - 후보 순위, 추천 이름, 발음오행 흐름, 사주 보완 기운, 획수 참고를 카드로 표시.
- `src/index.css`
  - 후보 비교 카드와 모바일 반응형 스타일 추가.
- `src/lib/naming.test.ts`
  - 후보 비교 정렬 테스트 추가.

## 작명 발음오행 기준 옵션과 저장 기능 추가

작명 확장 3단계로 발음오행을 보는 기준 선택과 결과 저장 기능을 추가했다.

- 발음오행 기준 옵션:
  - `전체 이름 기준`: 성과 이름 전체의 초성 흐름을 본다. 기존 기본값이다.
  - `이름 중심 기준`: 3글자 이상 이름에서 성을 고정값으로 보고 이름 부분의 흐름을 더 본다.
  - 정답 학파를 단정하지 않고, 사용자가 어떤 기준으로 계산했는지 결과와 저장 파일에 표시한다.
- `src/lib/naming.ts`
  - `SoundElementSchool` 추가.
  - `analyzeNameSound`, `evaluateName`, `compareNames`가 기준 옵션을 받도록 확장.
  - `NameEvaluation`에 `school`, `schoolLabel` 저장.
- `src/pages/NamingPage.tsx`
  - 발음오행 기준 선택 토글 추가.
  - PDF 저장 버튼 추가. 브라우저 인쇄 기능으로 PDF 저장한다.
  - 마크다운 저장 버튼 추가.
- `src/lib/exportNaming.ts` 신규:
  - 이름 감정 결과, 후보 비교, AI 해석 리포트를 마크다운으로 저장.
- 테스트:
  - `src/lib/naming.test.ts`에 이름 중심 기준 테스트 추가.
  - `src/lib/exportNaming.test.ts` 신규.
  - `src/prompts/namingPrompt.test.ts`에서 발음오행 기준 전달 확인.

## 작명 목적 모드와 법적 확인 안내 추가

GPT 의견을 반영해 작명 기능을 용도별 리포트로 확장하되, 법적 등록 가능성이나 한자 DB 없는 뜻풀이를 단정하지 않는 안전 구조로 구현했다.

- 작명 목적 모드:
  - 아기 이름
  - 개명 이름
  - 예명·활동명
  - 상호명·브랜드명
- `src/pages/NamingPage.tsx`
  - 작명 목적 카드 선택 UI 추가.
  - 원하는 이미지, 피하고 싶은 발음/느낌, 목적 메모 입력 추가.
  - 입력 화면에 등록·법적 확인 안내 카드 추가.
  - 안내 내용:
    - 아기 이름·개명 이름은 실제 출생신고 또는 개명 신청 전 전자가족관계등록시스템/관할 기관에서 인명용 한자, 이름 글자 수, 동일 이름 등 등록 요건을 최종 확인해야 한다.
    - 예명·상호·브랜드명은 상표, 도메인, SNS 계정, 기존 사용 여부를 별도로 확인해야 한다.
- `src/lib/naming.ts`
  - `NamingMode`, `NamingPurpose`, `NAMING_MODE_LABEL` 추가.
  - `evaluateName`, `compareNames`가 목적 정보를 보존하도록 확장.
- `src/prompts/namingPrompt.ts`
  - 작명 목적, 원하는 이미지, 피하고 싶은 발음/느낌, 목적 메모를 AI 해석에 전달.
  - 법적 등록 가능성, 인명용 한자 해당 여부, 상표권·상호권 가능성은 확정적으로 말하지 못하게 제한.
  - 등록 가능 여부와 인명용 한자 여부는 최종 확인이 필요한 사항으로만 안내.
- `src/lib/exportNaming.ts`
  - 마크다운 저장 파일에 작명 목적과 법적 확인 안내 포함.
- 테스트:
  - 목적 정보가 이름 평가·비교·프롬프트·마크다운 저장에 보존되는지 확인.

법적 안전 원칙:

- 한자 DB가 없는 상태에서 한자 뜻, 자원오행, 인명용 한자 여부를 만들지 않는다.
- "법적으로 등록 가능"이라고 단정하지 않는다.
- 출생신고, 개명, 상표·상호 사용 가능성은 사용자가 공식 시스템/기관에서 최종 확인하도록 안내한다.

## 인명용 한자 데이터 도입 조사와 공식 확인 링크 추가

인명용 한자 DB를 바로 앱에 넣지 않고, 먼저 공식 출처와 안전 원칙을 정리했다.

- `docs/naming-hanja-data-plan.md` 신규:
  - 찾기쉬운 생활법령정보와 전자가족관계등록시스템 기준으로 현재 확인한 내용을 정리.
  - 앱 내부 DB를 만들기 전 필요한 출처/라이선스/갱신 절차 확인 항목을 정리.
  - 한자 뜻, 자원오행, 획수, 인명용 여부를 AI가 임의 생성하지 않는 원칙을 명시.
- 공식 확인 내용:
  - 생활법령정보: 자녀 이름에는 한글 또는 통상 사용되는 한자를 사용해야 하고, 인명용 한자 범위는 교육부 한문교육용 기초한자와 가족관계등록규칙 별표 1 한자에 따른다.
  - 생활법령정보: 인명용 한자가 아닌 한자가 포함되면 가족관계등록부에 이름이 한글로 기록될 수 있다.
  - 생활법령정보: 성을 제외한 이름자가 5자를 초과하면 출생신고가 수리되지 않는 제한이 있다.
  - 전자가족관계등록시스템: 고객센터에 인명용 한자 조회와 인명용한자표 PDF 다운로드 항목이 있다.
  - 전자가족관계등록시스템: 한자는 지정된 발음으로만 사용할 수 있고, 일부 초성 ㄴ/ㄹ 한자와 동자·속자·약자·부수 변형에 대한 주의사항이 있다.
- 앱 반영:
  - `NamingPage`의 등록·법적 확인 안내 카드에 공식 링크 추가.
  - 마크다운 작명 리포트에도 공식 확인 링크 포함.

현재 결론:

- 앱 내부 인명용 한자 DB 도입은 보류.
- 공식 PDF/별표 데이터를 앱에 복제·가공해도 되는지와 갱신 책임을 확인한 뒤 진행.
- 그 전까지는 공식 확인 링크 제공과 사용자 직접 획수 입력 방식만 유지.

## 작명 기능 마무리 — 후보 비교 AI 종합평과 이미지 ZIP 저장

작명 기능을 하나의 리포트 상품처럼 마무리하기 위해 후보 비교 전체를 AI 해석에 반영하고 이미지 ZIP 저장을 추가했다.

- 후보 비교 AI 종합평:
  - `api/naming.ts`, `src/lib/namingApi.ts`, `src/prompts/namingPrompt.ts`가 `NameComparison`을 함께 받을 수 있게 확장.
  - 후보가 여러 개면 프롬프트에 후보 순위, 종합 판정, 발음오행 흐름, 사주 보완 판정, 획수 참고를 함께 전달한다.
  - 출력 구조에 `후보 비교 종합평` 섹션을 추가해 추천 이름 하나만이 아니라 후보 전체를 비교해 설명하게 한다.
  - API 호출은 여전히 1회만 사용하므로 후보 수만큼 비용이 늘지 않는다.
- 이미지 ZIP 저장:
  - `src/lib/shareNamingImage.ts` 신규.
  - 작명 마크다운 리포트를 섹션별로 나눠 여러 장의 PNG 카드 이미지로 생성하고 ZIP으로 저장한다.
  - 각 이미지 하단에 `등록 가능 여부는 공식 시스템/기관에서 최종 확인` 안내를 넣는다.
  - `NamingPage`에 `이미지 ZIP 저장` 버튼 추가.
- 테스트:
  - `src/prompts/namingPrompt.test.ts`에 후보 비교 종합평 프롬프트 전달 테스트 추가.

## 챗봇 오류가 '[object Object]'로 뜨는 문제 수정

후속 챗봇에서 오류가 `[object Object]`로 표시됨. 원인: 서버/프록시가 error를 문자열이
아닌 객체로 반환할 때 `new Error(객체)`가 message를 "[object Object]"로 만들어 실제 원인을
가림. (`src/lib/readingApi.ts`)

- `serverErrorText(value, fallback)` 헬퍼 추가: 문자열이면 그대로, 객체면 message/error를
  꺼내고, 안 되면 JSON.stringify, 빈 값이면 fallback.
- 비정상 응답(!res.ok)과 스트림 error 라인 두 곳에서 이 헬퍼로 메시지를 뽑도록 변경.
- 이제 "[object Object]" 대신 실제 원인(예: 크레딧 부족·API 키·429·HTTP 상태)이 노출되어
  진단 가능. 테스트 3개 추가.

## 리딩 서버 함수 크래시(A server error has occurred) 수정

증상: 리딩 API가 Vercel FUNCTION_INVOCATION_FAILED("A server error has occurred")로 실패.
원인 추정: 생활 처방 개인화(249f90a)에서 `lifestyleGuide.ts`가 `./saju`를 import하면서,
API 함수 그래프(`api/reading.ts → systemPrompt → lifestyleGuide → saju`)에 무거운
`lunar-javascript`가 새로 딸려 들어옴. API는 원래 사주 계산을 하지 않는데(계산은 브라우저),
불필요한 무거운 의존성이 서버 번들에 유입됨.

수정: `lifestyleGuide.ts`에서 `./saju` import 제거하고, 필요한 작은 상수 표
(GAN_WUXING/ZHI_WUXING 한글 오행 매핑)만 인라인. 이로써 systemPrompt→lifestyleGuide 그래프가
saju/lunar를 더 이상 끌어오지 않아 API 번들이 가벼워짐. (150 테스트 통과)

교훈: `src/prompts/systemPrompt.ts`는 API 서버 함수가 import하므로, 여기서 도달하는 모듈은
브라우저 전용 무거운 계산 라이브러리를 끌어오면 안 된다.

## 상담형 사주 리포트 UX 1차 개편

AI 사주에 대한 사용자 불만은 "편하지만 중요한 고민 앞에서는 너무 뭉뚱그려진다"는 점으로 정리했다.
그래서 자동풀이 앱이 아니라 `근거 있는 사주 상담 리포트 + 선택 판단 도구` 쪽으로 UX와 프롬프트를 1차 개편했다.

변경:
- 홈 화면을 단순 메뉴 나열에서 핵심 진입 3개 중심으로 정리했다.
  - 내 사주 정밀 리포트
  - 지금 고민 상담
  - 궁합·관계 분석
- 사주 입력 폼을 두 단계로 나눴다.
  - `1 기본 정보`: 원국 계산에 필요한 정보
  - `2 지금 보고 싶은 것`: 관심사, 말투, 깊이, 질문, 상담형 입력
- 상담형 입력 확장 영역을 추가했다.
  - 고민 분야
  - 현재 상황
  - 고민 중인 선택지
  - 최근 1~3개월 실제 상황
  - 가장 두려운 결과
- 풀이 말투에 `행동계획 중심`을 추가했다.
- 프롬프트에 `상담형 판단 원칙`을 추가했다.
  - 사용자가 선택지와 실제 상황을 적으면 자동풀이처럼 넓게 말하지 않고, 질문의 판단 기준을 먼저 제시한다.
  - 선택지가 있으면 `[선택지 비교]`를 포함한다.
  - 최근 상황이나 두려움이 있으면 `[듣기 싫어도 봐야 할 부분]`을 포함한다.
- 프롬프트에 `흔한 말 감지` 규칙을 추가했다.
  - "신중하게 결정하세요", "무리하지 마세요", "변화를 준비하세요" 같은 문장을 그대로 쓰지 않게 했다.
  - 대신 무엇을 확인할지, 언제 기다릴지, 어떤 신호를 보면 움직일지, 오늘/이번 주/이번 달 무엇을 할지로 바꾸게 했다.

안전 원칙:
- 사주 계산 로직은 건드리지 않았다.
- 생년월일 원본을 AI로 보내지 않는 구조는 유지했다.
- 상담형 입력은 계산을 바꾸는 값이 아니라 해석 우선순위를 잡는 문맥 정보다.
- 이직, 퇴사, 투자, 결혼, 이별 같은 고위험 결정은 사용자가 직접 판단할 수 있게 기준을 주는 방식으로만 다룬다.

검증:
- 상담형 프롬프트 직렬화 테스트 추가.
- ContextPicker 상담형 입력 UI 테스트 추가.

## 사주 리딩 결과 순서 정리 — 총평 먼저, 디테일은 아래로

피드백:
- 리딩 완료 화면에서 사주 원국, 신살, 오행, 대운/세운 같은 디테일이 먼저 보여서 총평보다 계산 자료가 먼저 보였다.
- 정보량이 너무 많고 깊게 느껴져, 처음 보는 사용자는 어디부터 읽어야 하는지 헷갈릴 수 있었다.

변경:
- 결과 상단은 `요약 대시보드 → 첫 점괘 → 질문 중심 핵심 → 분야별 요약` 순서로 보이게 했다.
- 계산 근거 패널(`SajuFactsPanel`, `TarotFactsPanel`)은 총평과 목차 뒤로 내렸다.
- `자세한 풀이 목차`를 추가해 사용자가 필요한 섹션으로 바로 이동할 수 있게 했다.
- 긴 세부 풀이 섹션은 처음부터 모두 펼쳐 보이지 않고 접힘 영역으로 바꿨다.
- 정보량은 줄이지 않고, 첫 화면의 압박감만 줄이는 방향이다.

유지한 것:
- 사주 계산 로직 변경 없음.
- AI 프롬프트의 깊이와 근거 보존 구조는 유지.
- 전문 근거는 기존처럼 보존하되, 사용자가 먼저 봐야 하는 총평보다 아래에 배치.

## 현재 제품 방향

앱의 핵심 방향은 다음과 같다.

- 계산은 정확하게
- 본문은 쉽게
- 근거는 전문가용으로 보존
- 질문에는 먼저 답하기
- 리포트는 PDF/마크다운/이미지로 저장 가능하게
- 무료 맛보기로 신뢰를 만들고, 유료 리포트로 깊이를 제공하기

## 이름 감정 메뉴에 이름 추천 탭 추가

이름 감정 페이지(`/naming`)에 `이름 감정 / 이름 추천` 탭 토글을 추가.

- **결정론적 근거**: `lib/naming.ts`의 `buildNamingBrief(chart)`가 사주에서 보완하면 좋은 기운
  (`buildLifestyleGuide` 기반)과 그에 어울리는 초성(발음오행)·상생 기운·피할 기운을 계산.
  계산은 여기서 끝내고 실제 이름 후보 생성은 이 브리프 안에서만 AI가 하게 함(프로젝트 철학
  `calc → evidence → AI` 유지).
- **AI 추천**: `prompts/namingPrompt.ts`의 `NAMING_RECOMMEND_SYSTEM_PROMPT` /
  `buildNamingRecommendMessage`. 성·성별·글자수·이미지 조건과 사주 보완 근거를 전달하고
  한글+한자 뜻 후보를 제안. 단, 인명용 한자·획수·중복·상표는 별도 확인 안내(단정 금지).
- **API**: `api/naming.ts`가 `mode: "recommend"`를 분기 처리(기존 감정은 `evaluate`).
- **클라이언트**: `lib/namingApi.ts`의 `generateNameRecommendations`, `pages/NamingPage.tsx`
  탭/폼/결과 렌더.
- 테스트: `naming.test.ts`, `namingPrompt.test.ts`에 브리프·추천 프롬프트 케이스 추가
  (162 테스트 통과, build 성공).

## 궁합 결과 밀도 개선 & 중복 근거 정리

사용자 피드백: 궁합 세부 항목이 "애매하고 내용이 부족"하고, 점수 숫자가 낮게 뜨면
설명 톤과 따로 놀아 불안해 보임. 또 중간 "근거" 카드가 위 게이지 문구를 그대로 반복.

- **숫자 → 상태 라벨**: `Gauge`에 `tierLabel` 옵션 추가. `tierWord(score)`로
  잘 맞아요/무난해요/조율이 필요해요 라벨을 궁합 게이지에만 노출(다른 화면은 숫자 유지).
  "설명 없는 숫자 지양" 원칙과 일치.
- **밀도 강화**: `CompatibilityResult.breakdown`/`purposeFits`에 `signal` 필드 추가.
  각 항목에 "이럴 때 드러나요"(구체적 상황) 한 줄 + detail을 더 실용적으로 확장.
- **종합 요약 구체화**: 세부 점수 중 가장 강한 축·조율 필요한 축을 요약 문장에서 직접 짚음.
- **중복 제거**: 항상 보이던 평문 "근거" 카드(게이지 note·일지 형파해 날것 용어 반복) 삭제.
  전문가 근거는 하단 접이식 `전문가 근거 보기`로 일원화.
- 테스트: `sajuFeatures.test.ts`에 signal·요약 축 검증 추가, 기존 용어 노출 검사 유지.
- **7일 조율 플랜 제거**: 다른 세션이 `Deepen compatibility repair report`(origin/main)로 추가한
  `repairReport.sevenDayPlan`(7일 조율 플랜)을 사용자 요청으로 삭제. 타입·`compatibilityRepairReport`
  반환·CompatibilityPage 렌더·CSS(`compat-plan-list`)·테스트·문서(CLAUDE.md, next_steps.md) 참조 정리.
  `관계 보완 리포트`의 나머지(대화 예시·하지 않는 편이 좋은 반응 등)는 유지.
- 통합: 이 밀도 개선은 origin/main(다른 세션의 궁합 보완 리포트 포함) 위로 리베이스해 함께 반영.

## AI 결과 재사용 캐시 (일관성 + 비용 절감)

사용자 피드백: 같은 원국인데 리딩을 돌릴 때마다 API를 새로 불러 결과가 매번 달라지고
토큰 비용도 든다. → 입력 기준 결과 캐시를 추가.

- `src/lib/resultCache.ts`: localStorage 기반. 키는 입력 페이로드를 키순서 무관 안정 직렬화 후
  해시. 날짜 의존 흐름이 오래 고정되지 않도록 키에 기간 버킷(오늘=일, 그 외=월)을 섞음. LRU 정리.
- 리딩(`useReadingStore.startReading`): 같은 (type+원국+질문+포커스+타로카드+버킷)이면 저장된
  결과를 재사용(스트리밍/API 생략). `forceRegenerate`와 `regenerateCurrent()` 추가.
- `ReadingActions`에 "🔄 다시 생성" 버튼(원국 있을 때). 이름 추천에도 캐시 + "🔄 다시 생성".
- 이름 감정 AI 해석도 (평가결과+비교) 기준 캐시.
- 테스트: `resultCache.test.ts`(169 통과). 이름 API 실제 원인은 ESM 확장자 누락이었고 별도 수정.

## 이름 추천 구조화 (실제 이름 앞세우기 + 점수표/TOP5)

사용자 피드백: 추천 탭이 "방향 설명" 위주로 나오고 실제 이름이 뒤로 밀린다. 유료 상품으로
가려면 후보 개수·점수표·TOP 심층이 필요하다.

- **역할 분리**: AI는 이름 후보만 뽑고(점수·순위 금지), 점수는 사주 차트로 결정론적으로 계산.
  `namingPrompt.ts`의 추천 프롬프트를 JSON 출력(`{ direction, candidates:[{name,hanja,hanjaMeaning,sound,image}] }`)
  으로 변경. `name`은 성 제외 이름 부분, 성은 시스템이 붙임.
- `naming.ts` 추가: `parseRecommendedNames`(잡음/코드펜스 허용 JSON 파서), `namingDisplayScore`
  (사주 보완+발음 조화 → 40~99점 환산, AI가 지어낸 점수 아님), `scoreRecommendedNames`
  (성 결합·`evaluateName` 채점·중복 제거·내림차순 정렬·rank 부여).
- 후보 개수 6 → 24(`RECOMMEND_COUNT`). `api/naming.ts` `MAX_TOKENS` 3000→4500,
  추천 응답엔 truncation 안내 문구 미부착(JSON 파싱 보호).
- `NamingRecommendResult.tsx`: 방향 요약 + 전체 점수표 + TOP5 상세 카드(한자 뜻·소리 근거·인상·적합도).
  파싱 실패 시 기존 `<pre>` 평문 폴백 유지.
- 캐시 네임스페이스 `naming-recommend` → `naming-recommend-v2`로 올려 구 형식 무효화.
- 테스트: `naming.test.ts`에 파싱/채점/정렬 검증 추가(173 통과), build OK.
- 남은 과제(유료화): 무료/유료 게이팅(무료 3개·유료 전체), "피해야 할 이름" 전용 섹션,
  인명용 한자 DB 실검증.

## 결과 화면 시각 대시보드 (카드·그래프로 가독성)

사용자 요청: 글만 긴 결과가 안 읽힌다 → 카드·도표·그래프를 얹어 가독성 강화. 단 기존 내용/항목은
하나도 줄이지 않는 순수 추가(additive) + 순서 재배치.

- 신규 룰 `src/lib/readingDashboard.ts`(무 API, 결정론): `buildReadingDashboard(chart, luck)` →
  강점/주의점 3개씩, 키워드 칩, 기질 스펙트럼 4축(직관↔분석/즉흥↔신중/표현↔내면/관계↔독립),
  인생영역 6개 상대 막대(성향/일/재물/관계/멘탈/흐름). 오행 분포·십성·신강신약에서 도출.
  점수는 "상대 경향+라벨"이며 절대 진단 아님(CLAUDE.md 준수). 막대·축마다 한 줄 해석.
- 신규 컴포넌트: SummaryCardGrid(요약 히어로), PersonalitySpectrum, LifeAreaBars,
  ActionChecklist(오늘/이번주/피할 패턴 체크박스).
- ReadingResult.tsx 순서 재배치(내용 삭제 없음): 요약 대시보드 → 바로 보는 요약 → 스펙트럼/인생영역 →
  타로 → 상세 해석 섹션 전부 → 실행 체크리스트 → 생활 정리 → 하단 접이(details) "계산 근거·시각 자료"로
  SajuFactsPanel(원국·신살·타임라인·계산값 전부)+PatternMap+EvidenceConfidence 이동.
- 모바일 안전(index.css): 2×2 그리드 auto-fit→좁으면 1열, 넓은 도표 overflow-x:auto, 버튼 wrap+44px,
  overflow-wrap:anywhere, 컨테이너 min-width:0. Playwright 360/390/768px 검증 → 가로 스크롤 없음.
- 테스트: readingDashboard.test.ts 추가(179 통과), build OK.

## 나머지 메뉴 시각/모바일 통일 (타로 히어로 + fortune·compat 하드닝)

확인 결과 대부분 화면은 이미 시각화돼 있었음: combo·flow는 ReadingResult 공유로 대시보드 자동 적용,
오늘 운세(FortuneResult)·궁합(CompatibilityPage)은 이미 히어로·게이지·카드·근거접이 구조. → 재구성 대신
일관성+모바일 통일 패스만 수행.

- 신규 `TarotSummaryHero.tsx`: 타로는 사주 대시보드가 없어, 뽑은 카드의 정/역방향 비율 바 + 중심/빠진
  에너지 칩 + 방향 비율 기반 한 줄 메시지를 상단 히어로로. 계산은 tarotSymbolism 재사용(새 계산 없음).
  ReadingResult에서 tarotCards가 있을 때 TarotFactsPanel 위에 렌더.
- index.css 모바일 하드닝(오늘 운세·궁합): .fortune-result/.compat-result에 min-width:0 +
  overflow-wrap:anywhere, 이미지 max-width, 게이지 max-width, 480px에서 fortune-category-grid/
  compat-highlight-grid/compat-advice-grid/compat-deep-list 1열, lucky-item min-width:0, fortune-two 스택,
  액션 버튼 wrap+44px. 타로 히어로 CSS 추가.
- 검증: Playwright 360/390/768px로 오늘 운세·궁합·타로 렌더 → 전부 가로 스크롤 0, 게이지/카드/칩 정상.
  test 179 통과, build OK.

## 원국·신살·월별 상단 복구 + 대운 가독성 (사용자 피드백 반영)

이전 커밋에서 SajuFactsPanel(원국·신살·오행·대운/세운·1~12월 흐름)을 하단 접이로 옮긴 게 "없앤 것"처럼
보인다는 피드백. 사용자는 원국·신살·월별을 맨 위에서 바로 보길 원함(사람들이 그 시각 자료를 좋아함).

- ReadingResult 순서 복구: 하단 접이(reading-evidence-zone) 제거하고 SajuFactsPanel을 다시 상단 노출.
  PatternMap·ActionCalendar·EvidenceConfidence도 접이 밖으로 꺼내 원래대로 보이게. 요약 대시보드/스펙트럼/
  인생영역/타로 히어로 등 신규 요소는 유지(아무것도 삭제 안 함).
- 대운 가독성: DaYunTimeline 각 pill에 천간 오행 기반 기운 라벨(성장기/표현기/안정기/정리기/사색기) 추가.
- 검증: Playwright 390px — 원국 top(290px)·신살(810)·대운 라벨 8개·1~12월 흐름 전부 상단 노출, 가로 스크롤 0.
  test 179 통과, build OK.

## 월별 풀이 카드화 + 이름추천 잘린 JSON 복구 (사용자 피드백)

- 월별 풀이 가독성: "올해의 흐름 → 쉬운 풀이"의 1~12월이 문단 벽으로 나오던 문제. parseMonthlyFlow로
  일반화("N월 — 키워드:… 조언:…" 및 "N월, 키워드는 … 한 줄 조언: …" 두 형식 지원), 어느 파트든 월별
  나열(≥3개, 키워드/조언 구조 有)이면 month-evidence-grid 카드로 렌더. 중간 설명은 body로 보존(내용 안 버림).
  조언은 라벨+구분선으로 강조. 3열/2열/1열 반응형.
- 이름추천 raw JSON 노출 버그: 후보 JSON이 max_tokens로 잘리면 parseRecommendedNames가 null →
  평문 폴백이 잘린 raw JSON을 그대로 노출. parseRecommendedNames를 견고화: 통짜 파싱 실패 시 완성된
  후보 객체({…"name"…})만 정규식으로 회수하고 direction도 별도 추출 → 잘려도 카드로 렌더. api/naming
  MAX_TOKENS 4500→8000으로 truncation 자체도 완화. 테스트 추가(180 통과), build OK.

## 올해의 흐름 월별 카드 고정 포맷 (파싱 신뢰도 개선)

사용자 피드백: "올해의 흐름"이 그냥 달별 텍스트 문단으로 나오는 것 같다. 원인 확인 결과, AI가
자유 산문으로 쓰고("N월 — 키워드: X. 조언: Y") 프론트 정규식(`parseMonthlyFlow`)이 이를 다시 파싱해
카드로 바꾸는 구조였는데, 모델이 문구를 정확히 안 지키면 파싱이 통째로 실패해 평문으로 떨어졌다.
또한 파서가 키워드·조언만 뽑고 기회·조심할 점은 구분 없이 한 덩어리(`body`)에 뭉개고 있었다.

- `systemPrompt.ts`의 `# 올해의 흐름` 지시를 고정 포맷으로 강제: 도입부는 산문 1~2문단 유지,
  그 다음 1~12월은 반드시 `N월 | 키워드: … | 기회: … | 주의: … | 조언: …` 한 줄씩. 각 필드는
  "1문장 강제"가 아니라 "1~2문장, 왜 그런지까지"로 지시해 정보량을 줄이지 않음. `|` 구분자는
  마침표 기준으로 자르던 기존 정규식과 달리 필드 안에 문장이 여러 개 있어도 안 잘림.
- `ReadingResult.tsx`: `parseMonthlyFlow`를 고정 포맷 파서(1차) + 기존 산문 파서(2차, 과거 저장된
  리딩 호환용 폴백)로 재작성. `MonthEvidence`에 `opportunity`(기회)/`caution`(주의) 필드 추가,
  카드에 기회(초록)/주의(호박색)/조언(파랑) 3줄을 색으로 구분해 표시.
- 모바일 안전성: `.month-evidence-card`의 고정 `min-height` 제거(내용에 맞춰 자동 확장),
  텍스트 줄바꿈 처리 추가. 실제 `<table>`은 안 쓰고 반응형 카드 그리드 유지(3열→2열→1열).
- 테스트: `ReadingResult.test.tsx`에 새 포맷 + 구 포맷 폴백 케이스 추가(181 통과), build OK.
  Playwright로 데스크톱/375px 모바일 렌더 확인 — 가로 스크롤/텍스트 잘림 없음.

## 결과 화면 재배치 + 진짜 로딩 진행률

사용자 피드백: 계산 기반 위젯 7개(SajuFactsPanel·SummaryCardGrid·InstantSummary·PersonalitySpectrum·
LifeAreaBars·PatternMap·ActionCalendar)가 전부 맨 위에 쌓여 있고, 그 아래 AI 프로즈는 시각 요소
없이 텍스트만 쭉 이어져 "위는 과하고 아래는 힘이 빠진다"는 느낌. 같은 오행/신강약 근거가 최대
8곳에서 반복 노출되고, 월별 흐름도 SajuFactsPanel 원시 그리드·ActionCalendar·AI 카드 3곳에서
중복. 로딩 배너(`LoadingNotice`)의 3단계 스텝도 실제 진행과 무관하게 항상 마지막 칸만 켜지도록
하드코딩돼 있어 "느리다"는 피드백의 한 원인이었다(실제 생성 시간 자체는 하드코딩된 지연이 아님).

- **위젯 재배치**: 최상단은 4개로 축소(SajuFactsPanel → SummaryCardGrid → InstantSummary →
  EvidenceConfidence). PersonalitySpectrum·LifeAreaBars·PatternMap·ActionCalendar는 "분야별 요약"
  바로 뒤, AI 본문 섹션이 시작되기 직전으로 이동해 위/아래 사이 시각적 완충 지대를 만듦.
  **주의(다음 세션 참고)**: 특정 AI 섹션 제목이 스트리밍으로 등장했을 때만 위젯을 끼워 넣는
  방식을 처음 시도했으나, 그러면 원래 즉시 뜨던 계산 위젯이 그 섹션이 나올 때까지 늦게 뜨는
  회귀가 생겨서 되돌림. 지금은 `sajuChart`/`luckCycles` 존재 여부로만 조건을 걸어 AI 스트리밍
  진행과 무관하게 항상 즉시 렌더되고, 위치만 아래로 옮긴 상태.
- **월별 그리드 중복 정리**: `SajuFactsPanel`의 "올해 1~12월 흐름" 원시 그리드(간지+4단계 라벨만
  있는 가장 raw한 버전)를 `<details>` 접이식으로 감싸 기본은 닫힌 상태로 변경(summary: "월별 흐름
  계산값 보기"). 데이터는 삭제하지 않았고, 더 읽기 쉬운 버전(ActionCalendar 행동 추천, AI
  "올해의 흐름" 카드)은 그대로 펼쳐서 보임.
  **주의(다음 세션 참고)**: 이전에 "SajuFactsPanel 전체(원국·신살·오행·대운/세운·1~12월 흐름)를
  하단 접이로 옮겼다가 사용자가 '없앤 것처럼 보인다'는 피드백으로 상단에 복구"한 이력이 있다
  (위 "원국·신살·월별 상단 복구" 항목 참고). 이번 변경은 SajuFactsPanel 전체가 아니라 그 안의
  월별 그리드 하위 항목 하나만 접은 것이고, SajuFactsPanel 자체(원국·신살·오행·대운·세운·10년
  흐름)는 여전히 상단에 그대로 펼쳐져 있다. 다만 과거에 이 영역을 숨기는 것에 사용자가 민감하게
  반응한 이력이 있으므로, 만약 이번에도 "월별 계산값이 안 보인다"는 피드백이 오면 이 `<details>`를
  다시 펼침 상태로 되돌릴 것.
- **진짜 로딩 진행률**: `LoadingNotice`의 가짜 3단계 스텝을 제거하고, 신규 `src/lib/readingProgress.ts`
  (`buildReadingProgress`)로 실시간 스트리밍 텍스트에 등장한 `# 섹션명` 개수를 세어 실제 퍼센트 바 +
  "N/전체 · 지금 쓰는 중: OO" 텍스트로 교체. 리딩 타입(saju/combo/tarot/today/flow)별로 기대 섹션
  목록이 다르므로 타입별 상수를 별도 유지(서버 전용 `systemPrompt.ts`와 동기화 필요, 클라이언트
  번들에 직접 import 불가). 경과 시간 타이머 추가. 진행률 계산은 **최초 리딩 생성일 때만**
  (`session.messages.length <= 2`) 켜고, 후속 질문 응답(`#` 섹션 형식을 안 씀)이나 세션 생성 전
  (계산 대기 중) 페이지에서는 경과 시간 + 안내 문구만 표시.
- 테스트: `readingProgress.test.ts` 신규(섹션 매칭/조건부 섹션 스킵/괄호 헤더 대응 등 6개),
  전체 187 통과, build OK. Playwright로 위젯 순서(DOM 트리 조회)·`<details>` 기본 닫힘 상태·
  로딩 배너 퍼센트 계산·데스크톱/375px 가로 스크롤 없음을 확인.

## 목차 링크 빈 화면 버그 수정 + 계산 위젯 재접이 (사용자 피드백)

사용자 피드백 두 가지: (1) 리딩 목차를 클릭하면 빈 화면이 뜬다, (2) 사주 리딩 전체에 요소가
너무 많고 보기 편하지 않다.

- **목차 빈 화면 버그**: 원인은 `HashRouter`. `ReadingTableOfContents`가 `<a href="#reading-...">`를
  써서, 클릭 시 페이지 내 스크롤이 아니라 `location.hash`가 통째로 바뀌어 라우터가 존재하지 않는
  경로로 이동 → 매칭되는 Route 없음 → 빈 화면. `<a>`를 `<button>`으로 바꾸고 `document.getElementById`
  + `el.open = true` + `scrollIntoView`로 직접 처리하도록 수정.
- **계산 위젯 재정리**: 20곳 이상의 실제 사주 서비스(포스텔러/점신/헬로우봇/마이파이/정관명리 등)를
  조사한 결과, 대부분 "짧은 요약 먼저 → 계산 상세는 접거나 별도 화면"으로 가고, 모든 걸 한 화면에
  펼치는 점신의 "운세보고서"는 오히려 반면교사 사례(후기에서 "뻔하다" 지적)였다. 이를 근거로
  `LifeAreaBars`·`EvidenceConfidence`·`InstantSummary`·`TarotFactsPanel`·`SajuFactsPanel`(원국 4기둥
  제외)·`PersonalitySpectrum`·`PatternMap`·`ActionCalendar`를 신규 `CalculationEvidenceZone`
  (`<details className="reading-evidence-zone">`, 기본 닫힘, summary "계산 근거 자세히 보기")
  하나로 묶어 목차와 AI 본문 섹션 사이에 배치. 데이터는 하나도 삭제하지 않았고 접었을 뿐이다.
  - **중요 — 위 "원국·신살·월별 상단 복구" 항목 참고**: 이 정확히 같은 종류의 변경(SajuFactsPanel을
    접어서 내림)을 예전에 시도했다가, "원국이 없어진 것처럼 보인다"는 피드백으로 되돌린 이력이
    있다. 이번엔 그 이력을 사용자에게 다시 확인시켰고, 절충안으로 **사주 원국 4기둥(연주/월주/
    일주/시주) 박스만 `SajuPillarSnapshot`(신규, `SajuFactsPanel.tsx`에서 named export)으로 분리해
    항상 최상단에 노출**하고, 나머지(신살/오행그래프/음양/강도게이지/대운타임라인/세운10년/
    월별그리드/계산값 상세)만 접힌 영역 안으로 옮겼다. `SajuFactsPanel`에 `showPillars?: boolean
    = true` prop을 추가해 접힌 영역 안에서는 `showPillars={false}`로 호출, 4기둥 중복 렌더를 막음.
  - `TarotSummaryHero`(타로 한 줄 헤드라인)는 접지 않고 밖에 유지: 사주 없는 순수 타로 리딩에서
    AI 텍스트가 나오기 전 유일한 즉시 요약이기 때문. `TarotFactsPanel`(카드별 근거)만 접힌 영역 안.
  - 변경 후 순서: 요약 대시보드 → (타로 헤드라인) → 원국 4기둥 → 첫 점괘 → 질문 답변 → 분야별
    요약 → 목차 → [접힌 계산 근거] → AI 본문 섹션(기존처럼 `<details>` 접힘) → 마지막 점괘 →
    실행 체크리스트 → 생활 정리.
- 테스트: `ReadingResult.test.tsx`에 순서 검증 테스트 2개 추가(원국 스냅샷 < 목차 < 접힌 영역 <
  본문 섹션, 4기둥 중복 없음 확인 / 타로 헤드라인 < 접힌 영역 < 카드별 근거), 전체 197 통과, build OK.
  Playwright로 실제 세션(로컬스토리지 시드) 렌더 확인: 원국 4기둥 상단 노출, 접힌 영역 기본
  닫힘→클릭 시 정상 펼침, 목차 클릭 시 해당 본문 섹션만 정확히 열림, 모바일 390px 가로 스크롤 없음.

## 명리 엔진 고도화 1단계 — 사건화 엔진 (직업/돈/연애/건강/가족/이사/창업)

감사 피드백: 기존 계산은 "성향"까지는 잘 번역하지만 "어느 분야에서 지금 어떤 사건이
움직이는가"를 규칙으로 연결하지 못하고 LLM에 통째로 맡김. → 계산값을 분야별 현실 사건
신호로 연결하는 규칙 엔진을 추가(사용자 확정 로드맵 1번). 무 API·결정론.

- 신규 `src/lib/eventEngine.ts` (`buildEventForecast(chart, luck, gender)`):
  - 원국 십성(천간+지지 정기) 파싱 → 그룹(비겁/식상/재성/관성/인성)별 카운트.
  - 십성 그룹 → 분야 매핑(재성=돈·연애·직업, 관성=직업·연애, 인성=이사·직업·가족,
    식상=창업·직업·연애, 비겁=돈·창업·가족). 성별 반영(남명 재=이성 / 여명 관=배우자).
  - 대운·세운·월운 간지의 십성(인라인 tenGodOf) → 해당 분야 "활성" 가중(세운2/대운1.5/월운1).
  - 원국·운의 합충형파해를 궁위(연/월/일/시)와 연결 → 그 자리가 상징하는 분야 활성(충/삼합 가중↑).
  - 분야별 활성도 high/mid/low + 쉬운 말 사건 패턴 + 타이밍 신호 + 조심 신호 + 전문가 근거(evidence).
  - 표면 문구는 전문용어 배제, evidence만 십성·궁위·충합 용어 보존(CLAUDE.md 준수). 단정/공포 금지.
  - saju.ts를 import하지 않음(lunar가 서버 번들에 딸려오는 것 방지, lifestyleGuide와 같은 원칙).
    필요한 오행표·지장간 정기·tenGodOf를 인라인.
- 타입: `src/types/index.ts`에 `LifeDomain`/`EventActivation`/`EventScenario`/`EventForecast` 추가.
- 프롬프트 배선(`src/prompts/systemPrompt.ts`): `formatEventForecast`로 근거 블록 직렬화,
  원국 있는 리딩(tarot 제외)에 `[분야별 사건 신호 — 계산됨]` + 활용 안내 추가.
  안내: 활성 분야 우선·구체화, 목록 밖 사건 창작 금지, 평이 분야는 담담히, 용어는 근거 영역에만.
- UI: 신규 `EventForecastPanel.tsx` — "지금 움직이는 분야" 카드. 활성(high/mid) 분야 강조 그리드 +
  전체 분야 접이. ReadingResult 요약 영역(원국 스냅샷 아래)에 원국 있을 때 렌더. index.css 스타일 추가.
- 다음 단계: 활성도를 activation/benefit/risk 점수로 확장(로드맵 3번), 과거 사건 검증 보정(2번).
- 테스트: `eventEngine.test.ts`(6), `EventForecastPanel.test.tsx`(3), `reading.test.ts` 배선 1개 추가.
  전체 217 통과, build OK. API 번들에 lunar 미유입 확인(eventEngine은 타입만 import).

## 명리 엔진 고도화 2단계 — 과거 검증 기반 리딩 보정

로드맵 2번: 사용자가 실제 과거 사건(예: 2021년 이직)을 입력하면, 그 해 세운·대운 흐름이
그 분야와 계산상 부합하는지 판정해 이번 리딩의 해석 신뢰도를 보정한다. 무 API·결정론.

- 타입(`src/types/index.ts`): `PastEvent`(연도·분야·메모), `PastEventCalibrationInput`(그 해
  세운/대운 간지+상호작용), `PastEventMatch`(strong/partial/weak+요약+근거), `PastValidationReport`.
  `ReadingContext.pastEvents` 추가.
- 계산층(`src/lib/saju.ts`): `computePastEventCalibrationInputs(birthInfo, events)` —
  각 사건 연도의 세운 간지(입춘 기준 6/15), 그 시기 대운 간지, 원국과의 상호작용(luckVsNatal 재사용)을
  순수 데이터로 계산. 계산은 브라우저에서, API로는 결과 값만 전달(계산/보안 원칙).
- 판정층(`src/lib/pastValidation.ts`, saju.ts 미import): eventEngine의 매핑(GROUP_DOMAINS·groupOf·
  tenGodOf·ZHI_MAIN_STEM·DOMAIN_LABEL export)을 재사용. 세운/대운 십성이 그 분야에 맞는지 +
  상호작용 강도로 strong/partial/weak 판정. 표면은 쉬운 말, 근거만 십성·간지 보존. 단정 금지.
- eventEngine.ts: 재사용 위해 `tenGodOf`/`groupOf`/`GROUP_DOMAINS`/`DOMAIN_LABEL`/`positionDomains`/
  `ZHI_MAIN_STEM_TABLE`/타입(`TenGodGroup`/`PositionLabel`) export.
- 프롬프트(`systemPrompt.ts`): `ReadingFacts.pastValidation` 추가, `formatPastValidation` 직렬화,
  `[과거 사건 검증 — 계산됨]` + 활용 안내(잘 맞은 축 자신 있게, 약한 축 조심스럽게, 과거로 미래 단정 금지).
- 데이터 흐름: store(`useReadingStore`)에서 birthInfo+pastEvents로 계산해 body에 담아 전송 →
  api/reading.ts는 통과만(saju.ts 미import). cacheKey에 pastEvents 반영.
- UI 입력(`ContextPicker`): "실제로 있었던 과거 일(검증용, 선택)" — 연도·분야·메모 행 추가/삭제.
- 결과 카드(`PastValidationPanel`): 요약 영역에 부합도 배지+설명, 사건화 예보 아래 렌더.
- index.css: 과거 사건 입력행·검증 결과 카드 스타일(모바일 반응형 포함).
- 테스트: `pastValidation.test.ts`(4), `reading.test.ts` 배선 1개. 전체 222 통과, build OK.
  API 번들에 lunar 미유입 확인.

## 명리 엔진 고도화 3단계 — Activation / Benefit / Risk 점수 체계

로드맵 3번: 사건화 엔진의 활성도(high/mid/low)를 분야별 3축 점수(0~100)로 확장.
"이 분야가 얼마나 움직이고(activation), 이득 방향인지(benefit), 부담 방향인지(risk)"를 계산.

- 타입: `EventScores { activation, benefit, risk, balance }`, `EventScenario.scores` 추가.
  balance = opportunity(기회형)/caution(주의형)/mixed(혼조형)/calm(평이).
- eventEngine `activationFor` 확장:
  - benefit: 합/삼합/반합/방합 상호작용 + 운 간지 오행이 용신(보완 기운) + 원국에서 그 분야
    담당 십성이 넉넉할 때(역량) 가산.
  - risk: 충/형/파/해/자형 상호작용 + 운 간지 오행이 기신(부담 기운) + 그 분야 담당 십성이
    비었을 때(취약) 가산.
  - 용신/기신은 chart.yongshin.supportive/unfavorable(한글 오행)을 Element로 변환해 사용.
  - LuckSignal에 천간/지지 오행(stemEl/branchEl) 추가.
  - balance는 benefit-risk 차이(±18)로 판정, activation low면 calm.
- headline: 기회형/주의형 분야를 구분해 "○○는 살리기 좋고, △△는 점검 필요" 식으로 생성.
- 프롬프트(systemPrompt): 근거 블록에 (활성/이득/위험) 점수와 성격 라벨 노출, 활용 안내에
  기회형/주의형/혼조형 톤 매칭 규칙 추가(점수 그대로 노출 금지, 말로 옮기기).
- UI(EventForecastPanel): 활성 분야 카드에 balance 배지 + 활성/이득/위험 3축 미니 막대. index.css 추가.
- 테스트: eventEngine.test.ts 점수 범위·balance 검증 2건 추가. 전체 223 통과, build OK.

## 명리 엔진 고도화 4단계 — 통근·투출·격국 성패·용신 체계 확장

로드맵 4번. 계산 로직을 건드리므로 기존 회귀 테스트 호환을 유지하는 additive 방식으로 구현
(기존 함수 불변, 새 optional 필드만 추가). saju-calculation-validation.md도 갱신.

- 통근(通根) `computeRootedness`: 각 천간이 지지 지장간에 같은 오행으로 뿌리를 두는지.
  정기/중기/여기 강도 판정. 특히 일간 통근 여부를 "쉽게 흔들리지 않는 힘" 문구로. → `SajuChart.rootedness`.
- 투출(投出) `computeTransparency`: 월지 지장간이 천간에 드러났는지 → 격의 뚜렷함. → `SajuChart.transparency`.
- 격국 성패 `assessGyeokgukStatus`: 월지 정기 투출 + 월지 충 여부로 성격/파격/불명확 판정. →
  `GyeokgukInfo.status`/`statusReason`.
- 용신 확장: 기존 억부(suggestYongshin) 유지 + `climaticYongshin`(겨울생→화/여름생→수) +
  `mediatingYongshin`(최강 두 오행이 상극이면 잇는 오행). → `YongshinCandidates.climatic/mediating/method`.
- 배선: systemPrompt formatSajuChart에 통근·투출·격국 성패·조후/통관 용신 근거 추가.
  SajuFactsPanel 계산값 영역에 표시.
- 타입: `RootednessHit`, `TransparencyInfo`, GyeokgukInfo/YongshinCandidates 필드 확장.
- 테스트: sajuFeatures.test.ts에 통근·투출·격국 성패·조후용신 검증 5건 추가.
  기존 회귀 테스트(계산 고정값) 전부 유지. 전체 228 통과, build OK.

## 명리 엔진 고도화 5단계 — 대운·세운 중첩 규칙 강화

로드맵 5번(마지막). 대운(큰 흐름)과 세운(올해 흐름)이 각각 원국과 맺는 상호작용만 보던 것을,
두 흐름이 서로 겹치는 방식까지 판정하도록 확장. 무 API·결정론(additive).

- `computeLuckOverlap(대운간지, 세운간지, 용신오행, 기신오행)`:
  - 대운↔세운 두 기둥 사이의 직접 합충형파해(computeInteractions 재사용).
  - 각 간지가 용신(보완) 방향인지 기신(부담) 방향인지(luckFavorOf) 판정.
  - 종합 combo: amplify-good(좋은 흐름 겹침)/amplify-bad(부담 겹침)/mixed(엇갈림)/quiet(조용함).
  - 충 있으면 "자리·환경 흔들림", 합 있으면 "새 인연·기회" 코멘트 부착. 쉬운 말 headline + 근거.
- computeLuckCycles: currentDaYun+세운으로 overlap 계산 → `LuckCycles.daYunYearOverlap`.
  LuckCycleOptions에 yongElements/avoidElements 추가(store에서 chart.yongshin 전달).
- 타입: `LuckOverlap`, `LuckFavor`.
- 배선: store에서 용신/기신 오행 전달. systemPrompt formatLuckCycles에 중첩 판정 근거 + 해석 안내
  (좋은 흐름 겹침=밀어붙이기 좋은 시기, 부담 겹침=속도 조절, 엇갈림=신호 보며 조정).
  SajuFactsPanel 운 흐름 영역에 combo별 색상 카드로 표시. index.css 추가.
- 테스트: sajuFeatures.test.ts에 중첩 판정·중립 케이스 2건. 전체 230 통과, build OK.
  기존 계산 회귀값 유지.

## 명리 엔진 고도화 5단계 완료 — 로드맵 1~5 전부 반영

사용자 확정 로드맵(사건화 → 과거검증 → activation/benefit/risk → 통근·투출·용신 → 대운·세운 중첩)
5단계를 순차 구현하고 각 단계마다 main 커밋/푸시 완료. 모든 계산은 결정론·무 API,
표면은 쉬운 말·근거는 전문가 영역 보존 원칙 유지. saju.ts(lunar) 미유입 원칙도 신규 룰 모듈에 유지.

## Evidence Gate / Judgment Engine P0

목표: LLM이 결론을 직접 만들지 않고, 계산·사건화·압축 근거 뒤에 판단 레이어가 먼저
`JudgmentPack`을 만들고 LLM은 상담 문장으로 번역만 하도록 제한.

- 새 판단 레이어 추가:
  - `evidenceIds.ts`: compactEvidence의 문자열 근거를 `EvidenceRef` 객체(id/source/strength/direction/summary)로 정규화.
  - `ruleEngine.ts`: career/money/love/health/startup/move/family/general P0 rule 발동. 모든 rule은 `rule.*` id와 evidence 보유.
  - `judgmentEngine.ts`: rule 결과를 `CAREER_CHANGE_HIGH`, `MONEY_RISK_MEDIUM`, `STARTUP_NOT_RECOMMENDED` 같은 code 기반 JudgmentCandidate로 변환.
  - `confidenceEngine.ts`: chart/luck/event/context/overall 확신도 산정. counterEvidence가 있으면 overall 감점.
  - `contradictionEngine.ts`: 직업 변화 vs 즉시 창업 금지, 돈 위험 vs 창업 실험 등 P0 모순/긴장 탐지.
  - `judgmentValidation.ts`: JudgmentPack 구조 검증 + LLM 출력의 forbidden claim/unsupported high-risk claim 검사.
  - `judgmentPrompt.ts`: LLM에 JudgmentPack만 전달하고 새 결론 생성을 금지하는 prompt payload 구성.
- `JudgmentPack.schemaVersion = 1.0.0`.
- `DecisionTrace`와 `audit` 구조를 포함해 Evidence → Rules → Judgments → Confidence → Contradiction → Prompt 흐름 추적 가능.
- 연결:
  - light 사주/combo compactEvidence 경로에서 `buildReadingJudgmentPack` 생성.
  - API meta에 `judgmentPack` 포함.
  - `readingValidation`이 optional judgmentPack을 받아 출력 후 Evidence Gate warning/error를 기록.
- 원칙:
  - `saju.ts` 계산 로직 변경 없음.
  - `eventEngine` 계산 결과 변경 없음.
  - P0에서는 rewrite 없이 warning 기록만 수행.
- 테스트 추가:
  - ruleEngine, judgmentEngine, confidenceEngine, contradictionEngine, judgmentValidation, judgmentPrompt.
  - `npm test`: 36 files / 243 tests 통과.
  - `npm run build`와 별도 `tsc --noEmit`은 현재 로컬 환경에서 `tsc`가 장시간 무출력으로 멈춰 중단함.

## Case Validation Engine P2 (사례 기반 검증 엔진)

목표: 규칙을 더 추가하는 것이 아니라, 지금 판단(JudgmentPack)이 실제 사례에서 얼마나 맞는지
자동으로 대조·집계하는 "데이터를 모으는 엔진"을 추가. 판단을 바꾸는 엔진이 아니다.

- 새 모듈 `src/lib/caseValidation/` (읽기 전용, 계산·룰·판단 미변경):
  - `caseTypes.ts`: `Case`(birth + 분야별 실제 결과 + 사용자/전문가 평가), `CaseDomainOutcome`,
    `MatchLevel`(match/partial/minor/miss → 100/70/30/0), `PredictedDirection`,
    `CaseJudgmentOutcome`, `CaseValidationResult`. `CASE_SCHEMA_VERSION = 1.0.0`.
  - `caseScore.ts`: `CODE_EXPECTATION`(JudgmentCode → 분야·예측방향), `RULE_FOR_CODE`(codeForRule 역매핑),
    `scoreMatch`(예측방향 ↔ 실제 사건/방향 채점). 예측 없는 판단(GENERAL_MIXED_FLOW)은 대조 제외.
  - `caseValidator.ts`: JudgmentPack × Case 대조 → 판단별 등급 + `matchRate`. audit의 rewrite/fallback 반영.
  - `caseMetrics.ts`: Rule/Judgment/Confidence 통계(trigger/match/mismatch/avgScore/avgConfidence/avgUserFeedback),
    confidence 구간 캘리브레이션. 모두 읽기 전용, 값 자동 변경 없음.
  - `caseDataset.ts`: 사례 저장 컨테이너(추가/필터/직렬화). UI 없음, 저장 구조만.
  - `caseReport.ts`: 전체·분야별 적중, Rule Top/Best/Worst, rewrite/fallback 발생률, confidence 분포,
    보정 후보(gap 큰 rule, 자동 적용 아님), 사람 검토 필요 항목. `formatCaseReport` 텍스트 출력.
  - `caseFixtures.ts`: `makeJudgment`/`makePack` 팩토리 + 22개 픽스처(career/money/love/health/startup/move/family + 혼합).
- 원칙:
  - `saju.ts` 계산 / `eventEngine` / Rule / Judgment 구조 변경 없음.
  - confidence 자동 보정 없음. 통계는 자료로만 제공하고, 보정 후보는 "사람 검토 후"로 명시.
- 자동 보정 가능한 부분: Rule별 avgScore·avgConfidence gap, confidence 구간별 실제 적중률(캘리브레이션 자료).
- 아직 사람 검토가 필요한 부분: 예측 방향 없는 판단(GENERAL_MIXED_FLOW), 표본 부족 rule,
  전문가 검토 부재 시 best/worst는 사용자 결과 기반 추정치.
- 테스트: `caseValidation.test.ts` 26개(score/validator/metrics/dataset/report/fixture). 기존 테스트 무변경.
  - `npm test`: 38 files / 278 tests 통과. `npm run build` 성공(기존 500kB chunk 경고만).

## AI Quality Dashboard P2 (개발자 전용 Observability Layer)

목표: 사용자 기능이 아니라, 개발자가 AI 엔진 품질을 숫자로 관찰·관리하는 운영 계층을 추가.
계산(saju.ts)·eventEngine·Rule·Judgment 엔진은 절대 변경하지 않는 관찰자(Observer) 레이어.

### Logging 위치 (분석 후 결정)
- 파이프라인: Compute→Evidence→Rule→Judgment→Evidence Gate(서버 api/reading.ts)→Claude→Validation→Rewrite→Fallback.
- JudgmentPack 생성: 서버 `buildReadingJudgmentPack`(api/reading.ts). rewrite/fallback 판정: 서버 `completeJudgmentGatedReply`.
- 클라이언트 `useReadingStore.startReading`가 리딩 완료 시점에 (a) meta의 JudgmentPack, (b) 클라 readingValidation 결과,
  (c) 서버 게이트 status를 모두 손에 쥔다 → 여기를 관찰 지점으로 선택. 계산 엔진 무변경, 저장은 브라우저 localStorage 모델과 일치.

### 새 파일 (`src/lib/quality/`)
- `qualityTypes.ts`: PII-free `QualityEvent` 스키마(timestamp/readingType/judgment·rule·contradiction·forbidden id/confidence/validation/gate/version). `QUALITY_SCHEMA_VERSION=1.0.0`, `ENGINE_VERSION`.
- `qualityLogger.ts`: `buildQualityEvent`(순수, 서버 재사용 가능) + `logReading`(Observer, 절대 throw 안 함).
- `qualityStorage.ts`: `QualityStore` 인터페이스 + localStorage 링버퍼(cap 2000) + 메모리 fallback. 모든 메서드 실패 삼킴.
- `qualityMetrics.ts`: reading 기간별 수·validation 비율·rewrite/fallback·forbidden TOP10·confidence(domain별)·judgment TOP20·rule TOP20·contradiction TOP10·최근 실패 로그.
- `qualityHealth.ts`: Engine Health(0~100) 가중합 + 컴포넌트 breakdown + `explainHealthChange`(왜 올랐/내렸는지 추적).
- `qualityDashboard.ts`: 저장 이벤트 → 뷰-모델(health+trend+metrics). 로직/뷰 분리.
- `qualityAccess.ts`: 개발자 전용 접근 제한(dev 허용 / prod는 VITE_QUALITY_DASHBOARD=1 또는 localStorage unlock).
- `index.ts`: 배럴(중심 운영 계층 진입점).
- UI: `src/pages/QualityDashboardPage.tsx` (경로 `/_internal/quality`, 접근 제한 내장).

### 수정 파일 (관찰 배선, 계산 무영향)
- `src/lib/readingApi.ts`: 서버 `gate`(status+reasonCodes) 신호를 StreamResult로 스레드(추가 필드, read-only).
- `src/store/useReadingStore.ts`: 리딩 완료 후 `logReading` 호출(try/catch 이중 방어).
- `api/reading.ts`: done 라인/JSON의 `gate: {status}` → `gate: {status, reasonCodes}` (PII 없는 이유 코드; gateSignal, 절대 throw 안 함).
- `src/App.tsx`: `/_internal/quality` 라우트 등록.

### Engine Health 계산
- validationPass 40% / rewriteSuccess 20% / fallback 억제 15% / confidenceStability 15% / ruleCoverage 10% (가중치 합 100, HEALTH_WEIGHTS 한 곳 관리).
- 각 컴포넌트 score·contribution·note로 분해 → Health 등락 원인 추적 가능. `explainHealthChange(before,after)`로 창(최근7일 vs 직전7일) 비교.

### 저장 원칙(불변식)
- 저장: timestamp, reading type, judgment/rule/contradiction/forbidden **code·id**, validation 결과, rewrite/fallback 플래그, confidence, engine/schema version만.
- 절대 저장 안 함: 생년월일·이름·사용자 입력·LLM 원문·개인정보(구조적으로 배제).

### 보안/원칙
- 엔진과 완전 분리된 Observer. 로깅 실패가 리딩을 깨지 않도록 logReading/storage/서버 gateSignal 모두 throw 금지.
- 대시보드는 계산·리딩을 호출하지 않고 저장된 이벤트만 읽는다.

### 테스트
- `src/lib/quality/quality.test.ts` 24개 + `QualityDashboardPage.test.tsx` 2개.
- `npm test`: 40 files / 304 tests 통과. `npm run build` 성공(기존 500kB chunk 경고만).

### 향후 P3 (Case Validation 연계)
- Quality Dashboard를 중심 운영 계층으로: Case Validation Engine(`src/lib/caseValidation/`)의 검증 결과를 같은 QualityEvent/저장소 위에 얹어 Rule Calibration 자료로 연결.
- Explain Engine / Rule Calibration Engine도 동일 이벤트를 소비. 서버 sink(QualityStore 구현 교체)로 브라우저 밖 집계 확장 가능(스키마 재설계 불필요).

## Golden Test Cases P2 (리딩 엔진 회귀 테스트 기반)

목표: 모델/프롬프트/룰 변경 시 리딩 품질 퇴보를 자동 감지. LLM 문장을 고정하지 않고 결정론
JudgmentPack(계산→근거→룰→판단)만 허용범위로 비교. 계산 엔진/eventEngine 무수정.

- 새 파일 `src/lib/goldenCases/`:
  - `goldenTypes.ts`: GoldenCase 스키마(필수/금지 code, 도메인, confidence 밴드, contradiction 허용집합, evidence 필수 id, 구조유효성).
  - `goldenRunner.ts`: `buildPackForCase`(computeSajuChart→computeLuckCycles→buildReadingJudgmentPack, 결정론) + `summarizeJudgmentPack` + `checkGoldenCase`(허용범위 검사).
  - `goldenCases.ts`: 실제 엔진 출력에서 도출한 21개 케이스(연령/성별/음양력/시간모름/야자시/focus 다양).
  - `golden.test.ts`: it.each 드라이버 + 네거티브 컨트롤 6종(위반이 실제 감지되는지 증명).
  - `README.md`: 갱신 절차.
- 비교 기준: judgment code 부분집합/배타, 도메인 커버리지, `validateJudgmentPack.ok`(forbidden-claim 구조 결함 0),
  confidence 넓은 밴드, contradiction 알려진 집합+개수 상한, 핵심 evidence id, 구조상 rewrite 강제 없음.
- 결정론 경계: 실제 LLM rewrite/fallback·문장 품질은 범위 밖 → optional LLM 단계로 분리(미구현).
- 회귀 원리: 룰이 조용히 죽거나(code 누락), 안전장치 퇴보(forbidden 구조결함), 도메인 하락, confidence 급변,
  허용 밖 모순, evidence 배선 끊김 → FAIL. 무해한 추가는 통과(over-detection 억제).
- 테스트: golden 31개. `npm test` 41 files / 338 tests 통과. `npm run build` 성공. golden 소스는 test-only import라 앱 번들 미포함.

## 결과 페이지 전면 가독성·비주얼 개선 (인라인 SVG viz 레이어)

목표: 모든 결과 화면(리딩/오늘운세/오늘의 카드/궁합/작명)에 도표·그래프·아이콘·장식을 넣어
"사용자 입장에서 끝내준다"는 느낌의 리딩 UI로 개선. 의존성 추가 없이 전부 인라인 SVG로 제작.

### 새 공용 레이어 `src/components/viz/`
- `icons.tsx`: 섹션/파트 tone 키 기반 스트로크 아이콘 세트 (전부 aria-hidden 장식, 텍스트가 항상 의미 전달).
- `ElementRadarChart.tsx`: 진짜 오행 오각형 레이더. 꼭짓점마다 이름+수치+풀이 라벨, 최강/최약 자동 캡션.
- `ArcGauge.tsx`: 270° 아크 게이지. 기존 `GaugeDef`와 호환(드롭인). `tierLabel`로 숫자 대신 생활언어 노출.
- `MonthlyFlowChart.tsx`: 1~12월 흐름 곡선. 곡선은 계산값(luckCycles.monthlyFlow)만 사용, y축은
  잔잔함/가벼운 자극/변화 있음/흔들림 큼 4단어(숫자 미노출). 달 버튼 탭 → AI 월별 텍스트 상세 연결.
- `TarotCardArt.tsx`: 제네릭 스타일라이즈드 타로 카드(이중 프레임+수트 배너+중앙 문양+이름 카르투슈).
- `RatingCell.tsx`: 좋음/보통/주의 픽토그래프(점 3개/경고 삼각형 + 단어 항상 병기).
- `Motif.tsx`: 장식 전용(붓선 구분선, 모서리 장식, 구름 문양, 낙관 도장, 태극). 데이터 미포함.
- `elementMeta.ts`: 오행 순서/라벨/풀이 공용 메타 (SajuFactsPanel과 공유).
- `readingText.tsx`(lib): ReadingResult의 parseSections/parseBodyParts/stripMarkdown/renderTextBlock 추출 —
  작명 등 다른 화면이 같은 규칙으로 AI 텍스트 렌더.

### 화면별 변경
- SajuFactsPanel: 가짜 점 레이더 → 오행 레이더 차트, 기운 강도 → 중립 아크 게이지(단어 중심),
  대운 알약 오행 틴트+연결선+"지금" 깃발, 월별 details 안에 흐름 차트 추가. 원국 스냅샷은 구조 불변
  (항상 노출·한자 우선 유지), 기둥 상단 오행 색 스트립만 추가.
- ReadingResult: 섹션/파트 헤더 tone 아이콘, 분야별 요약 = 아이콘+픽토그래프 카드+집계 스트립,
  올해의 흐름 = 계산 곡선 차트(+AI 텍스트는 탭 상세, 12장 카드는 접힘 보존), 목차 = 스티키 칩 내비
  (IntersectionObserver 하이라이트, HashRouter 제약으로 button+scrollIntoView 유지),
  첫/마지막 점괘 카드에 구름 문양+모서리 장식+큰 따옴표, 레이어 사이 붓선 구분선.
- 타로: TarotCardVisual 글리프 폴백 → TarotCardArt (imageUrl 분기 보존). FactsPanel/RevealStage/
  오늘의 카드 동시 업그레이드, TarotTodayPage 중복 비주얼 삭제. SummaryHero 비율바 → 카드당 핍
  (채움=정방향/점선 윤곽=역방향, 뽑은 순서 번호) + 칩 수트 아이콘.
- FortuneResult: 총운 대형 아크, 분야 카드 소형 아크+분야 아이콘, do/avoid 투톤 패널+체크/경고 아이콘,
  행운 그리드 아이콘, 일진 낙관 도장(+일반 텍스트 라벨 병기).
- NamingResult: AI 해석 `<pre>` 제거 → readingText 파서 기반 섹션 카드(평문 폴백 내장),
  발음오행 = 음절 노드+관계 화살표 다이어그램(상극은 지그재그, 단어 병기), 수리 = 실제 `<table>`,
  궁합 = 단어만 노출하는 소형 아크.
- CompatibilityPage: 점수 = 도넛 아크(+tierWord), breakdown = N축 폴리곤 레이더(꼭짓점 tierWord,
  게이지 목록은 상세 뷰로 유지), 두 사람 미니 4주 박스, 갈등 사이클 번호 배지+진행 화살표.
  computeCompatibility 로직 불변.

### 원칙 (이후 세션도 유지할 것)
- 오행 팔레트는 색약 구분이 어려움(검증 결과) → 색만으로 정보 구분 금지, 항상 텍스트 라벨 병기, 표 뷰 보존.
- 차트마다 생활언어 캡션(`.viz-caption`) 필수 — "시각 요소 하나 = 메시지 하나", 설명 없는 숫자 금지.
- 시각화 컴포넌트는 데이터 불충분 시 null 반환(스트리밍 내성). AI 산문을 수치화해 그래프로 그리지 않는다.
- 장식 모티프는 aria-hidden + 프린트에서 숨김. 차트는 break-inside: avoid + print-color-adjust로 인쇄 보강.
- 죽은 CSS 제거: .element-radar*, 옛 타로 글리프/작명 칩/compat 숫자 블록.
- 검증: npm test 42파일/356테스트, npm run build 성공(기존 500kB 경고만, 신규 의존성 0).

## 텔레그램 사주 선생님 봇 추가 (bot/)

날짜: 2026-07-06

### 무엇을
- `bot/` 디렉토리에 개인용 텔레그램 챗봇 추가. 용도: 내 사주를 등록해두고 "왜 신약사주인지", "오늘 일진이 왜 이렇게 흘러가는지" 같은 질문에 계산 근거를 짚어가며 답하는 1:1 사주 선생님.
- 실행: `TELEGRAM_BOT_TOKEN=... ANTHROPIC_API_KEY=... npm run bot` (롱폴링, 웹훅/서버 불필요). 상세는 `bot/README.md`.

### 아키텍처 (핵심 원칙 유지: 계산은 결정적, AI는 해석만)
- 계산은 전부 기존 엔진 재사용: `computeSajuChart` + `computeLuckCycles`(includeMonthlyFlow, 용신/기신 전달) + `computeFortuneEvidence`(오늘 일진). 봇이 새 계산 로직을 만들지 않는다.
- Claude에는 계산 JSON을 [원국]/[운 흐름]/[오늘 일진] 근거 팩으로 전달하고, 시스템 프롬프트에서 "데이터에 있는 값만 근거로, 왜 그런지 가르치듯" 답하게 제한. 공포/단정 금지, 건강=컨디션 조언까지, 큰 결정=판단 기준 제공 등 기존 안전 규칙 동일 적용.
- 파일: `bot/index.ts`(명령 라우팅), `bot/telegram.ts`(의존성 없는 Bot API 클라이언트, 4096자 분할, Markdown 실패 시 평문 폴백), `bot/parseBirth.ts`(자유 형식 생년월일 파싱: 음력/윤달/시간모름/출생지), `bot/evidence.ts`(근거 팩 + API 없는 /saju 요약), `bot/teacher.ts`(Claude 호출), `bot/store.ts`(bot/data/users.json, 최근 40턴, git 미포함).
- 명령어: /start /birth /saju(API 호출 없음) /today /reset /delete. `TELEGRAM_ALLOWED_USER_IDS`로 개인 봇 잠금 가능.

### 중요한 버그 수정 지식 (이후 세션 주의)
- `computeLuckCycles`는 `now`의 **로컬 시간 필드**(`Solar.fromDate`)를 쓴다. 웹앱은 브라우저(KST)라 문제없지만, UTC 서버에서 돌리면 일진이 하루(절기 경계면 월운까지) 어긋난다. 봇은 `bot/evidence.ts`의 `kstNow()`로 KST 벽시계 값을 가진 Date를 만들어 전달한다. 서버에서 이 함수를 쓰는 다른 경로가 생기면 같은 보정 필요.

### 부수 변경
- `@anthropic-ai/sdk` 0.32.1 → 0.110.0 (봇의 adaptive thinking 사용 목적). `api/reading.ts` 타입체크 통과, 기존 사용 API(messages.stream/create, APIError) 호환 확인.
- devDependency `tsx` 추가, `npm run bot` 스크립트 추가, `tsconfig.bot.json`(봇 전용 타입체크: `npx tsc -p tsconfig.bot.json`).
- 봇 기본 모델은 `claude-opus-4-8`(BOT_MODEL로 교체 가능). 웹앱 READING_MODEL(claude-sonnet-5)과 독립.

### 검증
- npm test 42파일/356테스트 통과, npm run build 성공(기존 500kB 경고만).
- 계산 스모크: 2000-01-01 12:30 서울 → 일주 무오(만세력 검증값 일치), KST 보정 후 luck/fortune 일진 일치(임오) 확인.

## 텔레그램 봇 — 버그 수정 + Railway 배포 준비

날짜: 2026-07-07

### 무엇을
- **성별 파싱 버그 수정** (`bot/parseBirth.ts`): 기존 `/남/.test(text)` / `/여/.test(text)`가 문자열 전체를 독립적으로 스캔해서, 출생지에 "여"가 들어간 지명(예: 여수)이 있으면 실제 성별과 무관하게 female로 덮어써지는 문제가 있었다. 공백/문자열 경계로 감싸인 독립 토큰(`남`/`여`/`남자`/`여자`)만 인정하도록 정규식 하나로 교체. `1990-01-01 12:00 남 여수` 같은 입력에서 재현/수정 확인.
- **답변 잘림 처리** (`bot/teacher.ts`): `max_tokens`를 8000 → 16000으로 올리고(adaptive thinking이 같은 예산을 나눠 쓰므로 근거 인용이 긴 답변은 8000에서 잘릴 위험이 있었음), `stop_reason === "max_tokens"`일 때 "답이 길어져 끊겼다" 안내를 답변 끝에 붙이도록 추가. 기존엔 `"refusal"`만 체크하고 잘림은 조용히 무시했다.
- **기동 시 조기 실패**: `ANTHROPIC_API_KEY` 미설정 시 SDK가 던지는 raw stack trace 대신, `telegram.ts`의 `TELEGRAM_BOT_TOKEN` 체크와 동일한 패턴으로 한국어 에러 메시지 후 `process.exit(1)`.
- **Railway 배포 대응**: `tsx`를 devDependencies → dependencies로 이동(Railway/Nixpacks가 `NODE_ENV=production`으로 설치하면 devDependency가 빠져서 `npm run bot` 런타임에 tsx가 없을 수 있음). `saju-tarot-chatbot/railway.json` 추가(startCommand: `npm run bot`, 재시작 정책). `bot/README.md`에 Railway 배포 절차 추가 — 특히 **Root Directory를 `saju-tarot-chatbot`으로 지정**해야 하는 점(모노레포)과, **Railway 컨테이너는 재배포마다 파일시스템이 초기화**되므로 `bot/data/users.json`(사주 등록·대화 기록)을 유지하려면 Volume을 붙이고 `BOT_DATA_DIR`을 그 마운트 경로로 지정해야 한다는 점을 명시.

### 검증
- npm test 42파일/356테스트 통과, npm run build 성공, `npx tsc -p tsconfig.bot.json --noEmit` 통과.
- 성별 파싱 수정 후 5개 케이스(남/여 단독, 음력, 시간모름, "남 여수", "여수 남") 직접 실행해 전부 기대값과 일치 확인.

## 텔레그램 봇 — 학습 보조 강화

날짜: 2026-07-07

### 무엇을
- 사용자 요청: 이 봇을 사주 "공부"에 도움이 되게 해달라 — 원리를 이해시켜주되, 답변은 억지로 길지 않고 간결하게, 대화 수준(초급/심화)에 맞춰 설명 깊이를 조절해달라는 4가지 요구.
- `bot/teacher.ts`의 `TEACHER_SYSTEM`에 세 가지 지침 추가:
  1. 원리 질문(용신이 왜 금인지, 지장간 배당 원리, 오행 상생상극 원리 등)은 계산 데이터 인용을 넘어 명리학 기초 이론부터 설명하고, 마지막에 사용자의 실제 계산값에 연결하라 — "데이터에 없는 걸 지어내지 말라"는 규칙과는 별개(이론 자체는 일반 지식으로 답해도 된다는 걸 명시).
  2. 사용자가 이미 자연스럽게 쓰는 용어는 재설명하지 말고, 대화 맥락으로 판단한 이해 수준에 맞춰 심화 질문엔 심화 용어로 답하라(수준 적응형 설명).
  3. 답변 분량은 질문 난이도에 맞추고, 이해에 필요 없는 문장은 쓰지 말라고 명시(길게 쓰는 것 ≠ 잘 이해되게 쓰는 것).
- `bot/index.ts`에 `/퀴즈` 명령어 추가: 대화·계산 데이터 중 개념 하나를 골라 문제만 먼저 내고, 사용자가 다음 메시지로 답하면 채점하도록 유도하는 프롬프트를 `askTeacher`에 전달. 별도 상태 관리 없이 기존 history 기반 대화 흐름으로 채점까지 자연스럽게 이어짐.
- `/start` 안내와 `bot/README.md`에 "내 사주와 무관한 이론 자체 질문도 가능"하다는 점과 `/퀴즈` 사용법을 반영.

### 검증
- npm test 42파일/356테스트 통과, `npx tsc -p tsconfig.bot.json --noEmit` 통과.

## 텔레그램 봇 — 롱폴링(Railway) → 웹훅(Vercel) 전환

날짜: 2026-07-07

### 왜
- Railway에 올린 롱폴링 봇은 하루 24시간 프로세스가 떠 있어야 해서, 실제 사용량과 무관하게 컴퓨팅 자원이 계속 과금됨. 사용자가 비용이 예상보다 많이 나온다고 확인 → 텔레그램 웹훅 + 서버리스(Vercel)로 전환 결정(사용자가 4가지 선택지 중 명시적으로 선택).
- 이 앱은 이미 Vercel에 배포돼 있으므로, 별도 인프라 없이 서버리스 함수 하나(`api/telegram-webhook.ts`) 추가로 끝남. 메시지가 올 때만 실행되므로 개인 사용량 기준 사실상 무료.

### 아키텍처 변경
- **저장소를 두 구현으로 분리** (`bot/storeTypes.ts`의 공용 `Store` 인터페이스: `getUser/setBirthInfo/appendHistory/clearHistory/deleteUser`, 전부 비동기로 통일):
  - `bot/fileStore.ts` (구 `bot/store.ts`) — 로컬 파일(`bot/data/users.json`). 롱폴링/로컬 개발 전용으로 격하.
  - `bot/kvStore.ts` (신규) — Upstash Redis REST API. 웹훅(서버리스)은 파일시스템이 요청/인스턴스마다 초기화되므로 필수. `api/_security.ts`의 `upstashRateLimit()`과 동일한 순수 HTTP `/pipeline` 방식을 그대로 재사용(호스팅 이식성 유지, 새 의존성 없음). 사용자당 JSON 한 덩어리를 `saju-bot:user:<chatId>` 키에 SET/GET.
  - `kvStore.ts`에 `markUpdateProcessed(updateId)`도 추가 — 텔레그램이 웹훅 응답 지연 시 같은 update를 재전송하는 경우를 막기 위해 `SET ... NX EX 3600`으로 원자적 중복 체크(Redis 장애 시엔 안전하게 "새 업데이트로 간주"하고 처리 — 무응답보다 드문 중복이 낫다는 판단).
- **메시지 처리 로직을 공용 모듈로 추출**: `bot/messageHandler.ts`가 `handleMessage(msg, store: Store)`를 export. 롱폴링(`bot/index.ts`, `fileStore` 주입)과 웹훅(`api/telegram-webhook.ts`, `kvStore` 주입)이 완전히 동일한 로직을 공유 — 저장소만 다르게 주입됨. 기존 `askTeacher` 호출 에러만 잡던 좁은 try/catch를 `handleMessage` 전체를 감싸는 구조로 넓혀서, 저장소 오류(예: Upstash 미설정)도 사용자에게 에러 메시지로 전달되게 함.
- `bot/teacher.ts`: `ChatTurn` 타입 임포트 경로를 `./store.js` → `./storeTypes.js`로 수정(타입 위치 이동에 따른 후속 수정).
- `api/telegram-webhook.ts` (신규, Vercel 서버리스): POST만 허용, `TELEGRAM_WEBHOOK_SECRET`으로 `X-Telegram-Bot-Api-Secret-Token` 헤더 검증(설정 시), `markUpdateProcessed`로 중복 제거 후 `handleMessage` 호출, 항상 200 반환. Claude 응답 생성까지 함수 안에서 끝까지 기다리므로(텔레그램에 별도 `sendMessage`로 보내야 해서) `vercel.json`에 `api/reading.ts`와 동일하게 `maxDuration: 300` 부여.
- `bot/index.ts`는 이제 로컬 개발/테스트 전용 롱폴링 루프로 축소 — `fileStore` + `messageHandler`만 사용. 파일 상단에 "웹훅과 동시에 못 쓴다, 로컬 테스트 전엔 `deleteWebhook` 먼저" 경고 추가.
- `tsconfig.bot.json`의 `include`에 `api/telegram-webhook.ts` 추가해서 웹훅 함수도 봇 타입체크(`npx tsc -p tsconfig.bot.json --noEmit`) 범위에 포함시킴.
- `bot/README.md` 전면 개편: 웹훅(프로덕션)을 기본 경로로, 롱폴링은 "로컬 개발/테스트용"으로 격하. Upstash 가입, Vercel 환경변수, `setWebhook`/`getWebhookInfo`/`deleteWebhook` curl 명령, **레일웨이 서비스를 반드시 삭제해야 비용이 실제로 멈춘다는 경고**(안 지우면 웹훅과 충돌하며 에러만 반복하고 요금도 계속 나감)를 명시.
- `railway.json`은 그대로 남겨둠(로컬 대안으로 다시 쓸 수도 있어 삭제하지 않음) — 다만 프로덕션 경로로는 더 이상 쓰지 않음.

### 검증
- `bot/fileStore.ts`를 임시 `BOT_DATA_DIR`로 직접 실행해 등록→기록→초기화→삭제 5단계 스모크 테스트 통과.
- npm test 42파일/356테스트 통과, `npx tsc -p tsconfig.bot.json --noEmit` 통과(신규 `api/telegram-webhook.ts` 포함), `npm run build` 성공.
- Upstash 실제 연동(kvStore.ts)은 로컬에서 실제 Upstash 인스턴스 없이는 테스트 못 함 — 배포 후 텔레그램에서 `/start`~질문까지 실사용 테스트 필요.

## 리딩 타입별 템플릿 1차 분리 (화면 배치만, 프롬프트/타입/저장 불변)

- 사전 점검: 헤드리스 Chromium + 스텁 NDJSON 스트림으로 전 결과 화면 육안 확인.
  발견 버그 1건 수정 — 스티키 목차 배경이 반투명이라 떠 있을 때 아래 콘텐츠가 비침 → 불투명 바탕 추가.
- `src/components/reading/readingBlocks.tsx`: ReadingResult에서 섹션 메타/월별 파서/섹션 카드/분야 요약/
  목차/근거 존/로딩 카드 등을 공용 블록으로 추출 (순수 이동, DOM 불변).
- `ReadingResult.tsx` = 디스패처: session.type + 질문 유무로 템플릿 선택.
  flow → `YearlyFlowTemplate`, tarot → 기본 템플릿 + 카드 근거 승격(promoteTarotFacts, 근거 존 중복 억제),
  saju+질문 → "고민 상담 리딩" 라벨, saju 무질문 → "평생사주 리포트" 라벨, combo 무질문 → "사주+타로 통합 리딩",
  그 외/과거 저장 세션 → 기본 템플릿 폴백.
- `YearlyFlowTemplate` (올해운세형, "1년 작전 지도"): 올해 한 줄 총평 히어로(연도 라벨+키워드 칩) →
  원국 스냅샷(항상 노출 유지) → 큰 흐름×올해 흐름 오버랩 카드 → 올해 총평 → 분야별 요약 →
  12개월 흐름 차트 승격 → 월별 상세 12카드 → 해야 할 것/피해야 할 것(펼침) → 나머지 섹션 →
  마지막 정리 → 근거 존/기본 리포트(하단) → 다음 리딩 CTA(`ReadingNextCta`, HashRouter Link).
  올해의 흐름이 월별 형식이 아니면(스트리밍 중/구버전 저장분) 일반 섹션 카드로 폴백.
- 하지 않은 것(의도): 프롬프트/AI 출력 구조/ReadingType/localStorage/useReadingStore 변경, 결제/구독.
- 테스트: `reading/readingTemplates.test.tsx` 5개 신규 (flow 전용 배치·스트리밍 폴백·라벨 분기·타로 승격 중복 방지).
  전체 43파일/361개 통과, 빌드 성공.

## 리딩 타입별 템플릿 2차 — 타입별 다음 리딩 CTA

- `DefaultReadingTemplate`에 `nextCta` prop 추가: AI 텍스트 도착 후(`hasReply && !loading`)에만 리딩 끝에
  `ReadingNextCta`를 렌더. 프롬프트/스토어/저장 구조 불변, 화면 배치만.
- 디스패처(`ReadingResult.tsx`)가 타입별 CTA를 주입:
  - 평생사주(saju 무질문): "이어서 보면 좋은 리포트" — 올해운세/고민 상담/오늘 운세.
  - 고민 상담(saju·combo + 질문): "이 고민, 더 파고들려면" — 사주+타로 재질문/올해 흐름/궁합.
  - 타로: 다시 뽑기/사주까지 보기/오늘의 카드. 콤보: 올해운세/전체 사주.
- 후속질문 자동 추천은 스토어·프롬프트 변경이 필요해 이번 범위에서 제외(2차는 CTA만).
  대운 인생지도 승격도 SajuFactsPanel 구조 변경 위험이 커서 3차로 남김.
- `ReadingResult.test.tsx`는 CTA의 react-router `<Link>` 때문에 MemoryRouter로 감쌌다(동작 동일).
- 테스트: 43파일/362개 통과, 빌드 성공. 헤드리스로 평생사주 라벨+CTA 렌더 육안 확인.

## 평생사주형 — 대운 인생 지도 승격 (3차)

- `SajuFactsPanel`에 `DaYunLifeMap` export 추가: 계산된 대운 배열을 세로 타임라인으로 렌더
  (나이·연도 범위 + 간지 + 기운 주제 문장 + 현재 시기 강조 + 오행별 노드 색). 계산 로직 불변, 표현만.
  기운 주제는 대운 천간 오행 → 성장/표현/안정/정리/사색 한 문장으로 옮긴 것(새 운명 주장 아님).
- `SajuFactsPanel`에 `showDaYun` prop(기본 true) 추가: 평생사주 템플릿이 대운을 위에서 인생 지도로
  이미 보여줄 때 하단 패널의 대운 알약 타임라인 + 큰흐름×올해흐름 중복 렌더를 끈다.
- `DefaultReadingTemplate`에 `promoteDaYunLifeMap` prop 추가: 원국 스냅샷 바로 아래에 "대운 인생 지도"
  카드(인생 지도 + 오버랩 헤드라인 + 캡션)를 렌더하고, 하단 SajuFactsPanel엔 showDaYun=false 전달.
- 디스패처: 평생사주(saju 무질문)만 promoteDaYunLifeMap 적용. 다른 타입은 기존대로 하단 패널에 대운 유지.
- 테스트: 인생 지도 승격 + 하단 중복 없음 검증 1개 추가(43파일/363개 통과), 빌드 성공.
  헤드리스로 세로 타임라인 렌더 + dayun-timeline 0개 육안 확인.

## 텔레그램 봇 — 사주 등록을 필수에서 선택으로

날짜: 2026-07-07

### 왜
- 사용자 요청: 사주 등록 안 해도 일반 명리학 이론 질문(지장간이 뭐야 등)에는 바로 답하게 해달라 — 지금까지는 등록 전 사용자가 보내는 모든 메시지를 "생년월일 등록 시도"로만 해석해서, 형식이 안 맞으면 계속 등록 안내만 반복하고 어떤 질문도 못 했다.

### 변경
- `bot/parseBirth.ts`: `looksLikeBirthInput(text)` 추가 — 연도(`19xx`/`20xx`+구분자)와 공백으로 감싸인 독립 성별 토큰(남/여/남자/여자)이 함께 있을 때만 "등록 시도"로 인식. 기존에 중복돼 있던 등록/재등록 두 분기의 판별 로직을 이 함수 하나로 통일.
- `bot/messageHandler.ts`: "사주 미등록 시 모든 입력을 등록 시도로 처리" 하드 게이트를 제거. 이제 흐름은: `/saju`·`/today`만 등록을 요구(개인 차트가 필수인 기능이라) → `looksLikeBirthInput`이면 등록/재등록 처리 → 그 외 모든 텍스트는 등록 여부와 무관하게 `askTeacher`로 전달. 등록 시도처럼 보이는데 파싱 실패한 경우, 안내 메시지는 **미등록 사용자에게만** 보여준다(이미 등록된 사용자가 우연히 연도+성별 단어가 섞인 질문을 했을 때 등록 안내로 오인하지 않도록).
- `bot/teacher.ts`: `AskOptions.birthInfo`를 `BirthInfo | null`로 변경. `birthInfo`가 없으면 원국/오늘 근거 데이터를 아예 첨부하지 않고, 대신 "아직 등록 안 함 — 일반 이론 질문엔 지식으로 답하고 개인 차트가 필요한 질문엔 등록을 안내하라"는 문맥을 첫 턴에 넣는다. `TEACHER_SYSTEM`에도 같은 취지의 규칙 한 줄 추가.
- `START_GUIDE`: "사주 등록 없이 바로 물어볼 수 있는 것" 예시를 등록 안내보다 먼저 보여주도록 순서 조정.

### 검증
- `looksLikeBirthInput` 직접 실행 확인: 일반 질문("지장간이 뭐야?") → false, 등록 형식 → true, 오탐 후보("2024년에 남자친구가...") → false(공백 경계 조건 덕분에 "남자친구" 안의 "남자"는 매치 안 됨).
- npm test 43파일/363테스트 통과, `npx tsc -p tsconfig.bot.json --noEmit` 통과, `npm run build` 성공.
