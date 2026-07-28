# 받은함 빠른메모 위젯 (DashInboxWidget)

안드로이드 홈 화면 위젯 → 탭하면 입력창 → 쓴 내용이 **대시보드 받은함**으로 들어감.

독립 앱이라 대시보드(웹앱)와는 별개로 설치돼. 데이터는 Supabase `inbox_queue` 테이블을 통해 전달되고,
대시보드가 켜질 때(또는 실시간으로) 받은함으로 합쳐진 뒤 큐는 비워져.

## 0. 먼저 Supabase 준비 (한 번만)
`dashboard/supabase-widget.sql` 을 Supabase SQL Editor에서 실행해서 `inbox_queue` 테이블을 만들어줘.

## 1. 빌드 (맥에서)
이 폴더(`inbox-widget/`)를 **Android Studio**로 열면 Gradle wrapper가 자동 생성되고 바로 빌드돼.

또는 터미널에서 (Gradle 설치돼 있으면):
```bash
cd inbox-widget
gradle wrapper          # gradlew 없을 때 한 번만
./gradlew assembleDebug
```
APK 위치: `app/build/outputs/apk/debug/app-debug.apk`

설치 (폰 연결 상태):
```bash
~/Library/Android/sdk/platform-tools/adb -s R5KL10033GY install -r app/build/outputs/apk/debug/app-debug.apk
```

## 2. 사용법
1. 앱(받은함 위젯)을 한 번 열어서 **대시보드 계정으로 로그인** (이메일/비번).
2. 홈 화면 길게 눌러 → 위젯 → **받은함 위젯** 추가.
3. 위젯 탭 → 입력창에 메모 쓰고 **받은함에 담기**.
4. 대시보드를 열면 받은함에 들어와 있음.

## 메모
- `Config.kt` 의 SB_URL / SB_KEY 는 대시보드와 동일 (anon/publishable 키, 공개용).
- 로그인 토큰은 앱 SharedPreferences에 저장. 만료되면 자동 갱신, 그래도 실패하면 재로그인 안내.
- 보안: `inbox_queue` 는 RLS로 본인 행만 INSERT/SELECT 가능.
