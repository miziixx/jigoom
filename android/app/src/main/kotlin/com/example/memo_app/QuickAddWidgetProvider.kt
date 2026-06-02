package com.example.memo_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/** 1×1 quick-add widget — tap to open the memo input popup. */
class QuickAddWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) update(context, appWidgetManager, id)
    }

    private fun update(context: Context, manager: AppWidgetManager, widgetId: Int) {
        val c = WidgetDataHelper.widgetColors(context)
        val views = RemoteViews(context.packageName, R.layout.widget_quick_add)

        views.setInt(R.id.qa_root, "setBackgroundColor", c.bg)
        views.setTextColor(R.id.qa_plus, c.text)
        views.setTextColor(R.id.qa_label, c.dim)

        val intent = Intent(context, MemoInputActivity::class.java).apply {
            putExtra(MemoWidgetProvider.EXTRA_MODE, MemoWidgetProvider.MODE_NORMAL)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pi = PendingIntent.getActivity(
            context, widgetId + 9000, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        views.setOnClickPendingIntent(R.id.qa_root, pi)

        manager.updateAppWidget(widgetId, views)
    }
}
