package com.ziia.jigeum

import android.content.Context
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * 'jigeum/widget' MethodChannel:
 *  - updateWidgets: 포커스/매트릭스 데이터 저장 + 위젯 갱신
 *  - setWidgetOpacity / getWidgetOpacity: 위젯 배경 투명도(0~100)
 *  - consumeLaunchAction: 위젯 탭 진입 액션 1회성 반환 (quick_capture)
 */
class MainActivity : FlutterActivity() {

    companion object {
        const val ACTION_QUICK_CAPTURE = "com.ziia.jigeum.QUICK_CAPTURE"
    }

    private var pendingAction: String? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        captureAction(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureAction(intent)
    }

    private fun captureAction(intent: Intent?) {
        if (intent?.action == ACTION_QUICK_CAPTURE) {
            pendingAction = "quick_capture"
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, "jigeum/widget"
        ).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "updateWidgets" -> {
                        val prefs = getSharedPreferences(
                            WidgetPrefs.FILE, Context.MODE_PRIVATE
                        )
                        prefs.edit()
                            .putString(WidgetPrefs.KEY_FOCUS, call.argument("focus") ?: "")
                            .putString(WidgetPrefs.KEY_Q1, call.argument("q1") ?: "")
                            .putString(WidgetPrefs.KEY_Q2, call.argument("q2") ?: "")
                            .putString(WidgetPrefs.KEY_Q3, call.argument("q3") ?: "")
                            .putInt(WidgetPrefs.KEY_Q4_COUNT, call.argument("q4count") ?: 0)
                            .apply()
                        WidgetPrefs.updateAllWidgets(this)
                        result.success(true)
                    }
                    "setWidgetOpacity" -> {
                        val percent = (call.argument<Int>("percent") ?: 90).coerceIn(0, 100)
                        getSharedPreferences(WidgetPrefs.FILE, Context.MODE_PRIVATE)
                            .edit().putInt(WidgetPrefs.KEY_OPACITY, percent).apply()
                        WidgetPrefs.updateAllWidgets(this)
                        result.success(true)
                    }
                    "getWidgetOpacity" -> {
                        val percent = getSharedPreferences(
                            WidgetPrefs.FILE, Context.MODE_PRIVATE
                        ).getInt(WidgetPrefs.KEY_OPACITY, 90)
                        result.success(percent)
                    }
                    "consumeLaunchAction" -> {
                        result.success(pendingAction)
                        pendingAction = null
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.success(null) // 위젯 실패가 앱을 막지 않도록
            }
        }
    }
}
