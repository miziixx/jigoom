# 목표달성 앱 (goal_app)

클린 아웃라이너 기반 목표달성 앱. Android APK + Flutter Web(PWA). 기획서 v1 MVP.

## 아키텍처

```
lib/
├─ main.dart                 # 진입점 + 시작 시 이월/승격/알림/위젯 동기화
├─ app.dart                  # 하단 탭 셸 (오늘/매트릭스/아웃라인)
├─ core/                     # theme, constants
├─ data/
│   ├─ db.dart               # Drift 스키마 (Nodes, Settings)
│   └─ repos/node_repository.dart   # 핵심 비즈니스 규칙
├─ features/
│   ├─ today/                # 오늘 뷰 + 2분 행동 시트
│   ├─ matrix/               # 매트릭스 뷰 + 사분면 리스트
│   ├─ outline/              # 아웃라이너 + 공용 NodeTile
│   ├─ capture/              # 퀵캡처 입력바
│   └─ widgetkit/            # 홈 위젯 브리지 + 상주/브리핑 알림
└─ providers.dart            # Riverpod 프로바이더
```

feature-first. 각 feature 는 view + controller 로만. usecase 레이어 없음.

## 핵심 비즈니스 규칙 (node_repository.dart)

1. **삭제 대신 상태 전이** — 완료는 `status='done' + doneAt`. 실제 삭제 없음.
2. **자동 이월** — 앱 시작 시 `date < today AND status='open'` → today, `carriedCount++`. 하루 1회, 조용히.
3. **Q4 자동 서랍** — `important=false, urgent=false` task → `status='drawer'`.
4. **포커스 선정** — Q1 → Q2 → Q3 순, `sortOrder` 최상단.
5. **Q2 아침 승격** — 하루 1회 Q2 1개에 오늘 날짜 부여 (`last_promote_date` 기록).
6. **금지** — 스트릭/달성률%/빨강 미완료/실패 문구/미완료 뱃지 없음.

## 최초 설정 (로컬 Flutter 환경에서 1회)

이 저장소에는 Dart 소스 + 홈위젯 리소스 + 웹 설정만 커밋되어 있습니다.
플랫폼 스캐폴드(gradle/Manifest 등)와 Drift 코드생성은 로컬에서 생성합니다.

```bash
cd goal_app

# 1) 플랫폼 스캐폴드 생성 (기존 lib/, web/, android 리소스는 유지됨)
flutter create --org com.ziia --platforms android,web .

# 2) 의존성
flutter pub get

# 3) Drift 코드 생성 (db.g.dart)
dart run build_runner build --delete-conflicting-outputs

# 4) 분석 + 테스트
flutter analyze
flutter test
```

### Android 수동 통합 (flutter create 후)

`android/app/build.gradle`:
- `minSdkVersion 26`, `targetSdk` 최신

`android/app/src/main/AndroidManifest.xml` `<application>` 안에 홈위젯 등록:

```xml
<receiver android:name=".FocusWidgetProvider" android:exported="true">
    <intent-filter>
        <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
        <action android:name="es.antonborri.home_widget.action.BACKGROUND" />
    </intent-filter>
    <meta-data
        android:name="android.appwidget.provider"
        android:resource="@xml/focus_widget_info" />
</receiver>
```

`<manifest>` 레벨 권한:

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
```

> `FocusWidgetProvider.kt`, `res/layout/focus_widget.xml`, `res/drawable/*`,
> `res/xml/focus_widget_info.xml` 는 이미 이 저장소에 포함되어 있습니다.

### 폰트

`assets/fonts/Pretendard-Regular.otf`, `Pretendard-SemiBold.otf` 를 번들해야 합니다
(google_fonts 아님). 없으면 pubspec 의 fonts 항목을 임시로 주석 처리.

## 빌드

```bash
# Android release (arm64 만 배포해도 충분)
flutter build apk --release --split-per-abi

# Web (WASM sqlite3, drift_flutter 자동 처리)
flutter build web --wasm
```

## 웹 주의

- `home_widget` / `flutter_local_notifications` 는 웹 미지원 → `kIsWeb` 분기로 no-op.
- PWA manifest: standalone, theme_color `#FFFFFF`.

## 테스트

핵심 3종만 (`test/node_repository_test.dart`): 자동 이월, 포커스 선정, Q2 승격
(+ Q4 서랍). 위젯/통합 테스트는 MVP 생략.

## 릴리즈

keystore 생성 후 `android/key.properties` 는 `.gitignore` 에 포함되어 있습니다.
`*.g.dart` 도 gitignore — 각 환경에서 build_runner 로 재생성.
