# DESIGN SYSTEM — 지금 (Editorial)

> Claude Code 상시 참조 문서. 새 기능·페이지·컴포넌트를 만들 때 **반드시 이 토큰과 규칙을 따른다.**
> 하드코딩된 색/간격/폰트 값 대신 항상 아래 토큰을 사용한다.
>
> **버전:** Editorial v1 (편집 디자인 전환). 이전 "보라 accent" 버전은 폐기됨.

---

## 0. 디자인 원칙 (모든 판단의 기준)

이 앱의 미학은 **"종이 + 잉크 한 색"** — 잡지·불릿저널 같은 **편집(에디토리얼) 감각**이다.
색을 더해서 감각을 내지 않는다. **타이포그래피·기호·여백**으로 낸다.

1. **색은 잉크 하나로 민다.** 화면은 종이 배경 + 잉크색 한 종류. 포인트 컬러(`mark`)는 **긴급(URGENT) 한 곳에만.** 화면당 유채색 포인트는 사실상 0~1개.
2. **타이포가 주인공.** 감각은 폰트 대비·자간·대문자·규칙선에서 나온다. 장식·그림자·둥근 모서리로 만들지 않는다.
3. **두 벌 폰트 = 하이브리드.** 한글 내용은 산세리프(Pretendard), 라벨·기호·영문·숫자는 모노스페이스. 이 대비가 톤의 핵심. (§3, §9 참조)
4. **섹션은 잡지 목차처럼.** 대문자 모노 라벨 + 카운트 + 규칙선(`TO-DO / 3 ────`). 카드·박스로 나누지 않는다.
5. **기호 문법.** 체크박스는 배지가 아니라 글리프(□ → ■). 우선순위는 알약이 아니라 우측 대문자 라벨(URGENT / IMPORTANT).
6. **모서리는 각지게, 그림자는 없이.** `radius = 0`. 앱 내부에 그림자를 쓰지 않는다. 경계는 1px 규칙선으로만.
7. **간격은 4px 리듬 + 22px 여백(editorial gutter).** 화면 좌우 여백 22px는 잡지 마진의 시그니처. 임의 값 금지.
8. **모든 상태를 정의한다.** normal / hover / active / disabled / empty / invalid / loading 을 빠뜨리지 않는다 (§6).

### 라벨 언어 규칙 (중요)
- **구조 라벨 = 영문 대문자 모노:** 섹션(`TO-DO` `LATER` `DONE`), 탭(`today` `all`…), 우선순위(`URGENT` `IMPORTANT`), 메뉴(`≡ MENU`)
- **내용·안내문 = 한글 산세리프/모노:** 할 일 제목("빨래하기"), 빈 상태("— 담아둔 게 없어요"), 입력 placeholder("빠르게 담기_"), 칩("중요" "긴급" "오늘")
- 이 하이브리드가 확정 방향이다. 전부 한글로 바꾸고 싶으면 구조 라벨만 아래 대응표로 교체 (무드는 조금 죽지만 명료):
  `TO-DO→할 일 · LATER→나중에 · DONE→완료 · today→오늘 · all→전체 · URGENT→긴급 · IMPORTANT→중요`

---

## 1. 색 (Color) — 6토큰 잉크 시스템

이 앱의 색은 **의미 6개**로 끝난다. 테마가 바뀌어도 토큰 이름은 그대로, 값만 바뀐다.

| 토큰 | 의미 | 용도 |
|---|---|---|
| `paper` | 종이 | 기본 배경 |
| `paper-2` | 종이(짙음) | 눌린 상태·구분되는 면·선택 배경 |
| `ink` | 잉크 | 본문·제목·활성 요소·마스트헤드 규칙선 |
| `ink-soft` | 흐린 잉크 | 메타·카운트·placeholder·우선순위(중요)·비활성 |
| `line` | 규칙선 | 얇은 구분선·섹션 fill·카드 없는 경계 |
| `mark` | 포인트 | **긴급(URGENT)·프롬프트 캐럿에만.** 유일한 유채색 포인트 |

