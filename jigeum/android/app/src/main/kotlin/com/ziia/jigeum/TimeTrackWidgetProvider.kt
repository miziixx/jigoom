package com.ziia.jigeum

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/**
 * 타임트래커 위젯 — 순수 안드로이드. 홈 화면.
 * 지금 시각 블록 + 마지막 기록을 보여주고, 탭하면 앱이 열려 바로 입력창(현재 블록).
 */
class TimeTrackWidgetProvider : AppWidgetProvider() {

    public override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val prefs = context.getSharedPreferences(WidgetPrefs.FILE, Context.MODE_PRIVATE)
        val label = prefs.getString(WidgetPrefs.KEY_TT_LABEL, "지금")
        val text = prefs.getString(WidgetPrefs.KEY_TT_TEXT, "탭해서 기록")
        val alpha = WidgetPrefs.bgAlpha(context)
        val pal = WidgetPrefs.palette(context)

        // 탭 → 타임트래커 입력 모드로 앱 열기
        val intent = Intent(context, MainActivity::class.java).apply {
            action = MainActivity.ACTION_TIME_TRACK
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pending = PendingIntent.getActivity(
            context, 3, intent,
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
                setTextColor(R.id.tt_label, pal.inkSoft)
                setTextColor(R.id.tt_text, pal.ink)
                setOnClickPendingIntent(R.id.tt_root, pending)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
