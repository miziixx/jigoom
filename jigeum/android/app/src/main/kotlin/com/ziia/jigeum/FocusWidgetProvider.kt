package com.ziia.jigeum

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/**
 * 포커스 위젯 (2×1) — 순수 안드로이드 구현 (플러그인 의존 없음).
 * MainActivity 가 MethodChannel 로 저장한 SharedPreferences("jigeum_widget")의
 * focus_title 을 읽어 표시한다. 위젯 탭 → 앱 열기.
 */
class FocusWidgetProvider : AppWidgetProvider() {

    companion object {
        const val PREFS = "jigeum_widget"
        const val KEY_TITLE = "focus_title"

        /** 등록된 모든 위젯 인스턴스를 갱신. */
        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                android.content.ComponentName(context, FocusWidgetProvider::class.java)
            )
            if (ids.isNotEmpty()) {
                FocusWidgetProvider().onUpdate(context, manager, ids)
            }
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val title = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_TITLE, "오늘 할 일을 정해볼까요")

        // 위젯 탭 → 앱 열기
        val launch = Intent(context, MainActivity::class.java)
        val pending = PendingIntent.getActivity(
            context, 0, launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.focus_widget).apply {
                setTextViewText(R.id.widget_title, title)
                setOnClickPendingIntent(R.id.widget_title, pending)
                setOnClickPendingIntent(R.id.widget_check, pending)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
