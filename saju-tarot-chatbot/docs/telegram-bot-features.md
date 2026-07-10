# 텔레그램 봇 — 기능 명세 (사주 · 타로 · 점성술 · 비서 + 100% 자연어 맥락 라우팅)

> 대상: `saju-tarot-chatbot/bot/` (롱폴링 `bot/index.ts` + Vercel 웹훅 `api/telegram-webhook.ts`가 공유하는 `bot/messageHandler.ts`).
> 이 문서는 "무엇을, 어떻게, 어디서" 하는지 전부를 코드 기준으로 정리한 레퍼런스입니다.
> 최종 반영: `main` (커밋 `9385783` 타로+라우팅, `790d8e0` "기억해?" 오인 수정).

---

## 0. 한눈에 보기

한 개의 개인 전용 텔레그램 봇이 아래를 **명령어 없이 자연어만으로** 처리합니다.

| 기능 | 자연어 예시 | 사주 등록 필요 | 처리 경로 |
|---|---|---|---|
| 사주 해석 | "나 왜 신약사주야?" | 개인 답이면 필요(이론 질문은 불필요) | `askTeacher` |
| 오늘 일진 | "오늘 왜 이렇게 의욕 없지?" | 필요 | `askTeacher`(+오늘 근거) |
| 점성술 | "내 새턴리턴 곧이야?" | 생년월일시 필요 | `askTeacher`(+점성술 근거) |
| 사주+점성술 통합 | "사주랑 별자리 같이 보면?" | 생년월일시 필요 | `askTeacher`(+통합 근거) |
| **타로** | "타로로 이번 연애 봐줘" | **불필요** | `askTarot` |
| 궁합 | "1993… 여, 1995… 남 연인" | 필요 | `askCompatibility` |
| 자기분석/기획/글쓰기/판단(비서) | "나 왜 자꾸 미루지?" | 선택 | `askSecretary` |
| 기억 저장/조회 | "이거 기억해둬" / "뭐 기억해?" | 불필요 | 결정론 + 라우터 |
| 기억 삭제/대화 초기화/보안확인 | "잊어줘" / "대화 초기화" / "보안 알려줘" | 불필요 | 결정론(키워드) |

핵심 두 축:
1. **타로를 봇에 신규 추가** — 스프레드 자동 선택 · 카드 뽑기 · 근거 직렬화 · 후속 질문 맥락 유지.
2. **맥락 인지 스마트 라우터** — 최근 대화 + 등록 상태를 함께 보고 100% 자연어/후속 질문을 이해. 파괴적 동작만 결정론 키워드로 안전 처리.

---

## 1. 메시지 처리 흐름 (`bot/messageHandler.ts` `handleMessage`)

들어온 텍스트는 위에서부터 순서대로 검사됩니다. 먼저 매치되는 단계에서 처리하고 `return`.

```
0. 접근 제어  — ALLOWED_IDS 지정 시 등록된 텔레그램 user id만 통과
1. 슬래시 명령 — /start /birth /reset /delete /privacy /help /saju /today
                 /타로 /tarot /궁합 /compat  (+ "/타로 <질문>" 즉시 뽑기)
2. 궁합 대기 상태(pending=compat)면 이 입력을 상대방 사주로 해석
3. 한 메시지에 두 사람 생년월일시  → 명령어 없이 바로 궁합
4. 생년월일시 형태 입력            → 등록/재등록 (+동시에 온 질문이면 바로 답)
5. 만세력 사주팔자(여덟 글자) 입력  → 등록/재등록 (+실제 생일 역산 → 대운까지)
6. 연·월주만 준 부분 팔자          → 최소 일주 필요 안내
7. /today · /퀴즈 특수 처리
8. 그 외 자유 텍스트 → 아래 "의도 분류 2단계"
```

### 8단계: 의도 분류 2단계 (핵심)

