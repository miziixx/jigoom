package com.ziia.jigeum

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/**
 * 포커스 위젯 (2×1) — 순수 안드로이드 구현.
 * 오늘의 포커스 표시. 탭하면 앱이 퀵캡처 입력 모드로 열림 (키보드 바로).
 */
class FocusWidgetProvider : AppWidgetProvider() {

    public override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val prefs = context.getSharedPreferences(WidgetPrefs.FILE, Context.MODE_PRIVATE)
        val title = prefs.getString(WidgetPrefs.KEY_FOCUS, "오늘 할 일을 정해볼까요")
        val alpha = WidgetPrefs.bgAlpha(context)

        // 탭 → 앱을 퀵캡처 모드로 열기
        val capture = Intent(context, MainActivity::class.java).apply {
            action = MainActivity.ACTION_QUICK_CAPTURE
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pending = PendingIntent.getActivity(
            context, 1, capture,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.focus_widget).apply {
                setTextViewText(R.id.widget_title, title)
                setInt(R.id.widget_bg_img, "setImageAlpha", alpha)
                setOnClickPendingIntent(R.id.widget_root, pending)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
