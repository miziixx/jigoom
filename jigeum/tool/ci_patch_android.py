#!/usr/bin/env python3
"""CI 전용: flutter create 로 생성된 android 스캐폴드를 홈위젯/알림용으로 패치.

- AndroidManifest.xml 에 홈위젯 receiver + 알림 권한 추가
- android:label 을 '지금' 으로 변경
- build.gradle(.kts) minSdk 26 보장

로컬 개발자는 README 의 수동 통합 안내를 따르면 됨. 이 스크립트는 재실행 안전(idempotent).
"""
import re
import sys
from pathlib import Path

APP = Path("android/app")
MANIFEST = APP / "src/main/AndroidManifest.xml"

PERMISSIONS = """    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
    <uses-permission android:name="android.permission.READ_CALENDAR" />
    <uses-permission android:name="android.permission.WRITE_CALENDAR" />
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
"""

# 음성 인식(SttBridge/SpeechRecognizer)용. Android 11+ 는 이 <queries> 가 없으면
# SpeechRecognizer.isRecognitionAvailable 가 false 를 돌려줘 마이크가 안 열린다.
QUERIES = """    <queries>
        <intent>
            <action android:name="android.speech.RecognitionService" />
        </intent>
    </queries>
"""

RECEIVER = """        <receiver android:name=".FocusWidgetProvider" android:exported="true" android:label="지금 · 포커스">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
            </intent-filter>
            <meta-data
                android:name="android.appwidget.provider"
                android:resource="@xml/focus_widget_info" />
        </receiver>
        <receiver android:name=".MatrixWidgetProvider" android:exported="true" android:label="지금 · 매트릭스">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
            </intent-filter>
            <meta-data
                android:name="android.appwidget.provider"
                android:resource="@xml/matrix_widget_info" />
        </receiver>
        <receiver android:name=".TimeTrackWidgetProvider" android:exported="true" android:label="지금 · 타임트래커">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
            </intent-filter>
            <meta-data
                android:name="android.appwidget.provider"
                android:resource="@xml/time_track_widget_info" />
        </receiver>
        <receiver android:name=".CalendarWidgetProvider" android:exported="true" android:label="지금 · 캘린더">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
            </intent-filter>
            <meta-data
                android:name="android.appwidget.provider"
                android:resource="@xml/calendar_widget_info" />
        </receiver>
        <receiver android:name=".QuickAddWidgetProvider" android:exported="true" android:label="지금 · 빠른 추가">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
            </intent-filter>
            <meta-data
                android:name="android.appwidget.provider"
                android:resource="@xml/quick_add_widget_info" />
        </receiver>
        <receiver android:name=".QuickMenuWidgetProvider" android:exported="true" android:label="지금 · 빠른 입력 메뉴">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
            </intent-filter>
            <meta-data
                android:name="android.appwidget.provider"
                android:resource="@xml/quick_menu_widget_info" />
        </receiver>
        <receiver android:name=".GoalWidgetProvider" android:exported="true" android:label="지금 · 오늘의 목표">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
            </intent-filter>
            <meta-data
                android:name="android.appwidget.provider"
                android:resource="@xml/goal_widget_info" />
        </receiver>
        <receiver android:name=".StudioWidgetProvider" android:exported="true" android:label="지금 · 위젯 스튜디오">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
            </intent-filter>
            <meta-data
                android:name="android.appwidget.provider"
                android:resource="@xml/studio_widget_info" />
        </receiver>
        <activity
            android:name=".StudioWidgetConfigActivity"
            android:exported="true"
            android:theme="@style/LaunchTheme">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_CONFIGURE" />
            </intent-filter>
        </activity>
        <activity
            android:name=".QuickAddActivity"
            android:exported="false"
            android:excludeFromRecents="true"
            android:theme="@style/Theme.Jigeum.QuickAdd" />
"""


def patch_manifest() -> None:
    text = MANIFEST.read_text(encoding="utf-8")

    # 권한 (중복 방지)
    if "POST_NOTIFICATIONS" not in text:
        text = re.sub(r"(<manifest[^>]*>\n)", r"\1" + PERMISSIONS, text, count=1)

    # 음성 인식 권한 (기존 매니페스트가 이미 패치된 경우 대비 오디오 권한만 별도 삽입)
    if "RECORD_AUDIO" not in text:
        audio = '    <uses-permission android:name="android.permission.RECORD_AUDIO" />\n'
        text = re.sub(r"(<manifest[^>]*>\n)", r"\1" + audio, text, count=1)

    # SpeechRecognizer <queries> (중복 방지)
    if "RecognitionService" not in text:
        text = re.sub(r"(<manifest[^>]*>\n)", r"\1" + QUERIES, text, count=1)

    # 앱 라벨
    text = re.sub(r'android:label="[^"]*"', 'android:label="지금"', text, count=1)

    # 홈 위젯 receiver (순수 네이티브 구현, 중복 방지)
    if "FocusWidgetProvider" not in text:
        text = text.replace(
            "        </application>", RECEIVER + "        </application>", 1)
        text = text.replace(
            "    </application>", RECEIVER + "    </application>", 1)

    MANIFEST.write_text(text, encoding="utf-8")
    print("patched AndroidManifest.xml")


def _app_gradle() -> Path | None:
    for name in ("build.gradle.kts", "build.gradle"):
        f = APP / name
        if f.exists():
            return f
    return None


def patch_min_sdk() -> None:
    f = _app_gradle()
    if not f:
        return
    t = f.read_text(encoding="utf-8")
    t = re.sub(r"minSdk(Version)?\s*=?\s*[\w.]+", "minSdk = 26", t)
    f.write_text(t, encoding="utf-8")
    print(f"patched {f.name} (minSdk=26)")


def patch_desugaring() -> None:
    """flutter_local_notifications 는 core library desugaring 필요.
    isCoreLibraryDesugaringEnabled + desugar_jdk_libs 의존성 주입 (idempotent)."""
    f = _app_gradle()
    if not f:
        return
    t = f.read_text(encoding="utf-8")
    kts = f.name.endswith(".kts")

    # 1) compileOptions 안에 desugaring 활성화
    if "isCoreLibraryDesugaringEnabled" not in t and "coreLibraryDesugaringEnabled" not in t:
        flag = ("        isCoreLibraryDesugaringEnabled = true\n"
                if kts else
                "        coreLibraryDesugaringEnabled true\n")
        t = re.sub(r"(compileOptions\s*\{\s*\n)", r"\1" + flag, t, count=1)

    # 2) desugar_jdk_libs 의존성 (별도 dependencies 블록 append — Gradle 이 병합)
    if "desugar_jdk_libs" not in t:
        if kts:
            t += ('\ndependencies {\n'
                  '    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n'
                  '}\n')
        else:
            t += ('\ndependencies {\n'
                  "    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n"
                  '}\n')

    f.write_text(t, encoding="utf-8")
    print(f"patched {f.name} (core library desugaring)")


if __name__ == "__main__":
    if not MANIFEST.exists():
        print("AndroidManifest not found — run flutter create first", file=sys.stderr)
        sys.exit(1)
    patch_manifest()
    patch_min_sdk()
    patch_desugaring()
