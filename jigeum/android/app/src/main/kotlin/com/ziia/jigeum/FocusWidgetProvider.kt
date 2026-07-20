package com.ziia.jigeum

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * 포커스 위젯 (2×1) — 표시 전용.
 * home_widget 의 SharedPreferences 브리지에서 focus_title 을 읽어 표시한다.
 * (인터랙티브 완료 버튼은 안정화를 위해 현재 미연결.)
 */
class FocusWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (widgetId in appWidgetIds) {
            val prefs = HomeWidgetPlugin.getData(context)
            val title = prefs.getString("focus_title", "오늘 할 일을 정해볼까요")
            val views = RemoteViews(context.packageName, R.layout.focus_widget).apply {
                setTextViewText(R.id.widget_title, title)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
