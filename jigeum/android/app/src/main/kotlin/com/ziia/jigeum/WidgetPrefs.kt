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
    const val KEY_TT_RUNNING = "tt_running" // 집중 기록 진행 중 여부(위젯 탭 토글)
    const val KEY_TT_STARTED = "tt_started_at" // 진행 중 세션 시작(epoch millis)
    const val KEY_FOCUS_QUEUE = "focus_queue" // 완료 세션 큐 JSON [{startedAt,endedAt}] — 앱이 드레인
    const val KEY_GOAL = "day_goal" // 오늘의 목표(여러 줄, 개행 구분)
    const val KEY_CAL_FOOT = "cal_foot" // 캘린더 위젯 하단: 음력·일진·별자리
    const val KEY_CAL_EVENTS = "cal_events" // 이번 달 일정 있는 날 목록(콤마 구분 일자)

    // 구글 캘린더 연동. 1×1 팝업 스피너용 목록 + 입력 큐(앱이 비워 동기화).
    const val KEY_GCAL_CALENDARS = "gcal_calendars" // JSON [{id,name,color}]
    const val KEY_QUICK_ADD_QUEUE = "quick_add_queue" // JSON [{title,calendarId,allDay,at}]

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

    // 위젯 공통 설정(모든 위젯에 적용) — 생성 설정창에서 정한다.
    const val KEY_W_THEME = "w_theme"       // "app" | gomgom | lavender | ...
    const val KEY_W_FONTSCALE = "w_fontscale" // 85 | 100 | 120

    /** 곰곰 6테마 위젯 팔레트(앱 theme.dart 와 동일 값). "app" 은 앱이 push 한 색. */
    private val THEME_PALETTES: Map<String, Palette> = mapOf(
        "gomgom" to Palette(0xFFEAE4D9.toInt(), 0xFF231E18.toInt(), 0xFF897F70.toInt(), 0xFFDAD2C3.toInt(), 0xFFD6852A.toInt()),
        "lavender" to Palette(0xFFECE5EF.toInt(), 0xFF2E2733.toInt(), 0xFF8A8092.toInt(), 0xFFDCD3E3.toInt(), 0xFFD79E3B.toInt()),
        "sagemist" to Palette(0xFFE7E9DE.toInt(), 0xFF2B322A.toInt(), 0xFF7C8377.toInt(), 0xFFD6DACB.toInt(), 0xFFC4794A.toInt()),
        "coastal" to Palette(0xFFF1EADF.toInt(), 0xFF3A2C20.toInt(), 0xFF8C7C68.toInt(), 0xFFE0D4C1.toInt(), 0xFFC1854E.toInt()),
        "blush" to Palette(0xFFF3E7E4.toInt(), 0xFF33272A.toInt(), 0xFF907E82.toInt(), 0xFFE7D6D3.toInt(), 0xFFD08A6A.toInt()),
        "lotus" to Palette(0xFF102A22.toInt(), 0xFFF0EAD6.toInt(), 0xFF9FB3A2.toInt(), 0xFF28453A.toInt(), 0xFFDDA08F.toInt()),
    )

    fun widgetThemeKey(context: Context): String =
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
            .getString(KEY_W_THEME, "app") ?: "app"

    /** 위젯 글자 배율(0.85~1.2). */
    fun fontScale(context: Context): Float {
        val pct = context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
            .getInt(KEY_W_FONTSCALE, 100).coerceIn(70, 140)
        return pct / 100f
    }

    fun palette(context: Context): Palette {
        val p = context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
        // 위젯 테마를 골랐으면 그 팔레트, 아니면 앱이 push 한 색(앱 테마 따라가기).
        val chosen = THEME_PALETTES[widgetThemeKey(context)]
        if (chosen != null) return chosen
        return Palette(
            paper = parse(p.getString(KEY_PAPER, null), "#F4F1EA"),
            ink = parse(p.getString(KEY_INK, null), "#26241F"),
            inkSoft = parse(p.getString(KEY_INK_SOFT, null), "#9A948A"),
            line = parse(p.getString(KEY_LINE, null), "#D8D2C6"),
            mark = parse(p.getString(KEY_MARK, null), "#B5443A"),
        )
    }

    /** 배경 알파(0~255) — 앱 전역 설정. */
    fun bgAlpha(context: Context): Int {
        val percent = context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
            .getInt(KEY_OPACITY, 90).coerceIn(0, 100)
        return percent * 255 / 100
    }

    /** 위젯별 배경 진하기(%) — 생성 시 설정창에서 정한 값. 없으면 전역 설정. */
    const val KEY_OPACITY_PREFIX = "opacity_" // opacity_<appWidgetId>

    fun opacityPercentFor(context: Context, widgetId: Int): Int {
        val p = context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
        val perWidget = p.getInt(KEY_OPACITY_PREFIX + widgetId, -1)
        return if (perWidget in 0..100) perWidget
        else p.getInt(KEY_OPACITY, 90).coerceIn(0, 100)
    }

    /** 위젯별 배경 알파(0~255). 설정창이 정한 위젯별 값 우선, 없으면 전역. */
    fun bgAlphaFor(context: Context, widgetId: Int): Int =
        opacityPercentFor(context, widgetId) * 255 / 100

    fun setWidgetOpacity(context: Context, widgetId: Int, percent: Int) {
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE).edit()
            .putInt(KEY_OPACITY_PREFIX + widgetId, percent.coerceIn(0, 100))
            .apply()
    }

    fun updateAllWidgets(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        listOf(
            FocusWidgetProvider::class.java to FocusWidgetProvider(),
            MatrixWidgetProvider::class.java to MatrixWidgetProvider(),
            TimeTrackWidgetProvider::class.java to TimeTrackWidgetProvider(),
            CalendarWidgetProvider::class.java to CalendarWidgetProvider(),
            QuickAddWidgetProvider::class.java to QuickAddWidgetProvider(),
            QuickMenuWidgetProvider::class.java to QuickMenuWidgetProvider(),
            GoalWidgetProvider::class.java to GoalWidgetProvider(),
        ).forEach { (cls, provider) ->
            val ids = manager.getAppWidgetIds(ComponentName(context, cls))
            if (ids.isNotEmpty()) provider.onUpdate(context, manager, ids)
        }
    }
}
