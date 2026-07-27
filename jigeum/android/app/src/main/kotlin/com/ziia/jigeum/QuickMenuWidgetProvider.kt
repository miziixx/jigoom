package com.ziia.jigeum

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/**
 * 3×1 빠른 입력 메뉴 위젯 — 홈 화면. 네 칸(빠른담기·일정·기록·음성)을 탭하면
 * 앱이 떠서 해당 입력을 바로 연다. 음성은 앱을 띄워 마이크를 시작하고, 받아쓴
 * 말을 규칙 엔진이 분류해 알맞은 곳(하이브리드 라우팅)으로 담는다.
 *
 * 목적지 3개는 기존 런치 액션을 재사용한다:
 *  - 빠른담기 → ACTION_QUICK_CAPTURE (오늘 할 일 입력)
 *  - 일정     → ACTION_OPEN_CALENDAR (달력에서 일정 추가)
 *  - 기록     → ACTION_TIME_TRACK   (현재 블록 기록 입력)
 *  - 음성     → ACTION_VOICE_CAPTURE (마이크 시작 → 분류·라우팅)
 */
class QuickMenuWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val alpha = WidgetPrefs.bgAlpha(context)
        val pal = WidgetPrefs.palette(context)

        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.quick_menu_widget).apply {
                setInt(R.id.qm_root, "setBackgroundColor",
                    (alpha shl 24) or (pal.paper and 0xFFFFFF))
                setTextColor(R.id.qm_todo, pal.ink)
                setTextColor(R.id.qm_schedule, pal.ink)
                setTextColor(R.id.qm_log, pal.ink)
                setTextColor(R.id.qm_voice, pal.mark)
                setOnClickPendingIntent(R.id.qm_todo,
                    launch(context, MainActivity.ACTION_QUICK_CAPTURE, 10))
                setOnClickPendingIntent(R.id.qm_schedule,
                    launch(context, MainActivity.ACTION_OPEN_CALENDAR, 11))
                setOnClickPendingIntent(R.id.qm_log,
                    launch(context, MainActivity.ACTION_TIME_TRACK, 12))
                setOnClickPendingIntent(R.id.qm_voice,
                    launch(context, MainActivity.ACTION_VOICE_CAPTURE, 13))
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    /** MainActivity 를 지정 액션으로 여는 PendingIntent(칸마다 다른 requestCode). */
    private fun launch(context: Context, action: String, reqCode: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            this.action = action
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(
            context, reqCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }
}
