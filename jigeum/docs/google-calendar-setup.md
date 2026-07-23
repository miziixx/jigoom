# 구글 캘린더 연동(폰 캘린더 방식) · 1×1 빠른 추가 위젯 — 설정 가이드

폰에 이미 구글 계정으로 **동기화된 캘린더를 앱이 직접 읽고 쓰는** 방식(안드로이드
`CalendarContract`)이다. 여기에 쓴 일정은 OS 동기화 어댑터가 구글로 다시 올려준다(양방향).

> ✅ **OAuth · Google Cloud 콘솔 · SHA-1 · clientId — 전부 필요 없다.**
> 필요한 건 `READ_CALENDAR` / `WRITE_CALENDAR` **런타임 권한(팝업 한 번)** 뿐.

이 저장소의 `android/` 는 커스텀 Kotlin/리소스만 커밋된 **소스 스냅샷**이라
`AndroidManifest.xml`·`build.gradle` 은 여기 없다. 아래 스니펫을 각자의 Flutter
프로젝트 매니페스트에 반영하고 빌드하면 된다.

---

## A. AndroidManifest 반영

### A-1. 권한 (`<manifest>` 안, `<application>` 위)
```xml
<uses-permission android:name="android.permission.READ_CALENDAR" />
<uses-permission android:name="android.permission.WRITE_CALENDAR" />
```

### A-2. 1×1 위젯 리시버 + 팝업 액티비티 (`<application>` 안)
기존 위젯(Focus/Matrix/TimeTrack/Calendar) 리시버들과 같은 위치에 추가:
```xml
<!-- 1×1 빠른 추가 위젯 -->
<receiver
    android:name=".QuickAddWidgetProvider"
    android:exported="false">
    <intent-filter>
        <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
    </intent-filter>
    <meta-data
        android:name="android.appwidget.provider"
        android:resource="@xml/quick_add_widget_info" />
</receiver>

<!-- 위젯 탭 시 뜨는 반투명 입력 팝업 -->
<activity
    android:name=".QuickAddActivity"
    android:exported="false"
    android:excludeFromRecents="true"
    android:theme="@style/Theme.Jigeum.QuickAdd" />
```
`Theme.Jigeum.QuickAdd` 는 `res/values/quick_add_styles.xml` 에 이미 정의돼 있다.

> Gradle 은 손댈 것 없다. `androidx.core`(ContextCompat/ActivityCompat)는 Flutter
> 프로젝트에 이미 들어 있다. `minSdkVersion` 은 대부분 그대로 OK(권장 21+).

---

## B. 코드 생성 · 빌드

```bash
cd jigeum
flutter pub get
# Drift 스키마가 v6 → v7 로 올라갔으므로 생성 파일 재생성:
dart run build_runner build --delete-conflicting-outputs
flutter build apk --debug   # 평소 빌드대로
```

---

## C. 앱에서 켜기 (기기에서)

1. 설정 → **GOOGLE CALENDAR** → **캘린더 연동 켜기** → 권한 팝업에서 **허용**.
2. 폰에 있는 캘린더 목록이 뜬다. **동기화할 캘린더(종류)** 를 스위치로 고른다
   (쓰기 가능한 주 캘린더는 기본 on).
3. 끝. 이후 자동으로 양방향 동기화된다.

---

## 동작 방식 (요약)

- **양방향 동기화**
  - 앱에서 만든/수정/삭제 일정(`dirty`) → 선택한(쓰기 가능) 폰 캘린더로 **push**
    → OS 가 구글로 업로드.
  - 선택한 캘린더의 변경 → 창[과거 60일~미래 365일]을 **pull** 해서 앱 일정으로 반영
    (신규는 자동 추가, 원격 삭제는 로컬에서도 제거).
  - 충돌은 "로컬 수정 중이면 로컬 우선, 아니면 원격 반영".
  - 트리거: 앱 시작 · 포그라운드 복귀 · 일정 편집 후(1.5초 디바운스) · 설정의 *지금 동기화*.
- **일정 편집 시 캘린더(종류) 지정**: 추가/수정 시트에 **캘린더 칩**이 뜬다(연동 켜짐 +
  쓰기 가능한 선택 캘린더가 있을 때). 고른 캘린더로 그 일정이 올라간다.
- **1×1 위젯**: 홈에 두고 탭하면 **반투명 팝업**이 떠서 제목 + 캘린더(종류) + 종일을
  입력한다. 입력은 큐에 쌓였다가 **앱이 열리거나 포그라운드로 올 때** 로컬 일정으로
  들어오고 폰 캘린더로 동기화된다.

### 전제 / 한계
- 폰 **설정 → 계정 → 구글 → 캘린더 동기화**가 켜져 있어야 구글까지 올라간다(기본 켜짐).
- 반복(recurring) 이벤트는 마스터 1건으로만 표시한다(개별 회차 확장·편집 미지원).
- 제목·메모·시간·종일만 동기화한다(색·알림·참석자 제외).
- 위젯 팝업 입력은 **앱이 다음에 열릴 때** 반영된다(즉시 백그라운드 동기화 아님).
  즉시성이 필요하면 `WorkManager` 로 백그라운드 flush 를 붙이면 된다 — 이번 범위 밖.
