# DESIGN SYSTEM

> Claude Code 상시 참조 문서. 새 기능·페이지·컴포넌트를 만들 때 **반드시 이 토큰과 규칙을 따른다.**
> 하드코딩된 색/간격/폰트 값 대신 항상 아래 토큰을 사용한다.

---

## 0. 디자인 원칙 (모든 판단의 기준)

이 앱의 미학은 **"따뜻한 종이 + 차분한 구조"** — 타임라인 기록(감성)과 구조적 상태 관리(질서)를 섞은 톤이다.

1. **절제가 곧 깔끔함.** 색은 최소, 폰트 단계는 5개 이하, 간격은 규칙적으로. 새 요소를 넣을 때 "더할까"보다 "뺄 수 있나"를 먼저 본다.
2. **포인트 컬러는 화면당 1~2개까지.** 무채색이 기본, 강조는 예외.
3. **두 벌 폰트 시스템.** 본문/제목은 산세리프, 메타·숫자·기호·태그는 모노스페이스. 이 대비가 톤의 핵심.
4. **간격은 4px 배수만.** 임의 값(예: 7px, 13px) 금지.
5. **구분선은 얇게(1px), 그림자는 약하게.** 경계를 무겁게 만들지 않는다.
6. **모든 상태를 정의한다.** 컴포넌트를 만들 땐 normal / hover / active / disabled / empty / invalid / loading 을 빠뜨리지 않는다 (§6 체크리스트 참조).

---

## 1. 색 (Color)

### 중립 — 따뜻한 회색(종이 느낌)
| 토큰 | 값 | 용도 |
|---|---|---|
| `bg` | `#FDFCFB` | 기본 배경 (순백보다 살짝 따뜻) |
| `bg-subtle` | `#F5F3F0` | 헤더·플로팅 입력바 등 구분되는 면 |
| `border` | `#E8E4DF` | 얇은 구분선, 카드 테두리 |
| `text` | `#1C1B1A` | 본문 (완전 검정 아님 — 눈 편함) |
| `text-muted` | `#8A8580` | 시간 스탬프·메타·플레이스홀더 |

### 포인트 — 딱 두 개
| 토큰 | 값 | 용도 |
|---|---|---|
| `accent` | `#6B4EFF` | 보라. 액션·링크·화살표·활성 체크박스 |
| `accent-soft` | `#EEEBFF` | 연보라. 선택된 탭 배경 등 accent의 은은한 버전 |
| `alert` | `#FF5B24` | 주황. 오늘 표시·마감 임박 점·긴급 배지 |

### 상태 — 대시보드/데이터 확장 대비
| 토큰 | 값 | 용도 |
|---|---|---|
| `success` | `#2E9E5B` | 유효·완료 |
| `warning` | `#E0A400` | 주의 |
| `error` | `#E5484D` | 오류·무효 입력 |
| `disabled` | `#C4BFB9` | 비활성 |

> 규칙: 위 팔레트 밖의 색을 새로 만들지 않는다. 새 의미가 필요하면 이 파일에 토큰을 추가하고 나서 사용한다.

---

## 2. 간격 (Spacing) — 4px 배수

| 토큰 | 값 |
|---|---|
| `space-1` | 4px |
| `space-2` | 8px |
| `space-3` | 12px |
| `space-4` | 16px |
| `space-5` | 24px |
| `space-6` | 32px |
| `space-8` | 48px |

**적용 규칙**
- 화면 좌우 여백: `space-4` (16px)
- 타임라인/리스트 아이템 사이: `space-5` (24px)
- 블록 내부 텍스트 여백: `space-3` (12px)
- 관련 요소 묶음 내부: `space-2` (8px)

---

## 3. 폰트 (Typography)

**두 벌 시스템**
- 본문/제목: **산세리프** (Pretendard 우선, 없으면 Inter / system-ui)
- 메타·숫자·기호·태그·시간: **모노스페이스** (JetBrains Mono / IBM Plex Mono)

**크기 위계 — 딱 5단계 (늘리지 말 것)**
| 토큰 | 크기 / 굵기 | 폰트 | 용도 |
|---|---|---|---|
| `display` | 28px / Bold | Sans | 화면 타이틀 ("Today") |
| `title` | 17px / Semibold | Sans | 블록 제목·할 일 제목 |
| `body` | 15px / Regular (line-height 1.5) | Sans | 본문 |
| `label` | 13px / Medium | Sans | 날짜 라벨·섹션 라벨 |
| `meta` | 11px / Regular | **Mono** | 시간 스탬프·진행도(1/4)·배지 텍스트 |

---

## 4. 반경 · 그림자 · 선

