package com.ziia.jigeum

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.graphics.Color

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

    // 앱에서 선택한 테마의 6토큰(앱과 위젯 톤 일치). 기본 = MANILA.
    const val KEY_PAPER = "t_paper"
    const val KEY_INK = "t_ink"
    const val KEY_INK_SOFT = "t_ink_soft"
    const val KEY_LINE = "t_line"
    const val KEY_MARK = "t_mark"

    /** 위젯에 적용할 테마 색 팔레트. */
    data class Palette(
        val paper: Int,
        val ink: Int,
        val inkSoft: Int,
        val line: Int,
        val mark: Int,
    )

    private fun parse(hex: String?, fallback: String): Int =
        try {
            Color.parseColor(hex ?: fallback)
        } catch (e: Exception) {
            Color.parseColor(fallback)
        }

    fun palette(context: Context): Palette {
        val p = context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
        return Palette(
            paper = parse(p.getString(KEY_PAPER, null), "#F4F1EA"),
            ink = parse(p.getString(KEY_INK, null), "#26241F"),
            inkSoft = parse(p.getString(KEY_INK_SOFT, null), "#9A948A"),
            line = parse(p.getString(KEY_LINE, null), "#D8D2C6"),
            mark = parse(p.getString(KEY_MARK, null), "#B5443A"),
        )
    }

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
