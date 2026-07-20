#!/usr/bin/env python3
"""CI 전용: flutter create 로 생성된 android 스캐폴드를 홈위젯/알림용으로 패치.

- AndroidManifest.xml 에 홈위젯 receiver + 알림 권한 추가
- android:label 을 '지금' 으로 변경
- build.gradle(.kts) minSdk 26 보장
- build.gradle(.kts) core library desugaring 활성화 (flutter_local_notifications 요구)

로컬 개발자는 README 의 수동 통합 안내를 따르면 됨. 이 스크립트는 재실행 안전(idempotent).
"""
import re
import sys
from pathlib import Path

APP = Path("android/app")
MANIFEST = APP / "src/main/AndroidManifest.xml"

PERMISSIONS = """    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
"""

RECEIVER = """        <receiver android:name=".FocusWidgetProvider" android:exported="true">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
                <action android:name="es.antonborri.home_widget.action.BACKGROUND" />
            </intent-filter>
            <meta-data
                android:name="android.appwidget.provider"
                android:resource="@xml/focus_widget_info" />
        </receiver>
"""


def patch_manifest() -> None:
    text = MANIFEST.read_text(encoding="utf-8")

    # 권한 (중복 방지)
    if "POST_NOTIFICATIONS" not in text:
        text = re.sub(r"(<manifest[^>]*>\n)", r"\1" + PERMISSIONS, text, count=1)

    # 앱 라벨
    text = re.sub(r'android:label="[^"]*"', 'android:label="지금"', text, count=1)

    # 위젯 receiver (중복 방지)
    if "FocusWidgetProvider" not in text:
        text = text.replace("        </application>", RECEIVER + "        </application>", 1)
        text = text.replace("    </application>", RECEIVER + "    </application>", 1)

    MANIFEST.write_text(text, encoding="utf-8")
    print("patched AndroidManifest.xml")


def patch_min_sdk() -> None:
    for name in ("build.gradle.kts", "build.gradle"):
        f = APP / name
        if not f.exists():
            continue
        t = f.read_text(encoding="utf-8")
        t = re.sub(r"minSdk(Version)?\s*=?\s*[\w.]+", "minSdk = 26", t)
        t = re.sub(r"minSdk(Version)?\s+flutter\.minSdkVersion", "minSdk = 26", t)
        f.write_text(t, encoding="utf-8")
        print(f"patched {name} (minSdk=26)")
        return


# flutter_local_notifications 는 core library desugaring 을 요구한다.
# (checkReleaseAarMetadata: "requires core library desugaring to be enabled")
DESUGAR_VERSION = "2.1.4"


def patch_desugaring() -> None:
    for name in ("build.gradle.kts", "build.gradle"):
        f = APP / name
        if not f.exists():
            continue
        t = f.read_text(encoding="utf-8")
        kts = name.endswith(".kts")

        # 1) compileOptions 안에 desugaring 활성화 플래그 추가 (idempotent)
        enable_line = (
            "        isCoreLibraryDesugaringEnabled = true\n"
            if kts
            else "        coreLibraryDesugaringEnabled true\n"
        )
        if "CoreLibraryDesugaringEnabled" not in t:
            if re.search(r"compileOptions\s*\{", t):
                t = re.sub(
                    r"(compileOptions\s*\{\s*\n)", r"\1" + enable_line, t, count=1
                )
            else:
                # compileOptions 블록이 없으면 android { 바로 아래에 통째로 추가
                block = (
                    "    compileOptions {\n"
                    + enable_line
                    + (
                        "        sourceCompatibility = JavaVersion.VERSION_11\n"
                        "        targetCompatibility = JavaVersion.VERSION_11\n"
                        if kts
                        else "        sourceCompatibility JavaVersion.VERSION_11\n"
                        "        targetCompatibility JavaVersion.VERSION_11\n"
                    )
                    + "    }\n"
                )
                t = re.sub(r"(android\s*\{\s*\n)", r"\1" + block, t, count=1)

        # 2) coreLibraryDesugaring 의존성 추가 (idempotent).
        #    Gradle 은 dependencies 블록 다중 선언을 허용하므로 파일 끝에 append.
        if "coreLibraryDesugaring" not in t:
            dep = (
                f'coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:{DESUGAR_VERSION}")'
                if kts
                else f"coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:{DESUGAR_VERSION}'"
            )
            if not t.endswith("\n"):
                t += "\n"
            t += "\ndependencies {\n    " + dep + "\n}\n"

        f.write_text(t, encoding="utf-8")
        print(f"patched {name} (core library desugaring, desugar_jdk_libs={DESUGAR_VERSION})")
        return


if __name__ == "__main__":
    if not MANIFEST.exists():
        print("AndroidManifest not found — run flutter create first", file=sys.stderr)
        sys.exit(1)
    patch_manifest()
    patch_min_sdk()
    patch_desugaring()
