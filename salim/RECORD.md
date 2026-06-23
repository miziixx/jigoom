# 살림 관리 — 작업 기록 (RECORD)

> 저장소 관례(`record.md`)를 따라, 이 앱에서 하는 **모든 작업을 시간순으로 기록**한다.
> 각 작업(0-1, 0-2, …) 완료 시마다 '무엇을 · 왜 · 어떤 파일'을 남긴다.

---

## 2026-06-23 — 프로젝트 셋업 결정 (코드 작성 전)

### 저장소 방향
- `myapps`를 여러 웹앱을 담는 **모노레포**로 사용하기로 결정.
- 새 앱 **"살림 관리"**를 `salim/` 폴더에 생성.
- (별도 합의) 안 쓰는 nemo(Flutter) 앱은 추후 지시 시 제거 예정.

### 앱 정체성 / 기획
- 기획서: `집안일살림앱_기획서.md` (v2 · 개성 통합본).
- 콘셉트: "집을 하나의 생명체처럼 돌본다." 집안일·살림·돈이 하나의 흐름으로 이어지고,
  **집 컨디션 게이지(화분)**가 메인 히어로.
- 화면: 하단 탭 6개 — 오늘 / 집안일 / 살림 / 가계부 / 보관 / 백과(살림백과).
- 데이터: 기기에 영구 저장(localStorage). 모바일 우선·오프라인·격려하는 톤(죄책감 금지).

### 기술 스택 결정
- **React + Vite + TypeScript** (기획서 11장 TS 타입을 그대로 활용).
- **상태/저장: Zustand + persist** → 7개 key(`chores`, `inventory`, `shopping`,
  `expenses`, `stash`, `logs`, `settings`)를 localStorage에 자동 저장. 백엔드 없음.
- **라우팅: react-router-dom** (6탭 + 뒤로가기).
- **스타일: 순수 CSS + CSS 변수** (모바일 우선, 의존성 최소).
- **PWA: vite-plugin-pwa** — '향후' 단계.

### 향후 네이티브(Android/iOS) 대비
- 나중에 스토어 앱으로 갈 수 있어 **웹 코드 재사용 경로**로 설계:
  - **Capacitor**로 Vite 빌드를 네이티브 셸로 패키징(React Native 재작성 불필요).
  - **저장 로직을 추상화 레이어 뒤에** 두어, 추후 `@capacitor/preferences`·SQLite로 교체만.
  - 위치/날씨 등 웹 전용 API는 서비스 모듈로 격리.

### 작업 규칙 확정
- 한 번에 하나의 작은 작업만.
- 작업 끝나면 `PROGRESS.md` 항목을 `[x]`로 바꾸고 RECORD.md에 기록한 뒤 정지.
- 사용자가 "다음" 지시 시 이어서 진행.

### 이번에 생성한 파일 (코드 0줄)
- `salim/README.md` — 앱 소개 + 기술 스택 + 작업 규칙.
- `salim/PROGRESS.md` — 작업 규칙 + 15장 개발 순서 체크리스트(전부 `[ ]` 예정).
- `salim/RECORD.md` — 이 기록 파일.

---

## 2026-06-23 — 0-1 Vite + React + TS 프로젝트 생성 ✅

### 무엇을
부팅되는 빈 Vite + React + TypeScript 스켈레톤을 `salim/`에 생성. 모바일 뷰포트 meta와 기본 폴더 구조까지.

### 어떤 파일
- `package.json` — react 18 · react-dom · react-router-dom · zustand / devDeps: vite 5 · @vitejs/plugin-react · typescript 5 · @types/react(-dom). scripts: dev/build/preview.
- `vite.config.ts` — `base: './'`(정적·Capacitor 대비 상대경로), `server.host: true`(휴대폰 접속 테스트), react 플러그인.
- `tsconfig.json` / `tsconfig.node.json` — Vite React-TS 표준. (node 설정은 composite 참조라 `noEmit` 사용 불가 → 제거.)
- `index.html` — `lang="ko"`, 모바일 뷰포트 meta(`viewport-fit=cover`, `maximum-scale=1`), theme-color, 제목 "살림 관리".
- `src/main.tsx` · `src/App.tsx`(플레이스홀더) · `src/index.css`(최소 리셋 + 모바일 max-width 480px 컨테이너) · `src/vite-env.d.ts`.
- `.gitignore` — node_modules/dist/logs 등.
- 빈 폴더 + `.gitkeep`: `src/{components,pages,store,data,lib,services,types}` — 이후 작업이 채울 자리.

### 왜
스토어(0-3)·테마(0-2)·탭 네비(0-4)·모델(0-5)은 각각 별도 작업으로 분리하고, 0-1은 "부팅되는 최소 골격 + 구조"만.

