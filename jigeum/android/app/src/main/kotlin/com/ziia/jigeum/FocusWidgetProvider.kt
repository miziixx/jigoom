package com.ziia.jigeum

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * 포커스 위젯 (2×1) — MVP.
 * 표시: 포커스 노드 title + 체크 버튼.
 * 체크 탭 → home_widget background 콜백(goalapp://complete?id=...) → Flutter 에서 done 처리.
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
            val id = prefs.getString("focus_id", "") ?: ""

            val views = RemoteViews(context.packageName, R.layout.focus_widget).apply {
                setTextViewText(R.id.widget_title, title)

                if (id.isNotEmpty()) {
                    val uri = Uri.parse("goalapp://complete?id=$id")
                    val intent: PendingIntent =
                        HomeWidgetBackgroundIntent.getBroadcast(context, uri)
                    setOnClickPendingIntent(R.id.widget_check, intent)
                }
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
