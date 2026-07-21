package com.ziia.jigeum

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context

/** 위젯 공용 SharedPreferences 키 + 전체 갱신 헬퍼. */
object WidgetPrefs {
    const val FILE = "jigeum_widget"
    const val KEY_FOCUS = "focus_title"
    const val KEY_Q1 = "q1"
    const val KEY_Q2 = "q2"
    const val KEY_Q3 = "q3"
    const val KEY_Q4_COUNT = "q4_count"
    const val KEY_OPACITY = "opacity" // 0~100
    const val KEY_TT_LABEL = "tt_label"
    const val KEY_TT_TEXT = "tt_text"

    /** 배경 알파(0~255). */
    fun bgAlpha(context: Context): Int {
        val percent = context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
            .getInt(KEY_OPACITY, 90).coerceIn(0, 100)
        return percent * 255 / 100
    }

    fun updateAllWidgets(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        listOf(
            FocusWidgetProvider::class.java to FocusWidgetProvider(),
            MatrixWidgetProvider::class.java to MatrixWidgetProvider(),
            TimeTrackWidgetProvider::class.java to TimeTrackWidgetProvider(),
        ).forEach { (cls, provider) ->
            val ids = manager.getAppWidgetIds(ComponentName(context, cls))
            if (ids.isNotEmpty()) provider.onUpdate(context, manager, ids)
        }
    }
}
