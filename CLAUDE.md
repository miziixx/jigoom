# nemo 앱 개발 가이드

## 프로젝트 개요
Flutter Android 메모 앱. 플레이버 시스템으로 4가지 버전 관리.

## 플레이버 (버전)

| 플레이버 | 앱 이름 | 앱 ID | 스토어 기능 |
|----------|---------|-------|------------|
| `personal` | nemo | `com.example.memo_app` | ❌ |
| `store` | nemo | `com.example.memo_app` | ✅ |
| `nemo2` | nemo2 | `com.example.memo_app_v2` | ❌ |
| `nemo2store` | nemo2 | `com.example.memo_app_v2` | ✅ |

- `nemo`와 `nemo2`는 앱 ID가 달라서 폰에 동시 설치 가능
- `personal`과 `store`는 앱 ID가 같아서 동시 설치 불가

## 빌드 & 설치 명령

### 디버그 빌드 + 설치 (개발 중)
```bash
# nemo (personal)
flutter build apk --flavor personal --debug --android-skip-build-dependency-validation
~/Library/Android/sdk/platform-tools/adb -s R5KL10033GY install -r build/app/outputs/flutter-apk/app-personal-debug.apk

# nemo2 (nemo2)
flutter build apk --flavor nemo2 --debug --android-skip-build-dependency-validation
~/Library/Android/sdk/platform-tools/adb -s R5KL10033GY install -r build/app/outputs/flutter-apk/app-nemo2-debug.apk

# nemo2 스토어 (nemo2store)
flutter build apk --flavor nemo2store --debug --android-skip-build-dependency-validation
~/Library/Android/sdk/platform-tools/adb -s R5KL10033GY install -r build/app/outputs/flutter-apk/app-nemo2store-debug.apk
```

### 릴리즈 빌드 (배포용)
```bash
flutter build apk --flavor personal --release --android-skip-build-dependency-validation
flutter build apk --flavor store --release --android-skip-build-dependency-validation
flutter build apk --flavor nemo2 --release --android-skip-build-dependency-validation
flutter build apk --flavor nemo2store --release --android-skip-build-dependency-validation
```
릴리즈 APK 위치: `build/app/outputs/flutter-apk/app-{flavor}-release.apk`

## 기기 연결
- 항상 폰이 연결된 상태로 작업
- 기기 ID: `R5KL10033GY`
- Gradle 직접 실행은 Dart 재컴파일 안 됨 → 반드시 `flutter build` 사용

## 주요 파일 구조
```
lib/
  models/
    memo.dart          # Memo 모델 (reminderAt, scheduledAt 등)
    memo_actions.dart  # MemoActions 콜백 묶음
    folder.dart
    quick_tab.dart
  screens/
    home_screen.dart   # 메인 화면
    schedule_screen.dart  # 일정 화면 (scheduledAt 기준)
    stats_screen.dart
  widgets/
    input_bar.dart     # 메모 입력바 (! → scheduledAt picker)
    memo_tile.dart
    calendar_view.dart
    sidebar.dart
    schedule_sheet.dart   # 알림 날짜/시간 설정 시트
    scroll_picker_dialog.dart  # 공용 스크롤 picker
    bottom_tab_bar.dart
  flavor.dart          # isStoreFlavor 판별
  app_theme.dart       # 테마 (kBg, kText, kMint, kTeal, kDim, kBorder, kSurface, mono())
```

## 핵심 개념
- **reminderAt**: 알림 전용 (🔔), NotificationService 연동
- **scheduledAt**: 일정 표시 전용 (! 단축키), schedule 화면에 표시
- **isStoreFlavor**: store / nemo2store 플레이버에서 true
- **themeNotifier**: ValueNotifier, 테마 변경 시 rebuild
- Gradle `--no-verify` 절대 사용 금지

## 변경 이력

### 위젯 메모 입력창 UI 개선 (nemo2test)
**파일:** `android/app/src/main/res/layout/activity_memo_input.xml`, `MemoInputActivity.kt`

nemo2test flavor의 홈 위젯 메모 입력창을 메인 앱 logroom UI(`_buildLogroomInput`)와 동일한 구조로 변경.

**변경 전:** 폴더 버튼(상단) → 텍스트 + 버튼 나란히(한 줄)
**변경 후:** 텍스트 입력(상단, 왼쪽 accent dot) → 리마인더 배지 → 툴바(하단, top border)

- `shape_accent_dot.xml`: 텍스트 왼쪽 7dp 원형 dot drawable (tealColor 55% alpha로 동적 적용)
- `toolbar_top_border.xml`: 툴바 상단 구분선 drawable
- 폴더 버튼을 툴바 안으로 이동, ADD 버튼 텍스트 `[ ADD ]` → `추가`
- `applyColors()`에서 accent dot 배경을 tealColor 기반으로 동적 설정
