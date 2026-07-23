# 구글 캘린더 연동 · 1×1 빠른 추가 위젯 — 설정 가이드

이 문서는 새로 추가된 **구글 캘린더 양방향 동기화**와 **1×1 빠른 추가 위젯(팝업 입력)**
을 실제 기기에서 동작시키기 위한 설정을 정리한다. 코드는 이미 들어가 있고,
아래 (A) OAuth 등록 · (B) 매니페스트/그래들 · (C) 코드 생성만 하면 된다.

> 이 저장소의 `android/` 는 커스텀 Kotlin/리소스만 커밋된 **소스 스냅샷**이라
> `AndroidManifest.xml`·`build.gradle` 은 여기 없다. 아래 스니펫을 각자의
> Flutter 프로젝트 매니페스트/그래들에 반영해야 한다.

---

## A. Google Cloud OAuth 등록 (한 번만)

구글 캘린더 API 는 앱을 GCP 에 OAuth 클라이언트로 등록해야 호출할 수 있다.
Android 는 **패키지명 + 앱 서명 SHA-1** 으로 자동 매칭되므로 **코드에 clientId 를
넣을 필요가 없다.**

1. **프로젝트 생성** — https://console.cloud.google.com → 상단 프로젝트 선택 → *새 프로젝트*.
2. **Calendar API 사용 설정** — *API 및 서비스 → 라이브러리* → "Google Calendar API" → *사용*.
3. **OAuth 동의 화면** — *API 및 서비스 → OAuth 동의 화면*
   - User Type: **External**.
   - 앱 이름 `지금`, 지원 이메일 입력.
   - **스코프 추가**: `.../auth/calendar` (Google Calendar API, 읽기·쓰기).
   - **테스트 사용자**에 본인 구글 계정(daily.zia@gmail.com 등) 추가.
     (게시 전에는 테스트 사용자만 로그인 가능.)
4. **Android OAuth 클라이언트 만들기** — *API 및 서비스 → 사용자 인증 정보 →
   사용자 인증 정보 만들기 → OAuth 클라이언트 ID*
   - 애플리케이션 유형: **Android**.
   - 패키지 이름: **`com.ziia.jigeum`**
   - **SHA-1 인증서 지문**: 아래로 구한 값을 붙여넣는다.

### SHA-1 구하기

디버그(개발용):
```bash
keytool -list -v -alias androiddebugkey \
  -keystore ~/.android/debug.keystore \
  -storepass android -keypass android | grep SHA1
```
또는 프로젝트에서:
```bash
cd jigeum/android && ./gradlew signingReport   # Variant: debug 의 SHA1
```
릴리즈(배포용) 키스토어가 따로 있으면 **그 SHA-1 로 클라이언트를 하나 더** 등록한다
(디버그·릴리즈 각각 등록 권장). Play 앱 서명을 쓰면 Play Console 의 앱 서명 SHA-1 도 등록.

> clientId 문자열은 Android 코드에 필요 없다. GCP 매칭만 맞으면 로그인·토큰 발급이 된다.
> (서버 백엔드로 토큰을 넘길 계획이 생기면 그때 Web 클라이언트의 `serverClientId` 가 필요.)

---

## B. AndroidManifest / Gradle 반영

### B-1. 권한 (매니페스트 `<manifest>` 안)
```xml
<uses-permission android:name="android.permission.INTERNET" />
```
(대개 이미 있음. 없으면 추가.)

### B-2. 1×1 위젯 리시버 + 팝업 액티비티 (`<application>` 안)
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
- 기존 위젯(Focus/Matrix/TimeTrack/Calendar) 리시버들과 같은 위치에 추가한다.
- `Theme.Jigeum.QuickAdd` 는 `res/values/quick_add_styles.xml` 에 이미 정의돼 있다.

### B-3. Gradle
- `google_sign_in` 이 `play-services-auth` 를 자동으로 끌어온다. **추가 설정 불필요.**
- `minSdkVersion` 은 **21 이상**이어야 한다(대부분 충족).
- 별도 ProGuard 규칙 없이 동작하지만, 릴리즈 난독화에서 문제가 나면
  `google_sign_in`·`googleapis` 관련 keep 규칙을 확인한다.

---

## C. 코드 생성 · 의존성

```bash
cd jigeum
flutter pub get
# Drift 스키마가 v6 → v7 로 올라갔으므로 생성 파일 재생성:
dart run build_runner build --delete-conflicting-outputs
```
그런 다음 평소대로 빌드:
```bash
flutter build apk --debug
```

---

## 동작 방식 (요약)

- **연결**: 설정 → `GOOGLE CALENDAR` → *구글 캘린더 연결*. 동의 후 캘린더 목록을 불러온다.
- **종류별 선택**: 목록에서 캘린더별 스위치로 **동기화 대상**을 고른다(주 캘린더는 기본 on).
- **양방향 동기화**:
  - 앱에서 만든/수정/삭제한 일정(`dirty`) → 선택된(쓰기 가능) 캘린더로 **push**.
  - 선택된 캘린더의 변경 → **증분(syncToken) pull** 해서 앱 일정으로 반영(신규는 자동 추가).
  - 충돌은 "로컬 수정 중이면 로컬 우선, 아니면 원격 반영" (last-writer-by-intent).
  - 트리거: 앱 시작 · 포그라운드 복귀 · 일정 편집 후(1.5초 디바운스) · 설정의 *지금 동기화*.
- **일정 편집 시 캘린더(종류) 지정**: 일정 추가/수정 시트에 **구글 캘린더 칩**이 뜬다
  (연결 + 쓰기 가능한 선택 캘린더가 있을 때). 고른 캘린더로 그 일정이 올라간다.
- **1×1 위젯**: 홈에 두고 탭하면 **반투명 팝업**이 떠서 제목 + 캘린더(종류) + 종일을
  입력할 수 있다. 입력은 큐에 쌓였다가 **앱이 열리거나 포그라운드로 올 때** 로컬 일정으로
  들어오고 구글 캘린더로 동기화된다.

### 한계 / 다음 단계 (선택)
- 위젯 팝업 입력은 **앱이 다음에 열릴 때** 원격에 반영된다(즉시 백그라운드 push 아님).
  즉시성을 원하면 `WorkManager` 로 백그라운드 flush 를 붙이면 된다(그래들에
  `androidx.work:work-runtime` 추가 필요) — 이번 범위 밖.
- 반복(recurring) 이벤트는 `singleEvents=true` 로 **개별 인스턴스**로 받아 표시한다.
  앱에서 반복 규칙 편집은 지원하지 않는다.
- 이벤트 색/알림/참석자 등은 동기화하지 않는다(제목·메모·시간·종일만).