```
[1단계] 결정론 키워드(detectIntent) — 파괴적 동작만 여기서 확정
  ├─ resetContext  → 대화 기록 초기화
  └─ memoryDelete  → 기억 삭제
     (되돌릴 수 없으므로 LLM 판단에 맡기지 않고 명시적 키워드로만)

[2단계] 맥락 인지 라우터(routeMessage) — 나머지 전부
  최근 대화 6턴 + 등록 상태(사주/생일/타로) + 키워드 힌트를 빠른 모델에 넘겨
  아래 중 하나로 확정 → 디스패치
    privacyCheck / memoryLookup / memorySave
    tarotReading(+newDraw/tarotFollowUp)
    selfAnalysis / planning / writing / decision   (비서)
    sajuReading / astrologyReading / combinedReading / todayFlow / generalChat (teacher)
```

라우터가 꺼져 있거나(실패 시) 키워드 결과로 안전하게 폴백합니다.

---

## 2. 타로 리딩 (신규)

파일: `bot/tarotReading.ts`, `bot/teacher.ts`(`askTarot`), 상태: `bot/storeTypes.ts`(`lastTarot`).
웹앱 계산 엔진(`src/lib/tarot.ts`, `src/lib/tarotSymbolism.ts`)을 그대로 재사용합니다. **카드는 프로그램이 뽑고, Claude는 해석만** 합니다(사주와 동일한 안전 원칙).

### 2.1 스프레드 자동 선택 — `selectSpread(question)`

사용자가 스프레드 이름을 몰라도 질문의 결로 배열을 고릅니다. 위에서부터 먼저 매치되는 것이 이깁니다.

| 우선순위 | 트리거(예) | 스프레드 | 장수 |
|---|---|---|---|
| 1 | "할까 말까", "둘 중", "비교", "A vs B", "아니면?" | `ab` (두 선택지 비교) | 5 |
| 2 | 연애·사랑·썸·재회·이별·남친/여친·관계·그 사람 마음 | `relation` (관계 속마음·흐름) | 5 |
| 3 | 이번 달·한 달·이달·월간·다음 달·주차 | `month` (한 달 흐름) | 5 |
| 4 | 깊게·자세히·정밀·제대로·중요한·켈틱·10장 | `celtic` (켈틱크로스) | 10 |
| 5 | 문제·해결·막힘·"어떻게 해야"·조언 | `soa` (문제와 해결책) | 3 |
| 6 | 한 장·1장·원카드·간단·빨리·핵심만 | `one` (핵심 1장) | 1 |
| 7 | 전체적으로·여러 각도·넓게·5장 | `five` (상황 정밀) | 5 |
| 기본 | 그 외 전부 | `ppf` (과거-현재-흐름) | 3 |

### 2.2 카드 뽑기 — `drawForQuestion(question, spreadOverride?)`

- 웹앱 `drawSpread(spreadId, "classic")` 사용. 78장 덱을 고르게 섞어 스프레드 장수만큼 뽑고, **각 카드 50% 확률로 역방향**.
- 각 카드는 `positionLabel`(자리 의미)과 `reversed`(정/역)를 가집니다.
- `spreadOverride`를 주면 그 배열로 강제(예: `/타로`는 질문 결로 자동, 테스트는 고정).

### 2.3 근거 직렬화 — `buildTarotEvidenceText(spreadId, cards, question)`

웹앱 `systemPrompt.ts`와 **동일한 밀도**의 근거 블록을 만듭니다.

- `[타로 계산 데이터]` — 스프레드 이름/장수, **자리 의미**(positions), 배열별 해석 지침(`note`).
- `[뽑힌 카드]` — 카드마다: 정/역 의미 + 상징 원형(archetype) + 상징 키워드 + 그림 단서 + 숫자/단계 의미 + 슈트 의미.
- `[타로 조합 진단]` — 정/역 비율, 메이저 비율, 반복 슈트, 흐름 축(첫 카드→마지막 카드).
- `[원소 조합(엘리멘탈 디그니티)]` — `describeElementalDignities`: 원소 분포, 인접 자리 강화/약화, 중심/빠진 에너지.
- `[질문]` — 사용자의 질문(없으면 자리·흐름 중심 안내).

