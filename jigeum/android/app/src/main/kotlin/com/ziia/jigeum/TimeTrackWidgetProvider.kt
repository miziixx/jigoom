package com.ziia.jigeum

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * 타임트래커 위젯 — 순수 안드로이드. 홈 화면.
 *
 * 탭하면 앱을 열지 않고 그 자리에서 집중 기록(FocusSession)을 시작/정지한다.
 * 진행 중이면 시작 시각을, 대기면 안내를 보여준다. 정지 시 완료 세션을 큐에
 * 쌓아 앱이 다음에 열릴 때 FocusSessions 로 반영한다. 마이크 칸만 앱(음성)으로.
 */
class TimeTrackWidgetProvider : AppWidgetProvider() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_TOGGLE) {
            toggle(context)
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(
                ComponentName(context, TimeTrackWidgetProvider::class.java)
            )
            onUpdate(context, mgr, ids)
            return
        }
        super.onReceive(context, intent)
    }

    public override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val prefs = context.getSharedPreferences(WidgetPrefs.FILE, Context.MODE_PRIVATE)
        val running = prefs.getBoolean(WidgetPrefs.KEY_TT_RUNNING, false)
        val alpha = WidgetPrefs.bgAlpha(context)
        val pal = WidgetPrefs.palette(context)

        val label: String
        val text: String
        if (running) {
            val started =
                prefs.getLong(WidgetPrefs.KEY_TT_STARTED, System.currentTimeMillis())
            val hm = SimpleDateFormat("HH:mm", Locale.KOREA).format(Date(started))
            label = "기록 중"
            text = "$hm 시작 · 탭해서 정지"
        } else {
            label = prefs.getString(WidgetPrefs.KEY_TT_LABEL, "타임트래커") ?: "타임트래커"
            text = "탭해서 기록 시작"
        }

        // 탭(루트) → 앱 없이 시작/정지 토글 (자기 자신에게 브로드캐스트).
        val toggle = Intent(context, TimeTrackWidgetProvider::class.java).apply {
            action = ACTION_TOGGLE
        }
        val togglePending = PendingIntent.getBroadcast(
            context, 3, toggle,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // 마이크 칸 → 앱을 열어 음성 캡처(분류·라우팅).
        val voice = Intent(context, MainActivity::class.java).apply {
            action = MainActivity.ACTION_VOICE_CAPTURE
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val voicePending = PendingIntent.getActivity(
            context, 15, voice,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.time_track_widget).apply {
                setTextViewText(R.id.tt_label, label)
                setTextViewText(R.id.tt_text, text)
                // 배경: 테마 paper + 투명도(alpha) 를 루트에 직접.
                setInt(R.id.tt_root, "setBackgroundColor",
                    (alpha shl 24) or (pal.paper and 0xFFFFFF))
                setInt(R.id.tt_bar, "setBackgroundColor", pal.mark)
                // 진행 중이면 라벨을 강조색으로 상태를 알린다.
                setTextColor(R.id.tt_label, if (running) pal.mark else pal.inkSoft)
                setTextColor(R.id.tt_text, pal.ink)
                setTextColor(R.id.tt_mic, pal.mark)
                setOnClickPendingIntent(R.id.tt_root, togglePending)
                setOnClickPendingIntent(R.id.tt_mic, voicePending)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    companion object {
        const val ACTION_TOGGLE = "com.ziia.jigeum.TT_TOGGLE"

        /** 시작/정지 토글. 정지 시 완료 세션을 큐에 쌓아 앱이 반영하게 한다. */
        private fun toggle(context: Context) {
            val prefs =
                context.getSharedPreferences(WidgetPrefs.FILE, Context.MODE_PRIVATE)
            val running = prefs.getBoolean(WidgetPrefs.KEY_TT_RUNNING, false)
            val now = System.currentTimeMillis()
            if (!running) {
                prefs.edit()
                    .putBoolean(WidgetPrefs.KEY_TT_RUNNING, true)
                    .putLong(WidgetPrefs.KEY_TT_STARTED, now)
                    .apply()
            } else {
                val started = prefs.getLong(WidgetPrefs.KEY_TT_STARTED, now)
                val raw = prefs.getString(WidgetPrefs.KEY_FOCUS_QUEUE, null)
                val arr = try {
                    if (raw.isNullOrEmpty()) JSONArray() else JSONArray(raw)
                } catch (e: Exception) {
                    JSONArray()
                }
                arr.put(JSONObject().put("startedAt", started).put("endedAt", now))
                prefs.edit()
                    .putBoolean(WidgetPrefs.KEY_TT_RUNNING, false)
                    .remove(WidgetPrefs.KEY_TT_STARTED)
                    .putString(WidgetPrefs.KEY_FOCUS_QUEUE, arr.toString())
                    .apply()
            }
        }
    }
}
