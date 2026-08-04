package com.ziia.jigeum

import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * 홈 위젯 구성 액티비티 — 홈 화면에 '지금 · 위젯 스튜디오' 위젯을 얹을 때 뜬다.
 *
 * Flutter 를 initialRoute '/widget_config' 로 띄워 위젯 설정 화면을 보여주고,
 * 'jigeum/studio_widget' 채널로 다음을 처리한다:
 *  - getAppWidgetId : 구성 중인 위젯 id
 *  - commit(png)    : Flutter 가 캡처한 PNG 저장 + 첫 렌더 + 배치 확정(RESULT_OK)
 *  - cancel         : 배치 취소(액티비티 종료)
 */
class StudioWidgetConfigActivity : FlutterActivity() {

    private var appWidgetId: Int = AppWidgetManager.INVALID_APPWIDGET_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        appWidgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID
        // 사용자가 그냥 나가면 위젯이 배치되지 않도록 기본은 취소.
        setResult(
            RESULT_CANCELED,
            Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        )
    }

    override fun getInitialRoute(): String = "/widget_config"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "jigeum/studio_widget")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getAppWidgetId" -> result.success(appWidgetId)
                    "commit" -> {
                        try {
                            val png = call.argument<ByteArray>("png")
                            if (png == null || appWidgetId ==
                                AppWidgetManager.INVALID_APPWIDGET_ID
                            ) {
                                result.success(false)
                                return@setMethodCallHandler
                            }
                            StudioWidgetStore.save(this, appWidgetId, png)
                            StudioWidgetProvider.render(
                                this, AppWidgetManager.getInstance(this), appWidgetId
                            )
                            setResult(
                                RESULT_OK,
                                Intent().putExtra(
                                    AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId
                                )
                            )
                            result.success(true)
                            finish()
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    "cancel" -> {
                        result.success(null)
                        finish()
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
