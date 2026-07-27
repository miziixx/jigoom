package com.ziia.jigeum

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/**
 * 4×2 오늘의 목표 위젯 — 홈 화면. 앱의 오늘의 목표(여러 줄)를 크고 굵게 보여준다.
 * 탭하면 앱이 떠서 목표 편집기를 연다(ACTION_EDIT_GOAL).
 */
class GoalWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val alpha = WidgetPrefs.bgAlpha(context)
        val pal = WidgetPrefs.palette(context)
        val prefs = context.getSharedPreferences(WidgetPrefs.FILE, Context.MODE_PRIVATE)
        val goal = prefs.getString(WidgetPrefs.KEY_GOAL, null)?.trim().orEmpty()

        // 각 줄 앞에 별표를 붙여 목록처럼 — 비어 있으면 안내 문구.
        val display = if (goal.isEmpty()) {
            "탭해서 오늘의 목표 적기"
        } else {
            goal.split("\n")
                .map { it.trim() }
                .filter { it.isNotEmpty() }
                .joinToString("\n") { "★ $it" }
        }

        val pending = PendingIntent.getActivity(
            context, 20,
            Intent(context, MainActivity::class.java).apply {
                action = MainActivity.ACTION_EDIT_GOAL
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.goal_widget).apply {
                setInt(R.id.goal_root, "setBackgroundColor",
                    (alpha shl 24) or (pal.paper and 0xFFFFFF))
                setTextColor(R.id.goal_label, pal.mark)
                setTextColor(R.id.goal_text,
                    if (goal.isEmpty()) pal.inkSoft else pal.ink)
                setTextViewText(R.id.goal_text, display)
                setOnClickPendingIntent(R.id.goal_root, pending)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
