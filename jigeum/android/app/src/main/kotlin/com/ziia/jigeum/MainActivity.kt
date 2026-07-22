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
 *  - saveBackup / openBackup: SAF 문서창으로 백업 JSON 저장/열기 (플러그인 없이)
 */
class MainActivity : FlutterActivity() {

    companion object {
        const val ACTION_QUICK_CAPTURE = "com.ziia.jigeum.QUICK_CAPTURE"
        const val ACTION_TIME_TRACK = "com.ziia.jigeum.TIME_TRACK"
        const val ACTION_OPEN_CALENDAR = "com.ziia.jigeum.OPEN_CALENDAR"
        const val REQ_SAVE_BACKUP = 7101
        const val REQ_OPEN_BACKUP = 7102
    }

    private var pendingAction: String? = null

    // SAF 진행 중 콜백/데이터
    private var backupResult: MethodChannel.Result? = null
    private var backupContent: String? = null

    override fun onActivityResult(
        requestCode: Int, resultCode: Int, data: Intent?
    ) {
        super.onActivityResult(requestCode, resultCode, data)
        val res = backupResult ?: return
        backupResult = null
        try {
            val uri = data?.data
            if (resultCode != RESULT_OK || uri == null) {
                res.success(null) // 사용자가 취소
                return
            }
            when (requestCode) {
                REQ_SAVE_BACKUP -> {
                    val content = backupContent ?: ""
                    contentResolver.openOutputStream(uri, "wt")?.use {
                        it.write(content.toByteArray(Charsets.UTF_8))
                    }
                    backupContent = null
                    res.success(true)
                }
                REQ_OPEN_BACKUP -> {
                    val text = contentResolver.openInputStream(uri)?.use {
                        it.readBytes().toString(Charsets.UTF_8)
                    }
                    res.success(text)
                }
                else -> res.success(null)
            }
        } catch (e: Exception) {
            res.success(null)
        }
    }

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
        when (intent?.action) {
            ACTION_QUICK_CAPTURE -> pendingAction = "quick_capture"
            ACTION_TIME_TRACK -> pendingAction = "time_track"
            ACTION_OPEN_CALENDAR -> pendingAction = "open_calendar"
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
                        val edit = prefs.edit()
                            .putString(WidgetPrefs.KEY_FOCUS, call.argument("focus") ?: "")
                            .putString(WidgetPrefs.KEY_Q1, call.argument("q1") ?: "")
                            .putString(WidgetPrefs.KEY_Q2, call.argument("q2") ?: "")
                            .putString(WidgetPrefs.KEY_Q3, call.argument("q3") ?: "")
                            .putInt(WidgetPrefs.KEY_Q4_COUNT, call.argument("q4count") ?: 0)
                            .putString(WidgetPrefs.KEY_CAL_FOOT, call.argument("calFoot") ?: "")
                        // 테마 색(있을 때만) — 앱 테마와 위젯 톤 일치.
                        call.argument<String>("paper")?.let { edit.putString(WidgetPrefs.KEY_PAPER, it) }
                        call.argument<String>("ink")?.let { edit.putString(WidgetPrefs.KEY_INK, it) }
                        call.argument<String>("inkSoft")?.let { edit.putString(WidgetPrefs.KEY_INK_SOFT, it) }
                        call.argument<String>("line")?.let { edit.putString(WidgetPrefs.KEY_LINE, it) }
                        call.argument<String>("mark")?.let { edit.putString(WidgetPrefs.KEY_MARK, it) }
                        edit.apply()
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
                    "updateTimeTrack" -> {
                        getSharedPreferences(WidgetPrefs.FILE, Context.MODE_PRIVATE)
                            .edit()
                            .putString(WidgetPrefs.KEY_TT_LABEL,
                                call.argument("label") ?: "지금")
                            .putString(WidgetPrefs.KEY_TT_TEXT,
                                call.argument("text") ?: "탭해서 기록")
                            .apply()
                        WidgetPrefs.updateAllWidgets(this)
                        result.success(true)
                    }
                    "consumeLaunchAction" -> {
                        result.success(pendingAction)
                        pendingAction = null
                    }
                    "saveBackup" -> {
                        backupResult = result
                        backupContent = call.argument<String>("content") ?: ""
                        val name = call.argument<String>("filename")
                            ?: "jigeum-backup.json"
                        val intent =
                            Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = "application/json"
                                putExtra(Intent.EXTRA_TITLE, name)
                            }
                        startActivityForResult(intent, REQ_SAVE_BACKUP)
                    }
                    "openBackup" -> {
                        backupResult = result
                        val intent =
                            Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = "*/*"
                            }
                        startActivityForResult(intent, REQ_OPEN_BACKUP)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.success(null) // 위젯 실패가 앱을 막지 않도록
            }
        }
    }
}