| 토큰 | 값 |
|---|---|
| `radius-sm` | 6px |
| `radius-md` | 10px |
| `radius-full` | 999px (배지·플로팅 바) |
| `border-width` | 1px (구분선) / 1.5px (체크박스·인터랙티브) |
| `shadow-float` | `0 4px 16px rgba(28,27,26,0.08)` (플로팅 입력바 정도로만, 약하게) |

---

## 5. 핵심 컴포넌트 규격

### 배지 (알약) — 우선순위 표시
- `radius-full`, 좌우 패딩 7px, 상하 2px, 텍스트 `meta`(Mono 9px)
- **긴급 (채움형)**: 배경 `alert`, 글자 흰색 — 확 튀게. 시선을 먼저 끄는 용도
- **중요 (테두리형)**: `border` 1px, 글자 `text-muted`, 배경 없음 — 얌전하게
- 규칙: 한 아이템에 배지는 1개. "긴급"만 채움, 나머지는 전부 테두리형으로 조용히 둔다 (채움 배지가 여러 개 줄서면 시끄러워짐)

### 체크박스
- **17px 사각형**, `radius-sm`(5~6px), `border` 1.5px (색 `#CFCAC4`)
- 체크 시 배경/테두리 `accent`, 체크 표시 흰색
- hover 시 테두리 `accent`
- 완료된 아이템: 제목 `text-muted` + 취소선

### 리스트 / 할 일 아이템  ★구분선 없음
- 구성: 체크박스 → `space-2`(10px) → 제목 → (우측) 우선순위 배지
- 제목: **14px, weight 500** (`title`보다 작고 얇게 — 리스트는 촘촘하게)
- **아이템 사이 구분선(border-bottom) 사용하지 않는다.** 상하 여백 7~9px + 왼쪽 정렬선으로만 구분한다.
- 완료 처리: 체크박스 `accent` 채움 + 제목 취소선/`text-muted`

### 섹션 라벨 (할 일 · 3 등)  ★배경 없음
- `meta`(Mono 11px) `text-muted`, **배경 알약·테두리 없이 텍스트만**
- 뒤 카운트 숫자(· 3)만 `text` 색으로 진하게
- 위 여백 `space-3`~`space-4`, 아래 여백 `space-1`

### 할 일 상세 — 라벨·값 (카탈로그 스타일)  ★신규
미술관 카탈로그 톤. **구분선 없이** 라벨-값을 2컬럼으로 정렬해 여백으로만 나눈다.
- 제목: `display`급(22px Bold), 아래 여백 넉넉히(`space-6`)
- 각 행(row): `grid-template-columns: 88px 1fr`, 행 간격 22px
  - **라벨**: `meta`(Mono 10px) `text-muted`, **우측 정렬** (값 쪽에 붙어 가운데로 모이는 배치 — 이 정렬이 톤의 핵심)
  - **값**: 14px weight 500, 좌측 정렬. 보조 정보는 `text-muted`
- **값 하이라이트 박스**: 특정 값 하나만 강조할 때 `bg-subtle` 배경 + `radius-sm` + Mono. 화면당 1개까지 (카탈로그의 번호 박스에서 차용)
- 상태/우선순위 값은 색으로: 긴급 `alert`, 진행 중 `accent`

### 빠른 담기 칩 (중요 / 긴급 / 오늘)
- 텍스트만. **이모지·아이콘 붙이지 않는다** (톤 안 맞음)
- `border` 1px 테두리 알약, 텍스트 `label`(13px) `text-muted`

### 플로팅 입력 바
- 하단 고정, `radius-full`, 배경 `bg-subtle` (반투명 허용), `shadow-float`
- 구성: `+` 아이콘 / 플레이스홀더(`text-muted`) / 마이크 아이콘