> **철칙:** `mark`를 장식으로 쓰지 않는다. 오직 "긴급"과 프롬프트 캐럿(›)뿐. 링크·아이콘·선택 상태는 `ink`로 표현한다.

### 기능 상태색 (functional only — 테마 무관, 극소량)
폼 검증·시스템 피드백 전용. 장식 금지. 편집 톤에 맞춰 채도를 낮춘다.

| 토큰 | 값 | 용도 |
|---|---|---|
| `success` | `#4F7A4A` | 유효·저장 완료 |
| `warning` | `#B08A2E` | 주의 |
| `error` | `#B0392E` | 오류·무효 입력 |
| `disabled` | = `ink-soft` (opacity 0.5) | 비활성 |

> 규칙: 위 밖의 색을 새로 만들지 않는다. "긴급/포인트"는 `mark`, 그 외 강조는 `ink`. 새 의미가 필요하면 이 파일에 토큰을 추가하고 나서 쓴다.

---

## 1-1. 테마 (Theme) — 내장 10종

사용자가 앱에서 고르는 테마. 각 테마는 위 6토큰(`paper / paper-2 / ink / ink-soft / line / mark`)의 값 세트다.
**9종 라이트 + 1종 다크(NOIR).** 기본값 = **MANILA**. 다크 모드 = **NOIR**.

| key | 이름 | 설명 | paper | paper-2 | ink | ink-soft | line | mark |
|---|---|---|---|---|---|---|---|---|
| `manila` | MANILA | 크림 종이 · 벽돌빛 (기본) | `#F4F1EA` | `#EFEBE2` | `#26241F` | `#9A948A` | `#D8D2C6` | `#B5443A` |
| `newsprint` | NEWSPRINT | 신문지 회백 · 선홍 | `#EDEBE6` | `#E6E3DC` | `#1C1C1A` | `#8C8A84` | `#D2CFC8` | `#C4362B` |
| `sage` | SAGE | 세이지 그린 · 이끼 | `#E9EAE0` | `#E1E3D6` | `#2E362B` | `#949A88` | `#CFD3C3` | `#5E7048` |
| `midnight` | MIDNIGHT | 아이보리 · 남색 잉크 | `#EFE9DD` | `#E8E1D2` | `#1B2A3A` | `#8C93A0` | `#D5CFC0` | `#B5443A` |
| `terracotta` | TERRACOTTA | 흙빛 · 구운 주황 | `#F0E4D8` | `#E9DACB` | `#3A2A20` | `#A8917E` | `#E0CCB8` | `#C0603A` |
| `olive` | OLIVE | 올리브 · 카키 | `#EAE7D6` | `#E2DEC9` | `#33321F` | `#9A9678` | `#D3CFB6` | `#7A6A2E` |
| `slate` | SLATE | 차가운 회청 · 먹 | `#E6E8EA` | `#DDE0E3` | `#23292E` | `#8A9196` | `#CDD1D4` | `#4A5A66` |
| `rose` | DUSTY ROSE | 흐린 장미 · 자두 | `#F0E7E4` | `#E9DBD7` | `#322523` | `#A8908C` | `#DDCCC8` | `#A64B54` |
| `plum` | PLUM | 연보라 회색 · 자수정 | `#ECE6EA` | `#E3DBE1` | `#2C2330` | `#978C9C` | `#D6CCD6` | `#7A4A6E` |
| `noir` | NOIR (DARK) | 먹지 · 크림 잉크 (다크) | `#201E1A` | `#2A2722` | `#EDE7D9` | `#7A756B` | `#3A3630` | `#D46A4A` |

**적용 방식**
- 테마는 6개 CSS 변수(또는 Flutter 상수)만 스왑한다. 컴포넌트 코드는 절대 색을 하드코딩하지 않는다 → 토큰만 참조하면 10종이 자동 대응.
- `mark`는 테마마다 성격이 다르지만(벽돌/선홍/이끼…) **역할은 동일**: 긴급 + 캐럿.
- **NOIR 주의:** paper가 어둡고 ink가 밝다. `paper`/`ink`가 뒤집히므로 "밝은 배경 가정"을 코드에 넣지 말 것(예: 검정 하드코딩 그림자). 토큰만 쓰면 자동 처리됨.
- 스위치 UI: 스와치 3색 바 순서는 **paper / ink / mark**. 선택된 테마는 `ink` 1.5px 테두리로 표시.