### 2.4 리딩 생성 — `askTarot` + 타로 전용 시스템 프롬프트 (`bot/teacher.ts`)

`runStream()`을 재사용(모든 Claude 호출 지점을 하나로 유지)하되, 타로 전용 시스템 프롬프트를 넘깁니다. 프롬프트 규칙 요약:

- 근거: 첨부된 카드만. 없는 카드/상징 지어내기 금지.
- 각 카드는 **자리 의미 + 정/역방향을 함께** 읽는다.
- 원소 조합·조합 진단으로 배열 전체 결을 먼저 잡고 개별 카드를 엮는다(카드 하나씩 나열 금지).
- 스프레드 `note`(예: 선택 비교는 A열/B열)를 따른다.
- 카드 이름 나열이 아니라 **질문 상황에서 현실로** 번역, 흐름 축으로 이야기 잇기, 마지막에 오늘/이번 주 행동 1~2개.
- **안전**: 이별·재회·결혼·합격·죽음·질병을 "된다/안 된다"로 단정 금지. "~쪽으로 기운다" 수준. '나쁜 카드'·역방향도 흉으로만 몰지 않고 '풀어야 할 과제'로. 건강은 컨디션까지만.
- 항상 한국어, 텔레그램 톤(짧게, 굵게는 `*별표*` 한 쌍).

### 2.5 후속 질문 맥락 유지 (문맥 이해의 핵심)

- 새로 뽑으면 `store.setLastTarot()`로 스프레드를 저장: `{ spreadId, question, cards, drawnAt }` (`StoredTarot`).
- **"그 카드 무슨 뜻이야?", "한 장 더 뽑아줘"** 같은 후속은:
  - `newDraw=false, tarotFollowUp=true` → 저장된 같은 카드를 근거로 이어서 답(`isFollowUp=true`).
  - "다시/한 장 더/새로 뽑아" 등 → `newDraw=true` → 새 스프레드를 뽑아 저장 갱신.
- `lastTarot`은 **대화 맥락 TTL 만료 · 사주 재등록 · `/reset`** 시 함께 비워집니다(오래된 카드가 남지 않게).

### 2.6 사용자 경험

새로 뽑을 때: ① "🃏 스프레드명 — N장 뽑았어요" + 자리별 카드 목록을 먼저 보내고(`describeDrawnCardsShort`), ② 이어서 해석을 스트리밍합니다.

---

## 3. 맥락 인지 스마트 라우터 (`bot/smartRouter.ts`)

### 3.1 왜 필요한가

기존 `detectIntent`(정규식 키워드)는 **현재 한 줄만** 보고 판단해서 맥락 의존 표현을 놓쳤습니다.
- "그럼 연애는?"(직전 주제 이어가기), "한 장 더"(타로 후속), "아까 그 카드" 등을 이해 못 함.
- 대표 버그: **"내 사주 기억해?"**(질문)를 `기억해` 키워드만 보고 **저장 명령**으로 오인 → §5.

### 3.2 동작

`routeMessage({ text, history, keywordHint, hasSaju, hasBirth, hasTarot })` →
`{ intent, newDraw, tarotFollowUp, usedLlm }`.

- 최근 대화 6턴 + 등록 상태 + 키워드 힌트를 **빠른 모델**에 넘겨 의도 하나를 JSON으로 받음(`temperature:0`).
- 애매하면 키워드 힌트를 존중(프롬프트에 명시). tarot일 때만 `newDraw`/`tarotFollowUp`을 정하고, 상태와 모순되면 규칙으로 교정(예: 뽑은 카드 없으면 무조건 `newDraw`).
- 반환 가능한 의도(`RoutableIntent`)에는 **파괴적 동작(memoryDelete·resetContext)이 없음** — 그건 라우터 이전에 키워드로 확정됩니다.