### 하단 탭 (bottom nav)
- 선택 탭만 `accent` 텍스트 + 아이콘 뒤 `accent-soft`(#EEEBFF) 알약 배경
- 비선택 탭은 `text-muted`, 배경 없음 (선택 1개만 강조, 나머지는 조용히)

### 헤더
- 작은 날짜 라벨(`label`) + `alert` 점 → 큰 타이틀(`display`) → 우측 메뉴 아이콘
- 이 위계(작은 라벨 → 큰 제목)를 모든 페이지에서 유지

---

## 6. 새 컴포넌트 만들 때 상태 체크리스트

컴포넌트를 만들 땐 아래 상태를 **명시적으로** 처리한다 (해당되는 것만, 빠뜨리지 말 것):

- [ ] **Interaction**: normal / hover / active(pressed) / focus / selected
- [ ] **가용성**: enabled / disabled
- [ ] **콘텐츠**: 채워짐 / empty(빈 상태) / placeholder
- [ ] **데이터 품질**: valid / invalid (+ error 메시지, input hint)
- [ ] **비동기**: loading / 성공 / 실패
- [ ] **키보드**: Enter / Tab / 방향키 (해당 시)

> 리스트/테이블류라면 행(추가·삭제·이동·정렬·필터)과 열(너비 default/min/max) 액션도 정의한다.

---

## 7. 토큰 정의 (스택별 — 골라서 사용)

### 7-1. CSS 변수
```css
:root {
  /* color */
  --bg: #FDFCFB;
  --bg-subtle: #F5F3F0;
  --border: #E8E4DF;
  --text: #1C1B1A;
  --text-muted: #8A8580;
  --accent: #6B4EFF;
  --accent-soft: #EEEBFF;
  --alert: #FF5B24;
  --success: #2E9E5B;
  --warning: #E0A400;
  --error: #E5484D;
  --disabled: #C4BFB9;

  /* spacing */
  --space-1: 4px;  --space-2: 8px;  --space-3: 12px;
  --space-4: 16px; --space-5: 24px; --space-6: 32px; --space-8: 48px;

  /* radius */
  --radius-sm: 6px;
  --radius-md: 10px;
  --radius-full: 999px;

  /* type */
  --font-sans: 'Pretendard', 'Inter', system-ui, sans-serif;
  --font-mono: 'JetBrains Mono', 'IBM Plex Mono', monospace;

  /* elevation */
  --shadow-float: 0 4px 16px rgba(28,27,26,0.08);
}

.text-display { font: 700 28px/1.2 var(--font-sans); }
.text-title   { font: 600 17px/1.3 var(--font-sans); }
.text-body    { font: 400 15px/1.5 var(--font-sans); }
.text-label   { font: 500 13px/1.4 var(--font-sans); }
.text-meta    { font: 400 11px/1.3 var(--font-mono); }
```

### 7-2. Tailwind (`tailwind.config.js` extend)
```js
module.exports = {
  theme: {
    extend: {
      colors: {
        bg: '#FDFCFB',
        'bg-subtle': '#F5F3F0',
        border: '#E8E4DF',
        text: '#1C1B1A',
        'text-muted': '#8A8580',
        accent: '#6B4EFF',
        alert: '#FF5B24',
        success: '#2E9E5B',
        warning: '#E0A400',
        error: '#E5484D',
        disabled: '#C4BFB9',
      },
      spacing: {
        1: '4px', 2: '8px', 3: '12px',
        4: '16px', 5: '24px', 6: '32px', 8: '48px',
      },
      borderRadius: { sm: '6px', md: '10px', full: '999px' },
      fontFamily: {
        sans: ['Pretendard', 'Inter', 'system-ui', 'sans-serif'],
        mono: ['JetBrains Mono', 'IBM Plex Mono', 'monospace'],
      },
      fontSize: {
        display: ['28px', { lineHeight: '1.2', fontWeight: '700' }],
        title:   ['17px', { lineHeight: '1.3', fontWeight: '600' }],
        body:    ['15px', { lineHeight: '1.5', fontWeight: '400' }],
        label:   ['13px', { lineHeight: '1.4', fontWeight: '500' }],
        meta:    ['11px', { lineHeight: '1.3', fontWeight: '400' }],
      },
      boxShadow: { float: '0 4px 16px rgba(28,27,26,0.08)' },
    },
  },
};
```

### 7-3. Flutter (ThemeData / 상수)
```dart
class AppColors {
  static const bg        = Color(0xFFFDFCFB);
  static const bgSubtle  = Color(0xFFF5F3F0);
  static const border    = Color(0xFFE8E4DF);
  static const text      = Color(0xFF1C1B1A);
  static const textMuted = Color(0xFF8A8580);
  static const accent    = Color(0xFF6B4EFF);
  static const accentSoft = Color(0xFFEEEBFF);
  static const alert     = Color(0xFFFF5B24);
  static const success   = Color(0xFF2E9E5B);
  static const warning   = Color(0xFFE0A400);
  static const error     = Color(0xFFE5484D);
  static const disabled  = Color(0xFFC4BFB9);
}

class AppSpace {
  static const s1 = 4.0;  static const s2 = 8.0;  static const s3 = 12.0;
  static const s4 = 16.0; static const s5 = 24.0; static const s6 = 32.0; static const s8 = 48.0;
}

class AppRadius {
  static const sm = 6.0;
  static const md = 10.0;
  static const full = 999.0;
}

const _sans = 'Pretendard';
const _mono = 'JetBrainsMono';

class AppText {
  static const display = TextStyle(fontFamily: _sans, fontSize: 28, fontWeight: FontWeight.w700, height: 1.2, color: AppColors.text);
  static const title   = TextStyle(fontFamily: _sans, fontSize: 17, fontWeight: FontWeight.w600, height: 1.3, color: AppColors.text);
  static const body    = TextStyle(fontFamily: _sans, fontSize: 15, fontWeight: FontWeight.w400, height: 1.5, color: AppColors.text);
  static const label   = TextStyle(fontFamily: _sans, fontSize: 13, fontWeight: FontWeight.w500, height: 1.4, color: AppColors.text);
  static const meta    = TextStyle(fontFamily: _mono, fontSize: 11, fontWeight: FontWeight.w400, height: 1.3, color: AppColors.textMuted);
}
```

---

## 7.5. 기존 화면 리팩터링 지침 (현재 앱 개선)

> 현재 화면들은 구조는 좋으나 "마감 디테일"이 빠져 밋밋하다. 아래 5가지를 우선 적용해 리팩터링한다.
> 구조·기능 배치·화면 구성은 **바꾸지 않는다.** 스타일 토큰만 입힌다.

### (1) 포인트 컬러 주입 — 현재 전부 흑백이라 미완성처럼 보임
`accent`(보라)를 **아래 지점에만** 넣는다 (화면당 1~2개 유지):
- 체크박스 체크 완료 상태 (배경/테두리 `accent`)
- 선택된 하단 탭 / 필터 알약 (현재 회색 `bg-subtle` → `accent` 계열 강조)
- "지금 이것부터" 포커스 카드의 강조 요소

우선순위 `!` 표시는 `alert`(주황)로 — 검정이면 의미가 안 읽힌다.

### (2) 우선순위 `!` → 알약 배지로 통일 (효과 가장 큼)
느낌표 단독 표기 금지. §5 배지 규격으로 교체한다:
- 긴급: **채움형** 배지("긴급"), 배경 `alert` 또는 `text`
- 중요: **테두리형** 배지("중요"), `border` + `text-muted`
- 이미 잘 된 예: 아웃라인 화면의 "오늘" 채움 배지 → 이 스타일로 전 화면 통일

### (3) 메타 정보는 모노스페이스로 (두 벌 시스템 실현)
현재 전부 산세리프 한 종류 → 단조로움. 아래를 `meta`(Mono)로 전환:
- 섹션 카운트 배지: "할 일 · 3", "나중에 · 0", "완료 · 0"
- 날짜/숫자: "7월 21일", "일정 0건 · 총 0분", "0개"
- 필터·기간 라벨의 숫자 부분
- 제목·할 일 텍스트는 산세리프 유지 (섞지 말 것)

### (4) 빈 상태(empty state) 톤 통일
"없어요" / "비어 있어요" / "0개" 처럼 툭 끊기는 표현 개선.
**기준: 습관 화면 톤** = 굵은 안내문(`title`) + 회색 보조 설명(`label`, `text-muted`) 2줄 구성.
- 예: "아직 없어요" (title) + "아래 입력창에 빠르게 담아보세요" (muted)
- 매트릭스 사분면 "비어 있어요", 전체 화면 "없어요"에 동일 적용

### (5) 구분선 제거 + 간격 규칙 통일 — "허접함"의 실제 원인
**리스트 아이템의 구분선(border-bottom)을 전부 제거한다.** 선 대신 여백과 왼쪽 정렬선으로 구분:
- 리스트 아이템 상하 여백: 7~9px (촘촘하게)
- 카드/사분면 내부 패딩: `space-4` (16px)
- 배지·체크박스와 제목 사이: `space-2` (8~10px)
- 섹션 라벨 배경 알약도 제거 → 텍스트만 (§5 참조)

### 우선순위 (투자 대비 효과 순)
1. (2) 배지 위계 + (1) accent 포인트 — 가장 티 남
2. (5) 구분선 제거 + (3) 모노스페이스 메타
3. (4) 빈 상태 정리
4. 할 일 상세 화면을 §5 "라벨·값 카탈로그 스타일"로 신규 구성

---

## 8. 하지 말 것 (안티패턴)

- 팔레트 밖 색을 임의로 쓰기 (그라데이션 남발, 화면당 포인트 3개 이상)
- 4px 배수가 아닌 간격 값
- 폰트 크기 단계를 6개 이상으로 늘리기
- 메타·숫자에 산세리프, 본문에 모노스페이스 쓰기 (두 벌 규칙 위반)
- 두꺼운 그림자·굵은 테두리로 경계 무겁게 만들기
- **리스트 아이템에 구분선(border-bottom) 넣기** (여백으로만 구분)
- 우선순위를 느낌표(`!`) 단독으로 표기하기 (배지 사용)
- 채움형 배지를 여러 개 나열하기 (긴급 1개만 채움, 나머지 테두리형)
- 상태(disabled/empty/invalid/loading) 정의를 건너뛰기