---

## 2. 간격 (Spacing)

**기본 리듬 = 4px 배수.** 단, 편집 레이아웃 상수는 예외로 지정된 값을 그대로 쓴다.

### 스케일 (4px 배수)
| 토큰 | 값 |
|---|---|
| `space-1` | 4px |
| `space-2` | 8px |
| `space-3` | 12px |
| `space-4` | 16px |
| `space-5` | 24px |
| `space-6` | 32px |
| `space-8` | 48px |

### 편집 레이아웃 상수 (이 값들이 "잡지 느낌"을 만든다 — 반올림하지 말 것)
| 토큰 | 값 | 용도 |
|---|---|---|
| `gutter` | **22px** | 화면 좌우 여백 (마스트헤드·보드·프롬프트·nav 공통). 시그니처 |
| `section-gap` | 26px 위 / 12px 아래 | 섹션 라벨 상하 여백 |
| `row-pad-y` | 11px | 할 일 한 줄 상하 패딩 |
| `task-gap` | 14px | 글리프 ↔ 제목 ↔ 우선순위 사이 |
| `chip-gap` | 8px | 칩 사이 |

**적용 규칙**
- 좌우 여백은 **항상 `gutter`(22px)**. 카드 안에서 다시 들여쓰지 않는다(카드가 없으니까).
- 섹션 사이 리듬은 `section-gap`으로 통일 — 화면마다 다르게 주지 말 것.
- 관련 요소 묶음 내부: `space-2`(8px). 블록 내부: `space-3`(12px).

---

## 3. 폰트 (Typography) — 두 벌 하이브리드

**두 벌 시스템 (§9에 한글+모노 트레이드오프 상세)**
- **한글 내용 = 산세리프:** Pretendard (없으면 system-ui)
- **라벨·기호·영문·숫자 = 모노:** JetBrains Mono (없으면 monospace)

**자간(letter-spacing)이 편집 감각의 절반이다.** 대문자 모노 라벨엔 반드시 트래킹을 준다.

**크기 위계 — 고정 (늘리지 말 것)**
| 토큰 | 크기 / 굵기 | 폰트 | 자간 | 용도 |
|---|---|---|---|---|
| `h-title` | 19px / Bold | **Sans** | -0.01em | 화면 타이틀 ("전체") |
| `body` | 15px / Medium | **Sans** | -0.01em | 할 일 제목·본문 (한글) |
| `sec-label` | 11px / Bold | **Mono** | **+0.14em** | 섹션 대문자 라벨 (TO-DO) |
| `pri-label` | 10px / Reg·Bold | **Mono** | **+0.12em** | 우선순위 (URGENT / IMPORTANT) |
| `meta` | 11px / Reg | **Mono** | +0.05em | 카운트(/ 3)·메뉴·빈 상태·시간 |
| `nav` | 10px / Reg·Bold | **Mono** | +0.04em | 하단 탭 (소문자: today) |
| `chip` | 10px / Reg | **Mono** | +0.08em | 빠른 태그 칩 (한글 가능) |
| `glyph` | 15px | **Mono** | — | 체크박스·기호 (□ ■ ›) |

> 섞지 말 것: 한글 제목에 모노, 라벨/숫자에 산세리프 → 두 벌 규칙 위반. §9 참조.

---

## 4. 반경 · 선 · 그림자

| 토큰 | 값 | 비고 |
|---|---|---|
| `radius` | **0** | 각진 모서리가 편집 시그니처. 칩·프롬프트·nav 전부 각지게. 둥글게 만들지 말 것 |
| `rule` | 1px `ink` | 마스트헤드(헤더 아래) 강한 규칙선 |
| `rule-thin` | 1px `line` | 섹션 fill·프롬프트 상단선·nav 상단선 |
| `underline-active` | 1.5px `ink` | 활성 탭·선택 표시 밑줄 |
| `shadow` | **none** | 앱 내부 그림자 금지. (디자인 목업의 폰 프레임 그림자는 앱 UI가 아님) |