### 3.3 안전 설계 (무엇을 LLM에 맡기고, 무엇을 안 맡기나)

| 동작 | 성격 | 판정 방식 |
|---|---|---|
| memoryDelete(기억 삭제) | **되돌릴 수 없음** | 결정론 키워드만 |
| resetContext(대화 초기화) | **되돌릴 수 없음** | 결정론 키워드만 |
| memorySave(기억 추가) | 되돌릴 수 있음 | 라우터(맥락) |
| memoryLookup(기억 조회) | 읽기 전용 | 라우터(맥락) |
| privacyCheck(보안 확인) | 읽기 전용 | 라우터(맥락) |
| 사주/타로/점성/비서/일반 | 부작용 없음 | 라우터(맥락) |

### 3.4 견고성 · 폴백

- 라우터 실패(API 오류)·비활성 시 `fallbackRoute`가 키워드 힌트로 안전 폴백(`heuristicTarotFlags`로 타로 플래그 보완).
- `narrowHint`: 폴백에서 키워드가 파괴적 의도(delete/reset)면 방어적으로 `generalChat`으로 좁힘.

### 3.5 환경변수

| 변수 | 기본값 | 설명 |
|---|---|---|
| `BOT_SMART_ROUTER` | `1`(on) | `0`/`false`/`off`면 라우터 끄고 키워드만 사용(지연·비용↓, 문맥 이해↓) |
| `BOT_ROUTER_MODEL` | `claude-haiku-4-5-20251001` | 라우터가 쓸 빠른 분류 모델 |

> 비용/지연: 라우터 ON이면 비보안 자유 텍스트마다 haiku 1콜이 본 답변 앞에 추가됩니다. 문맥 이해를 위한 의도적 트레이드오프이며 위 변수로 끌 수 있습니다.

---

## 4. 의도 목록 (`bot/intentDetector.ts` `DetectedIntent`)

| 의도 | 뜻 | 처리 |
|---|---|---|
| `sajuReading` | 사주/명리 해석, 사주 보유·등록 여부 질문 | teacher |
| `astrologyReading` | 서양·베딕 점성술 | teacher(+점성술 근거) |
| `tarotReading` | 타로 리딩/후속 | askTarot |
| `combinedReading` | 사주+점성술 함께 | teacher(+통합 근거) |
| `todayFlow` | 오늘 일진/흐름 | teacher(+오늘 근거) |
| `selfAnalysis` | 자기성찰 | secretary |
| `planning` | 기획/개발/MVP/작업지시서 | secretary |
| `writing` | 글 다듬기/이메일/카피 | secretary |
| `decision` | 선택/우선순위 판단 | secretary |
| `memorySave` | "기억해둬"(저장 **명령**) | 기억 추가 |
| `memoryLookup` | "뭐 기억해?"(조회 **질문**) | 기억 목록 |
| `memoryDelete` | "잊어줘/기억 지워" | 기억 삭제(키워드) |
| `privacyCheck` | 보안·개인정보 방식 질문 | 정책 안내 |
| `resetContext` | 대화 초기화 | 히스토리 초기화(키워드) |
| `generalChat` | 그 외 잡담/일반 | teacher |

타로 키워드 규칙: `타로`는 명확히 매치, `카드`는 뽑기/점/리딩 맥락이 붙을 때만(신용카드·교통카드 오분류 방지).

---

## 5. "기억해?"(질문) → 저장 오인 버그 수정

**증상(스크린샷):** "내 사주기억해?"(기억하고 있냐는 질문)에 봇이 "기억해뒀어요 ✅ (저장할 내용이 없음)"으로 잘못 저장.
**원인:** greedy 규칙 `/기억해\s*(줘|둬|주세요)?/`가 어미 없는 "기억해?"까지 저장 명령으로 매치.

