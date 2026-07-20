package com.ziia.jigeum

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * 'jigeum/widget' MethodChannel:
 *  updateFocus(title) → SharedPreferences 저장 + 홈 위젯 갱신.
 * 플러그인 없이 위젯 데이터를 전달하는 유일한 통로.
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, "jigeum/widget"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "updateFocus" -> {
                    try {
                        val title = call.argument<String>("title") ?: ""
                        getSharedPreferences(
                            FocusWidgetProvider.PREFS, Context.MODE_PRIVATE
                        ).edit().putString(FocusWidgetProvider.KEY_TITLE, title).apply()
                        FocusWidgetProvider.updateAll(this)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false) // 위젯 실패가 앱을 막지 않도록
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