---

## 5. 핵심 컴포넌트 규격

정확한 수치는 preview3 기준. 토큰으로 환산해 사용한다.

### 헤더 (마스트헤드)
- padding `22px 22px 14px` (`gutter`)
- 좌: 화면 타이틀 `h-title`(Sans 19/Bold) — 한글
- 우: `≡ MENU` — `meta`(Mono 11 +0.08em) `ink-soft`
- 바로 아래 **강한 규칙선 `rule`** (1px `ink`, 좌우 `gutter` 인셋)

### 섹션 라벨 (잡지 목차)
- margin `section-gap` (26 위 / 12 아래), 요소 간 gap 12px
- 구성: `이름`(대문자 `sec-label`) + `/ n`(카운트 `meta` `ink-soft`) + `fill`(남는 폭 1px `rule-thin`)
- 예: `TO-DO  / 3  ─────────────────`
- 카드·박스로 감싸지 않는다. 라벨+규칙선이 곧 구분.

### 할 일 아이템
- padding `11px 0`(`row-pad-y`), gap `14px`(`task-gap`)
- 좌: **글리프** □(16px 폭, 가운데정렬, `glyph`) → 클릭 시 ■
- 중: **제목** `body`(Sans 15/Medium) — 한글
- 우: **우선순위 라벨** `pri-label`(Mono 대문자)
  - `URGENT` → `mark` + Bold (유일한 포인트색 사용처)
  - `IMPORTANT` → `ink-soft`
  - 없으면 우측 비움 (배지 만들지 말 것)
- 완료(done): 글리프 ■, 제목 `ink-soft` + 취소선

### 체크박스 = 글리프
- `□` 미완료 / `■` 완료. 원형 체크박스·색 채움 쓰지 않는다.
- hover: 글리프 색 `ink`로 진하게(기본 `ink`면 `paper-2` 배경 살짝). active: `paper-2`.

### 빈 상태 (empty)
- `meta`(Mono 11) `ink-soft`, **앞에 em-dash "— "**
- 예: `— 담아둔 게 없어요` / `— 아직 완료한 일이 없어요`
- 한 줄, 담백하게. 느낌표·이모지 금지.

### 빠른 담기 (터미널 프롬프트)
- padding `12px 22px 8px`(`gutter`)
- **칩 줄:** `chip`(Mono 10 +0.08em) `ink-soft`, 1px `line` 테두리, padding `5px 10px`, `radius 0`, 한글 허용("중요"/"긴급"/"오늘")
- **프롬프트 줄:** 상단 `rule-thin`(1px, 단 여기선 `ink` 권장), padding-top 10px
  - 캐럿 `›` : `glyph` 13px, **`mark`** (포인트색 두 번째 사용처)
  - placeholder `빠르게 담기_` : `meta`(Mono 12) `ink-soft`, 끝에 언더스코어 커서

### 하단 탭 (nav)
- padding `14px 22px 20px`(`gutter`), 상단 `rule-thin`
- 탭: `nav`(Mono 10 소문자) `ink-soft` — `today / matrix / outline / routine / habit / all`
- 활성: `ink` + Bold + 하단 `underline-active`(1.5px `ink`), padding-bottom 2px

---

## 5-1. 기호 문법 (Glyph Grammar)

불릿저널 감성. **아래 세트만 쓴다.** 새 기호를 함부로 늘리지 않는다(기호 동물원 금지).

| 기호 | 의미 |
|---|---|
| `□` / `■` | 할 일 미완료 / 완료 |
| `›` | 프롬프트 캐럿 (mark) |
| `—` | 빈 상태·리스트 대시 접두 |
| `/` | 카운트 구분자 (TO-DO / 3) |
| `≡` | 메뉴 |

**확장(아껴서):** `●`/`○` 루틴 on/off · `★` 별표 · `△` 잠정. 필요할 때만, §6 상태 정의와 함께 추가.

---

## 6. 새 컴포넌트 만들 때 상태 체크리스트

컴포넌트를 만들 땐 아래 상태를 **명시적으로** 처리한다 (해당되는 것만, 빠뜨리지 말 것):