### 검증
- `npm install` 성공.
- `npm run build`(tsc -b && vite build) 통과 — 타입 에러 없음, dist 생성(JS ~143kB / gzip 46kB).

> 다음 작업: `0-2 전역 스타일/테마(CSS 변수) + 모바일 레이아웃 베이스` (사용자 "다음" 지시 대기).

---

## 2026-06-23 — 0-2 ~ 4-5 일괄 구현 ✅ (사용자 "4단계까지 쭉 진행" 지시)

> 사용자가 한 번에 4단계까지 진행하라고 해서, 0-2부터 4-5까지 구현하고 빌드 검증.

### 기반 레이어 (0-2~0-6, 3-1)
- `src/types/index.ts` — 11장 모든 타입(Chore, InventoryItem, Expense, StashItem, LogEntry, HowToEntry 등).
- `src/data/cycles.ts` — CYCLE 상수(5장) + EFFORT_LABEL.
- `src/data/choreTemplates.ts` — 12장 집안일 마스터 전체(카테고리·주기·시간·난이도·날씨/계절 태그). 일부에 tip/howtoId로 살림백과 연결.
- `src/data/howtos.ts` — 16장 살림백과 시드 22개(냄새/곰팡이·물때/막힘·고장/얼룩/벌레/빨래기초/응급·안전/자취 첫 세팅) + 검색·조회 헬퍼.
- `src/data/seasonTips.ts` — 8장 계절(월 기반 오프라인) 제안 규칙.
- `src/lib/storage.ts` — **저장 추상화**(localStorage, 향후 Capacitor 교체 지점). `src/lib/{id,date,chores,condition,predict}.ts` 유틸.
- `src/store/useStore.ts` — Zustand + persist(추상화 storage 사용). chores/inventory/shopping/expenses/stash/logs/settings + 액션 전부.
- `src/index.css` — 디자인 토큰(화분/그린 테마) + 전 컴포넌트 스타일. 모바일 우선(max-width 480px).
- 라우팅: `App.tsx` HashRouter(정적·Capacitor file:// 대비) + `Layout`(상단바·검색 아이콘 3-6) + `BottomTabBar`(6탭).

### 1단계 (집안일 + 컨디션 + 보관)
- `pages/ChoresPage.tsx` — 마스터 아코디언 다중 체크 담기(1-1) / 내 집안일 완료·수정·삭제·직접추가(1-2).
- `lib/chores.ts` isDue·daysOverdue(1-3), `lib/condition.ts` choreHealth·houseScore·레벨(1-5).
- `components/PlantGauge.tsx` 화분 SVG(레벨별 잎/꽃·시듦)(1-6) + 오늘 탭 게이지 바 width 트랜지션(차오름).
- `pages/StashPage.tsx` 보관: 추가/검색/삭제 + '오늘 꺼냈어요'(lastTouched)(1-7).

### 2단계 (필터 + 계절 + 일지)
- `pages/TodayPage.tsx` — 시간·기운 필터 칩·필터링(2-1), 계절 배너 + '오늘 할 일로' 끌어올림(2-2), 오늘 일지 타임라인(2-3), 지난 기록 일자별(2-4).

### 3단계 (살림백과)
- `pages/EncyclopediaPage.tsx` — 큰 검색창 keywords 매칭(3-2), 카테고리 카드 둘러보기(3-3), 항목 상세(왜→해결→예방→⚠️, emergency 빨강 상단 강조)(3-4), 관련 집안일 '추가'.
- `components/TipCard.tsx` — 집안일 💡팁 + '더 자세히' howtoId 링크(3-5). 상단 검색 아이콘(3-6).

### 4단계 (재고 + 장보기 + 예측)
- `pages/SupplyPage.tsx` — 재고 추가/수량±/알림기준/부족 뱃지(4-1), 장보기 추가·체크·삭제 + 부족 재고 자동 노출(4-2), '구매 완료' → 재고 복구 + 구매일 저장(4-3).
- `lib/predict.ts` — 소비속도 예측(평균 간격 → 소진 예상일) + isRunningLow(4-4). 오늘 탭 '곧 떨어져요' 요약(4-5).

### 가계부(5단계)는 자리만
- `pages/LedgerPage.tsx` 플레이스홀더. 구매 완료 시 일지에 'purchase/restock'로만 기록(지출 연동은 5-3).

### 검증
- `npm run build`(tsc 엄격 + vite) 통과, 경고 0. 69 모듈, JS gzip ~72kB / CSS gzip ~2.4kB.
- `vite preview` 서빙 확인(상대경로 `./assets/...`, base './' 적용).

> 다음 작업: `5단계 — 가계부 + 장보기 연동 + 잠자는 물건` (사용자 지시 대기).
