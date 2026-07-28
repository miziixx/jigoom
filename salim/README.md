# 살림 관리 (salim)

> 혼자 쓰는 종합 살림 관리 모바일 웹앱.
> 집안일 · 재고/장보기 · 가계부 · 물건 보관을 한 앱에.
> **"집을 하나의 생명체처럼 돌본다"** — 집 컨디션 게이지(화분)가 메인 히어로.

데이터는 기기에 영구 저장(localStorage), 모바일 우선, 오프라인 동작, 격려하는 톤.

---

## 작업 규칙

- 한 번에 **"하나의 작은 작업"**만 한다.
- 각 작업이 끝나면 `PROGRESS.md`의 해당 항목을 `[x]`로 바꾸고, `RECORD.md`에 기록을 남긴 뒤 멈춘다.
- 사용자가 **"다음"** 또는 다음 지시를 주면 이어서 한다.

---

## 기술 스택

| 영역 | 선택 | 비고 |
|------|------|------|
| 프레임워크 | **React + Vite + TypeScript** | 기획서 11장 TS 타입을 그대로 활용, 가벼운 정적 빌드 |
| 상태/저장 | **Zustand + persist** | 7개 key를 localStorage에 영구 저장. 백엔드 없음 |
| 라우팅 | **react-router-dom** | 6개 하단 탭 + 뒤로가기 |
| 스타일 | **순수 CSS + CSS 변수** | 모바일 우선, 의존성 최소 |
| 차트 | CSS 막대 | 가계부 월 요약, 초기엔 라이브러리 없이 |
| PWA | `vite-plugin-pwa` | 오프라인/설치, '향후' 단계 |

저장 key: `chores`, `inventory`, `shopping`, `expenses`, `stash`, `logs`, `settings`
(살림백과 `howtos`는 앱 내장 상수 — 사용자 데이터 아님)

### 향후 네이티브(Android/iOS) 전환 대비

나중에 스토어용 네이티브 앱으로 갈 수 있으므로, **지금 웹 코드를 그대로 재사용**하는 경로로 설계:

- **Capacitor로 감싸기** — Vite 빌드 결과물을 그대로 Android/iOS 네이티브 셸로 패키징
  (React Native 재작성 불필요). 설정은 `capacitor.config.json`에 준비됨.
- **저장 로직은 추상화 레이어 뒤에** — localStorage를 직접 호출하지 않고 `src/lib/storage.ts` 하나로 통일.
  네이티브 전환 시 `@capacitor/preferences`·SQLite로 교체만 하면 됨.
- **웹 전용 API 격리** — 위치/날씨는 `src/services/weather.ts`로 분리.

#### 스토어 출시 시 (Mac + Android Studio/Xcode 필요)

```bash
npm i -D @capacitor/cli && npm i @capacitor/core @capacitor/android @capacitor/ios
npm run build              # dist/ 생성
npx cap add android        # (또는 ios)
npx cap sync
npx cap open android       # Android Studio에서 빌드/서명/업로드
```

> 이 저장소 환경엔 모바일 SDK가 없어 실제 네이티브 빌드는 위 단계를 로컬에서 실행해야 함.
> 앱 코드는 이미 호환되게(상대경로 `base:'./'`, HashRouter, 저장 추상화) 작성돼 있음.

---

## 폰에서 쓰기 (배포 — Vercel)

비공개 저장소라 GitHub Pages 대신 **Vercel**로 배포한다(무료, 기존 대시보드와 동일 호스팅).

### 최초 1회 설정 (Vercel 웹에서)
1. https://vercel.com → **Add New… → Project** → `miziixx/myapps` 가져오기(Import).
2. **Root Directory** 를 **`salim`** 으로 지정 (중요 — 모노레포라 하위 폴더 선택).
3. Framework는 자동으로 **Vite** 인식. 그대로 **Deploy**.
4. 배포되면 `https://<프로젝트>.vercel.app` 주소가 생김.

이후 `salim/`에 push할 때마다 Vercel이 자동 재배포한다. (`salim/vercel.json`에 빌드 설정 포함)

### 폰에서
- 폰 브라우저로 위 Vercel 주소 접속 → 메뉴 → **'홈 화면에 추가'**(PWA 설치).
- 데이터는 그 기기의 localStorage에 저장(기기별 독립, 서버 없음).

> Vercel은 도메인 루트로 서빙되므로 기본 빌드(`base: './'`)가 그대로 맞다.
> (Netlify로도 동일하게 가능: New site → 저장소 → Base directory `salim`, Publish `salim/dist`.)

## 화면 구성 (하단 탭 6개)

`오늘` · `집안일` · `살림` · `가계부` · `보관` · `백과(살림백과)`

자세한 기능과 데이터 모델은 기획서, 개발 순서는 `PROGRESS.md`, 작업 이력은 `RECORD.md` 참고.