- [ ] **Interaction**: normal / hover / active(pressed) / focus / selected
- [ ] **가용성**: enabled / disabled
- [ ] **콘텐츠**: 채워짐 / empty(빈 상태 — em-dash 톤) / placeholder
- [ ] **데이터 품질**: valid / invalid (+ `error` 메시지, input hint)
- [ ] **비동기**: loading / 성공 / 실패
- [ ] **키보드**: Enter(담기) / Tab / 방향키 (해당 시)
- [ ] **테마**: 10종 전부에서 색이 토큰으로만 오는지 (특히 NOIR에서 안 깨지는지)

> 리스트/테이블류라면 행(추가·삭제·이동·정렬·필터)과 열(너비 default/min/max) 액션도 정의한다.

---

## 7. 토큰 정의 (스택별 — 골라서 사용)

### 7-1. CSS 변수 (기본 = MANILA)
```css
:root {
  /* --- theme tokens (테마가 스왑하는 6개) --- */
  --paper:    #F4F1EA;
  --paper-2:  #EFEBE2;
  --ink:      #26241F;
  --ink-soft: #9A948A;
  --line:     #D8D2C6;
  --mark:     #B5443A;

  /* --- functional states (테마 무관) --- */
  --success:  #4F7A4A;
  --warning:  #B08A2E;
  --error:    #B0392E;

  /* --- spacing --- */
  --space-1: 4px;  --space-2: 8px;  --space-3: 12px;
  --space-4: 16px; --space-5: 24px; --space-6: 32px; --space-8: 48px;
  --gutter: 22px;

  /* --- radius / line --- */
  --radius: 0;
  --rule: 1px;

  /* --- type --- */
  --font-sans: 'Pretendard', system-ui, sans-serif;
  --font-mono: 'JetBrains Mono', monospace;
}

/* 타이포 유틸 */
.t-h-title  { font: 700 19px/1.2 var(--font-sans); letter-spacing:-.01em; color:var(--ink); }
.t-body     { font: 500 15px/1.4 var(--font-sans); letter-spacing:-.01em; color:var(--ink); }
.t-sec      { font: 700 11px/1   var(--font-mono); letter-spacing:.14em; color:var(--ink); }
.t-pri      { font: 400 10px/1   var(--font-mono); letter-spacing:.12em; color:var(--ink-soft); }
.t-pri.urgent { color:var(--mark); font-weight:700; }
.t-meta     { font: 400 11px/1.3 var(--font-mono); letter-spacing:.05em; color:var(--ink-soft); }
.t-nav      { font: 400 10px/1   var(--font-mono); letter-spacing:.04em; color:var(--ink-soft); }
.t-nav.active { color:var(--ink); font-weight:700; border-bottom:1.5px solid var(--ink); }
```

```css
/* 테마 스왑: data-theme 속성만 바꾸면 됨 */
[data-theme="newsprint"]{ --paper:#EDEBE6; --paper-2:#E6E3DC; --ink:#1C1C1A; --ink-soft:#8C8A84; --line:#D2CFC8; --mark:#C4362B; }
[data-theme="sage"]     { --paper:#E9EAE0; --paper-2:#E1E3D6; --ink:#2E362B; --ink-soft:#949A88; --line:#CFD3C3; --mark:#5E7048; }
[data-theme="midnight"] { --paper:#EFE9DD; --paper-2:#E8E1D2; --ink:#1B2A3A; --ink-soft:#8C93A0; --line:#D5CFC0; --mark:#B5443A; }
[data-theme="terracotta"]{ --paper:#F0E4D8; --paper-2:#E9DACB; --ink:#3A2A20; --ink-soft:#A8917E; --line:#E0CCB8; --mark:#C0603A; }
[data-theme="olive"]    { --paper:#EAE7D6; --paper-2:#E2DEC9; --ink:#33321F; --ink-soft:#9A9678; --line:#D3CFB6; --mark:#7A6A2E; }
[data-theme="slate"]    { --paper:#E6E8EA; --paper-2:#DDE0E3; --ink:#23292E; --ink-soft:#8A9196; --line:#CDD1D4; --mark:#4A5A66; }
[data-theme="rose"]     { --paper:#F0E7E4; --paper-2:#E9DBD7; --ink:#322523; --ink-soft:#A8908C; --line:#DDCCC8; --mark:#A64B54; }
[data-theme="plum"]     { --paper:#ECE6EA; --paper-2:#E3DBE1; --ink:#2C2330; --ink-soft:#978C9C; --line:#D6CCD6; --mark:#7A4A6E; }
[data-theme="noir"]     { --paper:#201E1A; --paper-2:#2A2722; --ink:#EDE7D9; --ink-soft:#7A756B; --line:#3A3630; --mark:#D46A4A; }
/* (data-theme 없음 = manila 기본) */
```