**수정:**
- `intentDetector.ts`에서 기억 규칙을 **질문/명령으로 분리**하고, 조회(질문)를 저장(명령)보다 먼저 검사.
  - `memoryLookup`(질문): `기억해?`, `기억하고 있어?`, `뭐/무슨 기억`, `기억 나?` 등(물음표 또는 `있어/나/니` 요구).
  - `memorySave`(명령): `기억해줘/둬/놔`, `저장해줘`, `메모해줘` 등 **명시적 저장 어미**만. 어미 없는 `기억해?`는 제외.
- 저장/조회/보안은 라우터가 최종 판단(질문 vs 명령). 파괴적 삭제·초기화만 키워드 선처리.

**검증(회귀 테스트):**

| 입력 | 이전 | 현재 |
|---|---|---|
| "내 사주 기억해?" | memorySave ❌ | memoryLookup ✅ |
| "기억해?" | memorySave ❌ | memoryLookup ✅ |
| "기억하고 있어?" | generalChat | memoryLookup ✅ |
| "기억해줘" | memorySave | memorySave ✅ |
| "기억해둬" | memorySave | memorySave ✅ |

---

## 6. 명령어

| 명령 | 동작 |
|---|---|
| `/start` | 안내(자연어로 사주·타로·점성술 다 됨을 포함) |
| `/birth` | 생년월일시 등록 안내 |
| `/saju` | 원국 요약(API 호출 없음) |
| `/today` | 오늘 일진 상세 |
| `/타로`, `/tarot` | 타로 안내 |
| `/타로 <질문>`, `/tarot <질문>` | 질문 결로 즉시 뽑기 |
| `/궁합`, `/compat` | 궁합 시작(상대 사주 대기) |
| `/퀴즈` | 배운 개념 복습 문제 |
| `/reset` | 대화 맥락 초기화(등록 유지, `lastTarot`도 비움) |
| `/delete` | 사주·기억·대화 전체 삭제 |
| `/privacy` | 보안/개인정보 정책 |
| `/help` | 자연어 사용 예시 + 명령 목록 |

> 명령어는 전부 **선택**입니다. 자연어만으로 동일 기능 사용 가능.

---

## 7. 상태(저장) 모델 (`bot/storeTypes.ts`)

`UserRecord`:

| 필드 | 뜻 |
|---|---|
| `birthInfo` | 생년월일시 등록(점성술·궁합·대운 가능) |
| `pillars` | 만세력 팔자 직접 등록(birthInfo와 상호배타) |
| `history` | 최근 대화(최대 `MAX_HISTORY=40`턴) |
| `historyExpiresAt` | 맥락 TTL(`BOT_HISTORY_TTL_MINUTES`, 기본 45분). 지나면 history·`lastTarot` 자동 비움 |
| `pending` | 다단계 흐름 대기(궁합) |
| **`lastTarot`** | **마지막 타로 스프레드(후속 질문 맥락용). `StoredTarot{spreadId, question, cards, drawnAt}`** |
| `memories` | "기억해줘"로 저장된 짧은 요약(원문 저장 금지, TTL 없음) |

저장소 구현 2종(같은 인터페이스): 롱폴링 = `fileStore.ts`(로컬 JSON), 웹훅 = `kvStore.ts`(Upstash Redis).
새 메서드 `setLastTarot(chatId, tarot|null)` 양쪽에 구현. `setBirthInfo`/`setPillars`/`clearHistory`가 `lastTarot`도 초기화.

---

## 8. 안전·개인정보 원칙 (유지)

- **개인 전용**: `ALLOWED_IDS` 지정 시 등록 사용자만. 그 외 메시지는 Claude로 전달 안 함.
- **계산은 프로그램, 해석만 Claude**: 사주·점성술·타로 모두 근거를 프로그램이 계산해 넘기고 Claude는 그 안의 값만 해석(없는 카드/간지/배치 지어내기 금지).
- **로그 최소화**: 대화·질문·응답 원문 미기록(요청 ID·지연·토큰 수 정도만).
- **맥락 TTL**: history·lastTarot은 기본 45분 뒤 자동 소멸.
- **기억은 명시적 요청만**: 원문이 아니라 요약으로만 저장, "잊어줘"로 즉시 삭제.
- **파괴적 동작은 결정론 키워드로만**: 삭제·초기화는 LLM 오판으로 실행되지 않게.
- **비단정·비운명론**: 겁주는 말·확정 예언 금지. 큰 결정(퇴사·투자·이혼 등)은 판단 기준만.

