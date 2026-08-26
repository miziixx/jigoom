package com.ziia.jigeum

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.util.TypedValue
import android.widget.RemoteViews
import java.util.Calendar

/**
 * 캘린더 위젯 (4×4) — 홈 화면. 이번 달 월 그리드 + 오늘 강조.
 * 하단 줄은 앱이 push 한 음력·일진(사주)·별자리(점성학) (설정 토글 반영).
 * 탭하면 앱의 달력 화면으로.
 */
class CalendarWidgetProvider : AppWidgetProvider() {

    public override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val prefs = context.getSharedPreferences(WidgetPrefs.FILE, Context.MODE_PRIVATE)
        val foot = prefs.getString(WidgetPrefs.KEY_CAL_FOOT, "") ?: ""
        // 이번 달 일정 있는 날(일자) 집합 — 그 날 셀 하단에 색 바.
        val eventDays = (prefs.getString(WidgetPrefs.KEY_CAL_EVENTS, "") ?: "")
            .split(",").mapNotNull { it.trim().toIntOrNull() }.toSet()
        val pal = WidgetPrefs.palette(context)
        val alpha = WidgetPrefs.bgAlpha(context)        // 모든 위젯 공통 투명도
        val fs = WidgetPrefs.fontScale(context)          // 모든 위젯 공통 글자 배율

        // 이번 달 그리드 계산 (일요일 시작, 6주 42칸).
        val now = Calendar.getInstance()
        val month = now.get(Calendar.MONTH)
        val title = "${now.get(Calendar.YEAR)}. ${month + 1}"

        val cur = Calendar.getInstance()
        cur.set(Calendar.DAY_OF_MONTH, 1)
        cur.set(Calendar.HOUR_OF_DAY, 12)
        cur.set(Calendar.MINUTE, 0)
        cur.set(Calendar.SECOND, 0)
        cur.set(Calendar.MILLISECOND, 0)
        val firstOffset = cur.get(Calendar.DAY_OF_WEEK) - Calendar.SUNDAY // 일=0
        cur.add(Calendar.DAY_OF_MONTH, -firstOffset)

        val today = Calendar.getInstance()

        val launch = Intent(context, MainActivity::class.java).apply {
            action = MainActivity.ACTION_OPEN_CALENDAR
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pending = PendingIntent.getActivity(
            context, 4, launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.calendar_widget).apply {
                setTextViewText(R.id.cal_title, title)
                setTextColor(R.id.cal_title, pal.ink)
                setTextViewTextSize(R.id.cal_title, TypedValue.COMPLEX_UNIT_SP, 14f * fs)
                setInt(R.id.cal_rule, "setBackgroundColor", pal.ink)
                setTextViewText(R.id.cal_foot, foot)
                setTextColor(R.id.cal_foot, pal.inkSoft)
                setTextViewTextSize(R.id.cal_foot, TypedValue.COMPLEX_UNIT_SP, 10f * fs)
                setInt(R.id.cal_root, "setBackgroundColor",
                    (alpha shl 24) or (pal.paper and 0xFFFFFF))

                // 42칸 채우기 — 매 위젯 갱신마다 cur 를 다시 계산.
                val walk = cur.clone() as Calendar
                for (i in 0 until 42) {
                    val cellId = context.resources.getIdentifier(
                        "cal_d$i", "id", context.packageName)
                    if (cellId != 0) {
                        setTextViewText(cellId, walk.get(Calendar.DAY_OF_MONTH).toString())
                        setTextViewTextSize(cellId, TypedValue.COMPLEX_UNIT_SP, 12f * fs)
                        val inMonth = walk.get(Calendar.MONTH) == month
                        // 격자 구분선 + 일정 있는 날은 하단 색 바.
                        val hasEvent = inMonth &&
                            eventDays.contains(walk.get(Calendar.DAY_OF_MONTH))
                        setInt(cellId, "setBackgroundResource",
                            if (hasEvent) R.drawable.cal_cell_event else R.drawable.cal_cell)
                        val isToday = walk.get(Calendar.YEAR) == today.get(Calendar.YEAR) &&
                            walk.get(Calendar.DAY_OF_YEAR) == today.get(Calendar.DAY_OF_YEAR)
                        // 갤럭시 캘린더처럼 주말 색: 일=빨강, 토=파랑(테마 무관 고정).
                        val dow = walk.get(Calendar.DAY_OF_WEEK)
                        val color = when {
                            isToday -> pal.mark
                            !inMonth -> pal.inkSoft
                            dow == Calendar.SUNDAY -> 0xFFC0645A.toInt()
                            dow == Calendar.SATURDAY -> 0xFF5F7DA0.toInt()
                            else -> pal.ink
                        }
                        setTextColor(cellId, color)
                    }
                    walk.add(Calendar.DAY_OF_MONTH, 1)
                }
                setOnClickPendingIntent(R.id.cal_root, pending)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