### 7-2. Tailwind (`tailwind.config.js` extend)
```js
module.exports = {
  theme: {
    extend: {
      colors: {
        // 토큰은 CSS 변수를 참조 → 테마 스왑이 자동 반영됨
        paper:    'var(--paper)',
        'paper-2':'var(--paper-2)',
        ink:      'var(--ink)',
        'ink-soft':'var(--ink-soft)',
        line:     'var(--line)',
        mark:     'var(--mark)',
        success:  '#4F7A4A',
        warning:  '#B08A2E',
        error:    '#B0392E',
      },
      spacing: {
        1:'4px', 2:'8px', 3:'12px', 4:'16px',
        5:'24px', 6:'32px', 8:'48px', gutter:'22px',
      },
      borderRadius: { none: '0' },   // radius=0 원칙
      borderWidth:  { rule: '1px', active: '1.5px' },
      fontFamily: {
        sans: ['Pretendard', 'system-ui', 'sans-serif'],
        mono: ['JetBrains Mono', 'monospace'],
      },
      fontSize: {
        'h-title': ['19px', { lineHeight:'1.2', fontWeight:'700', letterSpacing:'-0.01em' }],
        body:      ['15px', { lineHeight:'1.4', fontWeight:'500', letterSpacing:'-0.01em' }],
        sec:       ['11px', { lineHeight:'1',   fontWeight:'700', letterSpacing:'0.14em' }],
        pri:       ['10px', { lineHeight:'1',   fontWeight:'400', letterSpacing:'0.12em' }],
        meta:      ['11px', { lineHeight:'1.3', fontWeight:'400', letterSpacing:'0.05em' }],
        nav:       ['10px', { lineHeight:'1',   fontWeight:'400', letterSpacing:'0.04em' }],
        chip:      ['10px', { lineHeight:'1',   fontWeight:'400', letterSpacing:'0.08em' }],
      },
      boxShadow: { none: 'none' },   // 앱 내부 그림자 금지
    },
  },
};
```

