package com.ziia.jigeum

import android.Manifest
import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.provider.CalendarContract
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar
import java.util.TimeZone

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
        const val ACTION_VOICE_CAPTURE = "com.ziia.jigeum.VOICE_CAPTURE"
        const val ACTION_EDIT_GOAL = "com.ziia.jigeum.EDIT_GOAL"
        const val REQ_SAVE_BACKUP = 7101
        const val REQ_OPEN_BACKUP = 7102
        const val REQ_CALENDAR_PERM = 7103
    }

    private var pendingAction: String? = null

    // 음성(STT) 브리지 — 'jigeum/stt' 채널.
    private var stt: SttBridge? = null

    // SAF 진행 중 콜백/데이터
    private var backupResult: MethodChannel.Result? = null
    private var backupContent: String? = null

    // 캘린더 권한 요청 진행 중 콜백
    private var permResult: MethodChannel.Result? = null

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        val granted = grantResults.isNotEmpty() &&
            grantResults.all { it == PackageManager.PERMISSION_GRANTED }
        when (requestCode) {
            REQ_CALENDAR_PERM -> {
                permResult?.success(granted)
                permResult = null
            }
            SttBridge.REQ_AUDIO_PERM -> stt?.onAudioPermissionResult(granted)
        }
    }

    override fun onActivityResult(
        requestCode: Int, resultCode: Int, data: Intent?
    ) {
        super.onActivityResult(requestCode, resultCode, data)
        // 음성 다이얼로그 결과는 STT 브리지로 위임.
        if (requestCode == SttBridge.REQ_SPEECH) {
            stt?.onSpeechResult(resultCode, data)
            return
        }
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
                    // 일부 문서 제공자는 "wt" 를 거부 → "w" 로 열고, 스트림이 null
                    // 이면 실패로 정직하게 보고(성공으로 위장하지 않음).
                    val wrote = (
                        contentResolver.openOutputStream(uri, "w")
                            ?: contentResolver.openOutputStream(uri)
                    )?.use {
                        it.write(content.toByteArray(Charsets.UTF_8))
                        it.flush()
                        true
                    } ?: false
                    backupContent = null
                    res.success(wrote)
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

    override fun onDestroy() {
        stt?.dispose()
        stt = null
        super.onDestroy()
    }

    private fun captureAction(intent: Intent?) {
        when (intent?.action) {
            ACTION_QUICK_CAPTURE -> pendingAction = "quick_capture"
            ACTION_TIME_TRACK -> pendingAction = "time_track"
            ACTION_OPEN_CALENDAR -> pendingAction = "open_calendar"
            ACTION_VOICE_CAPTURE -> pendingAction = "voice_capture"
            ACTION_EDIT_GOAL -> pendingAction = "edit_goal"
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        stt = SttBridge(this, flutterEngine.dartExecutor.binaryMessenger)
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
                    "updateGoal" -> {
                        getSharedPreferences(WidgetPrefs.FILE, Context.MODE_PRIVATE)
                            .edit()
                            .putString(WidgetPrefs.KEY_GOAL,
                                call.argument("goal") ?: "")
                            .apply()
                        WidgetPrefs.updateAllWidgets(this)
                        result.success(true)
                    }
                    "consumeLaunchAction" -> {
                        result.success(pendingAction)
                        pendingAction = null
                    }
                    "setGcalCalendars" -> {
                        // 1×1 팝업 스피너용 캘린더(종류) 목록 저장.
                        getSharedPreferences(WidgetPrefs.FILE, Context.MODE_PRIVATE)
                            .edit()
                            .putString(WidgetPrefs.KEY_GCAL_CALENDARS,
                                call.argument<String>("json") ?: "[]")
                            .apply()
                        WidgetPrefs.updateAllWidgets(this)
                        result.success(true)
                    }
                    "consumeQuickAddQueue" -> {
                        // 위젯 팝업으로 쌓인 입력 큐를 1회성으로 넘기고 비운다.
                        val prefs = getSharedPreferences(
                            WidgetPrefs.FILE, Context.MODE_PRIVATE
                        )
                        val queue = prefs.getString(
                            WidgetPrefs.KEY_QUICK_ADD_QUEUE, null
                        )
                        prefs.edit()
                            .remove(WidgetPrefs.KEY_QUICK_ADD_QUEUE).apply()
                        result.success(queue)
                    }
                    // ---- 폰 캘린더(CalendarContract) 연동 ----
                    "calendarPermission" -> result.success(hasCalendarPermission())
                    "requestCalendarPermission" -> {
                        if (hasCalendarPermission()) {
                            result.success(true)
                        } else {
                            permResult = result
                            ActivityCompat.requestPermissions(
                                this,
                                arrayOf(
                                    Manifest.permission.READ_CALENDAR,
                                    Manifest.permission.WRITE_CALENDAR
                                ),
                                REQ_CALENDAR_PERM
                            )
                        }
                    }
                    "listCalendars" -> result.success(listCalendars())
                    "queryEvents" -> result.success(
                        queryEvents(
                            call.argument<String>("calendarId") ?: "",
                            call.argument<Number>("start")?.toLong() ?: 0L,
                            call.argument<Number>("end")?.toLong() ?: 0L
                        )
                    )
                    "insertEvent" -> result.success(insertEvent(call))
                    "updateEvent" -> result.success(updateEvent(call))
                    "deleteEvent" ->
                        result.success(deleteEvent(call.argument<String>("eventId")))
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

    // ------------------------------------------------------ 캘린더 헬퍼

    private fun hasCalendarPermission(): Boolean {
        val read = ContextCompat.checkSelfPermission(
            this, Manifest.permission.READ_CALENDAR
        ) == PackageManager.PERMISSION_GRANTED
        val write = ContextCompat.checkSelfPermission(
            this, Manifest.permission.WRITE_CALENDAR
        ) == PackageManager.PERMISSION_GRANTED
        return read && write
    }

    private fun colorToHex(color: Int): String =
        String.format("#%06X", 0xFFFFFF and color)

    /** 폰 캘린더 목록. */
    private fun listCalendars(): List<Map<String, Any?>> {
        val out = ArrayList<Map<String, Any?>>()
        if (!hasCalendarPermission()) return out
        val proj = arrayOf(
            CalendarContract.Calendars._ID,
            CalendarContract.Calendars.CALENDAR_DISPLAY_NAME,
            CalendarContract.Calendars.ACCOUNT_NAME,
            CalendarContract.Calendars.CALENDAR_COLOR,
            CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL,
            CalendarContract.Calendars.IS_PRIMARY
        )
        contentResolver.query(
            CalendarContract.Calendars.CONTENT_URI, proj, null, null, null
        )?.use { c ->
            while (c.moveToNext()) {
                val level = c.getInt(4)
                val role = when {
                    level >= CalendarContract.Calendars.CAL_ACCESS_OWNER -> "owner"
                    level >= CalendarContract.Calendars.CAL_ACCESS_CONTRIBUTOR -> "writer"
                    else -> "reader"
                }
                out.add(
                    mapOf(
                        "id" to c.getLong(0).toString(),
                        "name" to (c.getString(1) ?: ""),
                        "account" to (c.getString(2) ?: ""),
                        "colorHex" to colorToHex(c.getInt(3)),
                        "accessRole" to role,
                        "primary" to (!c.isNull(5) && c.getInt(5) == 1)
                    )
                )
            }
        }
        return out
    }

    /** 한 캘린더의 [start,end) 이벤트. 반복 이벤트는 마스터 1건으로만 보인다. */
    private fun queryEvents(
        calendarId: String, start: Long, end: Long
    ): List<Map<String, Any?>> {
        val out = ArrayList<Map<String, Any?>>()
        if (!hasCalendarPermission() || calendarId.isEmpty()) return out
        val proj = arrayOf(
            CalendarContract.Events._ID,
            CalendarContract.Events.TITLE,
            CalendarContract.Events.DESCRIPTION,
            CalendarContract.Events.DTSTART,
            CalendarContract.Events.DTEND,
            CalendarContract.Events.ALL_DAY
        )
        val sel = "${CalendarContract.Events.CALENDAR_ID} = ? AND " +
            "${CalendarContract.Events.DTSTART} >= ? AND " +
            "${CalendarContract.Events.DTSTART} < ? AND " +
            "${CalendarContract.Events.DELETED} = 0"
        val args = arrayOf(calendarId, start.toString(), end.toString())
        contentResolver.query(
            CalendarContract.Events.CONTENT_URI, proj, sel, args, null
        )?.use { c ->
            while (c.moveToNext()) {
                val dtstart = c.getLong(3)
                val dtend = if (c.isNull(4)) 0L else c.getLong(4)
                val allDay = !c.isNull(5) && c.getInt(5) == 1
                val startMs: Long
                val endMs: Long
                if (allDay) {
                    startMs = utcMidnightToLocal(dtstart)
                    endMs = if (dtend > 0) utcMidnightToLocal(dtend)
                    else startMs + 86400000L
                } else {
                    startMs = dtstart
                    endMs = if (dtend > 0) dtend else dtstart + 3600000L
                }
                out.add(
                    mapOf(
                        "id" to c.getLong(0).toString(),
                        "title" to (c.getString(1) ?: ""),
                        "note" to (c.getString(2) ?: ""),
                        "startMs" to startMs,
                        "endMs" to endMs,
                        "allDay" to allDay
                    )
                )
            }
        }
        return out
    }

    private fun insertEvent(call: MethodCall): String? {
        if (!hasCalendarPermission()) return null
        val calId = call.argument<String>("calendarId") ?: return null
        val start = call.argument<Number>("start")?.toLong() ?: return null
        val end = call.argument<Number>("end")?.toLong() ?: (start + 3600000L)
        val values = ContentValues().apply {
            put(CalendarContract.Events.CALENDAR_ID, calId.toLong())
            put(CalendarContract.Events.TITLE, call.argument<String>("title") ?: "")
            put(CalendarContract.Events.DESCRIPTION, call.argument<String>("note") ?: "")
            applyTime(this, start, end, call.argument<Boolean>("allDay") ?: false)
        }
        val uri = contentResolver.insert(CalendarContract.Events.CONTENT_URI, values)
            ?: return null
        return ContentUris.parseId(uri).toString()
    }

    private fun updateEvent(call: MethodCall): Boolean {
        if (!hasCalendarPermission()) return false
        val eventId = call.argument<String>("eventId") ?: return false
        val start = call.argument<Number>("start")?.toLong() ?: return false
        val end = call.argument<Number>("end")?.toLong() ?: (start + 3600000L)
        val values = ContentValues().apply {
            put(CalendarContract.Events.TITLE, call.argument<String>("title") ?: "")
            put(CalendarContract.Events.DESCRIPTION, call.argument<String>("note") ?: "")
            applyTime(this, start, end, call.argument<Boolean>("allDay") ?: false)
        }
        val uri = ContentUris.withAppendedId(
            CalendarContract.Events.CONTENT_URI, eventId.toLong()
        )
        return contentResolver.update(uri, values, null, null) > 0
    }

    private fun deleteEvent(eventId: String?): Boolean {
        if (!hasCalendarPermission() || eventId == null) return false
        val uri = ContentUris.withAppendedId(
            CalendarContract.Events.CONTENT_URI, eventId.toLong()
        )
        return contentResolver.delete(uri, null, null) >= 0
    }

    /** 종일/시간제에 맞춰 DTSTART/DTEND/ALL_DAY/EVENT_TIMEZONE 채우기. */
    private fun applyTime(v: ContentValues, start: Long, end: Long, allDay: Boolean) {
        if (allDay) {
            v.put(CalendarContract.Events.DTSTART, localMidnightToUtc(start))
            v.put(CalendarContract.Events.DTEND, localMidnightToUtc(end))
            v.put(CalendarContract.Events.ALL_DAY, 1)
            v.put(CalendarContract.Events.EVENT_TIMEZONE, "UTC")
        } else {
            v.put(CalendarContract.Events.DTSTART, start)
            v.put(CalendarContract.Events.DTEND, end)
            v.put(CalendarContract.Events.ALL_DAY, 0)
            v.put(CalendarContract.Events.EVENT_TIMEZONE, TimeZone.getDefault().id)
        }
    }

    /** UTC 자정(종일 저장값) → 그 날짜의 로컬 자정 millis. */
    private fun utcMidnightToLocal(utcMs: Long): Long {
        val u = Calendar.getInstance(TimeZone.getTimeZone("UTC"))
        u.timeInMillis = utcMs
        val local = Calendar.getInstance()
        local.set(
            u.get(Calendar.YEAR), u.get(Calendar.MONTH),
            u.get(Calendar.DAY_OF_MONTH), 0, 0, 0
        )
        local.set(Calendar.MILLISECOND, 0)
        return local.timeInMillis
    }

    /** 로컬 자정 → 같은 날짜의 UTC 자정 millis (종일 이벤트 저장용). */
    private fun localMidnightToUtc(localMs: Long): Long {
        val l = Calendar.getInstance()
        l.timeInMillis = localMs
        val u = Calendar.getInstance(TimeZone.getTimeZone("UTC"))
        u.set(
            l.get(Calendar.YEAR), l.get(Calendar.MONTH),
            l.get(Calendar.DAY_OF_MONTH), 0, 0, 0
        )
        u.set(Calendar.MILLISECOND, 0)
        return u.timeInMillis
    }
}