---

## 9. 파일 맵 (이번 작업 관련)

| 파일 | 역할 | 상태 |
|---|---|---|
| `bot/tarotReading.ts` | 스프레드 선택·카드 뽑기·근거 직렬화·카드 헤더 | 신규 |
| `bot/tarotReading.test.ts` | 스프레드 선택/뽑기/근거 테스트 | 신규 |
| `bot/smartRouter.ts` | 맥락 인지 라우터(+폴백/휴리스틱) | 신규 |
| `bot/smartRouter.test.ts` | 폴백·휴리스틱·라우터 OFF 테스트 | 신규 |
| `bot/teacher.ts` | `askTarot` + 타로 시스템 프롬프트 추가 | 수정 |
| `bot/intentDetector.ts` | `tarotReading` 규칙 + 기억 질문/명령 분리 | 수정 |
| `bot/intentDetector.test.ts` | 타로·"기억해?" 회귀 테스트 | 수정 |
| `bot/messageHandler.ts` | 타로 핸들러 + 2단계 라우팅 배선 + `/타로` | 수정 |
| `bot/storeTypes.ts` | `StoredTarot`/`lastTarot`/`setLastTarot` | 수정 |
| `bot/fileStore.ts`, `bot/kvStore.ts` | `setLastTarot` 구현·초기화 배선 | 수정 |
| `bot/README.md`, `.env.example` | 사용법·환경변수 문서 | 수정 |

재사용(웹앱, 불변): `src/lib/tarot.ts`(`SPREADS`/`drawSpread`), `src/lib/tarotSymbolism.ts`(상징·엘리멘탈 디그니티), `src/lib/astrology.ts`(점성술).

---

## 10. 환경변수 요약

| 변수 | 기본 | 용도 |
|---|---|---|
| `ANTHROPIC_API_KEY` | (필수) | Claude 호출 |
| `TELEGRAM_BOT_TOKEN` | (필수) | 봇 실행 |
| `TELEGRAM_ALLOWED_USER_IDS` / `ALLOWED_TELEGRAM_USER_IDS` | — | 접근 제어(합집합) |
| `BOT_MODEL` | `claude-opus-4-8` | 리딩 모델 |
| `BOT_ROUTER_MODEL` | `claude-haiku-4-5-20251001` | 라우터 모델 |
| `BOT_SMART_ROUTER` | `1` | 맥락 라우터 on/off |
| `BOT_VERBOSITY` | `normal` | 답변 길이 상한(brief 900 / normal 1800 / detailed 8000 토큰) |
| `BOT_TEMPERATURE` | (SDK 기본) | 온도 |
| `BOT_HISTORY_TTL_MINUTES` | `45` | 맥락 TTL |
| `BOT_DATA_DIR` | `bot/data` | 롱폴링 저장 위치 |
| `UPSTASH_REDIS_REST_URL` / `_TOKEN` | — | 웹훅 저장소 |

---

## 11. 검증

- `npm test` — 봇 관련 신규/회귀 포함 전체 그린(라우터 LLM 경로는 네트워크 없이 폴백/휴리스틱만 단위 테스트).
- `npm run build` — 클린(Vite 청크 500kB 경고는 기존 사항, 실패 아님).
- 배포: `main` 푸시 → Vercel 배포(웹훅 함수 `api/telegram-webhook.ts` 포함) → 텔레그램 반영.
- 실사용 육안 검증 남음: 실제 텔레그램 왕복(봇 토큰·API 키 있는 환경)에서 타로 뽑기→후속, "내 사주 기억해?" 등 확인.