### 7-3. Flutter (테마 스왑용 구조)
```dart
// 6개 테마 토큰을 담는 클래스 (테마가 이 인스턴스를 통째로 교체)
class AppTheme {
  final Color paper, paper2, ink, inkSoft, line, mark;
  const AppTheme({
    required this.paper, required this.paper2, required this.ink,
    required this.inkSoft, required this.line, required this.mark,
  });

  static const manila = AppTheme(
    paper: Color(0xFFF4F1EA), paper2: Color(0xFFEFEBE2), ink: Color(0xFF26241F),
    inkSoft: Color(0xFF9A948A), line: Color(0xFFD8D2C6), mark: Color(0xFFB5443A));
  static const newsprint = AppTheme(
    paper: Color(0xFFEDEBE6), paper2: Color(0xFFE6E3DC), ink: Color(0xFF1C1C1A),
    inkSoft: Color(0xFF8C8A84), line: Color(0xFFD2CFC8), mark: Color(0xFFC4362B));
  static const sage = AppTheme(
    paper: Color(0xFFE9EAE0), paper2: Color(0xFFE1E3D6), ink: Color(0xFF2E362B),
    inkSoft: Color(0xFF949A88), line: Color(0xFFCFD3C3), mark: Color(0xFF5E7048));
  static const midnight = AppTheme(
    paper: Color(0xFFEFE9DD), paper2: Color(0xFFE8E1D2), ink: Color(0xFF1B2A3A),
    inkSoft: Color(0xFF8C93A0), line: Color(0xFFD5CFC0), mark: Color(0xFFB5443A));
  static const terracotta = AppTheme(
    paper: Color(0xFFF0E4D8), paper2: Color(0xFFE9DACB), ink: Color(0xFF3A2A20),
    inkSoft: Color(0xFFA8917E), line: Color(0xFFE0CCB8), mark: Color(0xFFC0603A));
  static const olive = AppTheme(
    paper: Color(0xFFEAE7D6), paper2: Color(0xFFE2DEC9), ink: Color(0xFF33321F),
    inkSoft: Color(0xFF9A9678), line: Color(0xFFD3CFB6), mark: Color(0xFF7A6A2E));
  static const slate = AppTheme(
    paper: Color(0xFFE6E8EA), paper2: Color(0xFFDDE0E3), ink: Color(0xFF23292E),
    inkSoft: Color(0xFF8A9196), line: Color(0xFFCDD1D4), mark: Color(0xFF4A5A66));
  static const rose = AppTheme(
    paper: Color(0xFFF0E7E4), paper2: Color(0xFFE9DBD7), ink: Color(0xFF322523),
    inkSoft: Color(0xFFA8908C), line: Color(0xFFDDCCC8), mark: Color(0xFFA64B54));
  static const plum = AppTheme(
    paper: Color(0xFFECE6EA), paper2: Color(0xFFE3DBE1), ink: Color(0xFF2C2330),
    inkSoft: Color(0xFF978C9C), line: Color(0xFFD6CCD6), mark: Color(0xFF7A4A6E));
  static const noir = AppTheme(
    paper: Color(0xFF201E1A), paper2: Color(0xFF2A2722), ink: Color(0xFFEDE7D9),
    inkSoft: Color(0xFF7A756B), line: Color(0xFF3A3630), mark: Color(0xFFD46A4A));

  static const all = [manila, newsprint, sage, midnight, terracotta,
                      olive, slate, rose, plum, noir];
}

// 기능 상태색 (테마 무관)
class AppState {
  static const success  = Color(0xFF4F7A4A);
  static const warning  = Color(0xFFB08A2E);
  static const error    = Color(0xFFB0392E);
}

class AppSpace {
  static const s1 = 4.0;  static const s2 = 8.0;  static const s3 = 12.0;
  static const s4 = 16.0; static const s5 = 24.0; static const s6 = 32.0; static const s8 = 48.0;
  static const gutter = 22.0;
}
const kRadius = 0.0; // 각진 모서리 원칙

const _sans = 'Pretendard';
const _mono = 'JetBrainsMono';

// 텍스트 스타일 (색은 현재 AppTheme의 ink/inkSoft를 주입해서 사용)
class AppText {
  static TextStyle hTitle(Color c) => TextStyle(fontFamily:_sans, fontSize:19, fontWeight:FontWeight.w700, height:1.2, letterSpacing:-.19, color:c);
  static TextStyle body(Color c)   => TextStyle(fontFamily:_sans, fontSize:15, fontWeight:FontWeight.w500, height:1.4, letterSpacing:-.15, color:c);
  static TextStyle sec(Color c)    => TextStyle(fontFamily:_mono, fontSize:11, fontWeight:FontWeight.w700, letterSpacing:1.54, color:c); // .14em
  static TextStyle pri(Color c)    => TextStyle(fontFamily:_mono, fontSize:10, fontWeight:FontWeight.w400, letterSpacing:1.2,  color:c); // .12em
  static TextStyle meta(Color c)   => TextStyle(fontFamily:_mono, fontSize:11, fontWeight:FontWeight.w400, letterSpacing:.55, height:1.3, color:c);
  static TextStyle nav(Color c)    => TextStyle(fontFamily:_mono, fontSize:10, fontWeight:FontWeight.w400, letterSpacing:.4,  color:c);
}
```

> 테마 저장: 선택한 테마 key를 로컬(SharedPreferences / localStorage 등)에 저장하고 앱 시작 시 복원. 기본값 `manila`. 시스템 다크모드 연동 시 다크 = `noir`.

