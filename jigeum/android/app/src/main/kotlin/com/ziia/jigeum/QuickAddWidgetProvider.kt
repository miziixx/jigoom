package com.ziia.jigeum

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/**
 * 1×1 빠른 추가 위젯 — 홈 화면. 탭하면 앱을 열지 않고 반투명 팝업
 * (QuickAddActivity)이 떠서 제목·캘린더(종류)를 바로 입력할 수 있다.
 * 입력은 큐에 쌓이고, 앱이 열릴 때 구글 캘린더로 동기화된다.
 */
class QuickAddWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val alpha = WidgetPrefs.bgAlpha(context)
        val pal = WidgetPrefs.palette(context)

        val launch = Intent(context, QuickAddActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pending = PendingIntent.getActivity(
            context, 5, launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.quick_add_widget).apply {
                setInt(R.id.qa_root, "setBackgroundColor",
                    (alpha shl 24) or (pal.paper and 0xFFFFFF))
                setTextColor(R.id.qa_plus, pal.ink)
                setTextColor(R.id.qa_label, pal.inkSoft)
                setOnClickPendingIntent(R.id.qa_root, pending)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