---

## 8. 기존 화면 리팩터링 지침 (보라 → 에디토리얼 전환)

> 구조·기능 배치·화면 구성은 **바꾸지 않는다.** 스타일 토큰만 갈아끼운다.
> 아래는 티 나는 순서.

### (1) 색 걷어내기 — 가장 먼저
- 모든 `accent`(보라)·유채색 강조를 제거 → `ink`로. 유일하게 남기는 색은 `mark`(긴급/캐럿)뿐.
- 배경 순백 → `paper`. 카드 배경/그림자 제거, 경계는 1px `line`.

### (2) 배지 → 라벨 (효과 큼)
- 알약 배지 전부 제거. 우선순위는 우측 **대문자 모노 라벨**(URGENT / IMPORTANT).
- 채움/테두리 배지 스타일 폐기.

### (3) 섹션을 목차형으로
- 카드·박스로 묶던 섹션 → **대문자 모노 라벨 + `/ n` 카운트 + fill 규칙선.**
- 예: "할 일 · 3" → `TO-DO / 3 ─────`.

### (4) 체크박스 → 글리프
- 원형 체크박스·색 채움 제거 → `□` / `■` 글리프.

### (5) 모노 전환 + 자간
- 카운트·날짜·숫자·라벨·탭 전부 Mono로. 대문자 라벨엔 자간(+0.12~0.14em) 부여.
- 한글 제목/본문은 Sans 유지 (섞지 말 것).

### (6) 각지게 + 그림자 제거
- 모든 `border-radius` → 0. 모든 `box-shadow` → none.

### (7) 하단/입력 톤
- 하단 입력바(알약) → **터미널 프롬프트**(`› 빠르게 담기_`, 캐럿 `mark`).
- 탭 → 소문자 모노, 활성 = `ink` + 밑줄.

### (8) 빈 상태 통일
- "없어요"·"0개" → em-dash 접두 한 줄 (`— 담아둔 게 없어요`).

---

## 9. 알아둘 트레이드오프 (설계 근거)

이 방향은 원래 영문 에디토리얼 레퍼런스에서 왔다. 그대로 옮길 때 두 지점이 갈린다.

**1. 한글 + 모노스페이스.** 레퍼런스가 전면 모노로 감각적인 건 영문이라 가능했던 것. 한글은 고정폭 모노가 마땅치 않다. 그래서 **할 일 내용(한글)은 Pretendard, 라벨·기호·영문·숫자는 모노**로 섞는 하이브리드가 현실적 정답. (§3) 한글에 모노를 강제하지 말 것.

**2. 영문 구조 라벨.** `TO-DO / today / URGENT`처럼 구조를 영문으로 두면 확 감각적이지만 한국어 UI의 직관성은 살짝 내려간다. 현재 확정 = **영문 유지**(§0 라벨 언어 규칙). 명료함이 더 중요해지면 대응표로 한글화하되, **감각↔명료는 이 축에서만 조절**하고 나머지 규칙은 유지한다.

---

## 10. 하지 말 것 (안티패턴)

- `mark`(포인트색)를 긴급·캐럿 외의 곳에 쓰기 (링크·아이콘·선택을 유채색으로)
- 팔레트(6토큰 + 상태 3) 밖 색을 임의로 추가 / 그라데이션
- 색을 하드코딩 (검정·흰색 직접 지정 → NOIR에서 깨짐). 항상 토큰 참조
- 둥근 모서리(`radius > 0`), 앱 내부 그림자, 굵은 테두리
- 알약 배지·원형 체크박스 부활 (라벨·글리프로 통일)
- 4px 리듬·22px `gutter`를 벗어난 임의 간격
- 폰트 크기 단계를 §3 밖으로 늘리기
- 한글 제목에 모노, 라벨·숫자에 산세리프 (두 벌 규칙 위반)
- 대문자 라벨에서 자간(letter-spacing) 빼기 (편집 감각 절반이 여기)
- 카드·박스로 섹션 감싸기 (라벨 + 규칙선으로 구분)
- 빈 상태에 느낌표·이모지·"없어요!" 톤
