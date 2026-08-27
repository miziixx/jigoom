package com.ziia.jigeum

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject
import java.util.Calendar

/**
 * 캘린더 위젯 — 완전 투명 가능. 삼성 캘린더식: 왼쪽 주차 + 헤더([오늘] 박스) +
 * 격자 박스 없이 은은한 가로 구분선 + 날짜별 파스텔 일정 pill(최대 3개).
 * 일정은 앱이 push 한 JSON({ "일자": [["제목", 색인덱스], ...] }). 탭하면 앱의 달력 화면으로.
 */
class CalendarWidgetProvider : AppWidgetProvider() {

    private val pills = intArrayOf(
        R.drawable.e_pill_0, R.drawable.e_pill_1, R.drawable.e_pill_2,
        R.drawable.e_pill_3, R.drawable.e_pill_4, R.drawable.e_pill_5
    )

    public override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val prefs = context.getSharedPreferences(WidgetPrefs.FILE, Context.MODE_PRIVATE)
        val eventsRaw = prefs.getString(WidgetPrefs.KEY_CAL_EVENTS, "") ?: ""
        val events: JSONObject = try {
            if (eventsRaw.isNotBlank()) JSONObject(eventsRaw) else JSONObject()
        } catch (e: Exception) { JSONObject() }
        val pal = WidgetPrefs.palette(context)
        val alpha = WidgetPrefs.bgAlpha(context)
        val fs = WidgetPrefs.fontScale(context)
        val pkg = context.packageName

        val now = Calendar.getInstance()
        val month = now.get(Calendar.MONTH)
        val title = "${month + 1}월"

        val cur = Calendar.getInstance()
        cur.set(Calendar.DAY_OF_MONTH, 1)
        cur.set(Calendar.HOUR_OF_DAY, 12)
        cur.set(Calendar.MINUTE, 0)
        cur.set(Calendar.SECOND, 0)
        cur.set(Calendar.MILLISECOND, 0)
        val firstOffset = cur.get(Calendar.DAY_OF_WEEK) - Calendar.SUNDAY
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
            val views = RemoteViews(pkg, R.layout.calendar_widget).apply {
                setTextViewText(R.id.cal_title, title)
                setTextColor(R.id.cal_title, pal.ink)
                setTextViewTextSize(R.id.cal_title, TypedValue.COMPLEX_UNIT_SP, 17f * fs)

                // 헤더 ‹ › ✎ ＋ 글리프 — 은은한 보조색.
                setTextColor(R.id.cal_prev, pal.inkSoft)
                setTextColor(R.id.cal_next, pal.inkSoft)
                setTextColor(R.id.cal_edit, pal.inkSoft)
                setTextColor(R.id.cal_add, pal.inkSoft)

                // 헤더 우측 [오늘] 박스 — 오늘 일자.
                setTextViewText(R.id.cal_today, today.get(Calendar.DAY_OF_MONTH).toString())
                setTextColor(R.id.cal_today, pal.mark)
                setTextViewTextSize(R.id.cal_today, TypedValue.COMPLEX_UNIT_SP, 12f * fs)

                setInt(R.id.cal_root, "setBackgroundColor",
                    (alpha shl 24) or (pal.paper and 0xFFFFFF))

                val walk = cur.clone() as Calendar
                for (i in 0 until 42) {
                    // 각 주 시작(일요일)마다 왼쪽 주차 표기.
                    if (i % 7 == 0) {
                        val wkId = context.resources.getIdentifier("cal_wk${i / 7}", "id", pkg)
                        if (wkId != 0) {
                            setTextViewText(wkId, walk.get(Calendar.WEEK_OF_YEAR).toString())
                            setTextColor(wkId, pal.inkSoft)
                            setTextViewTextSize(wkId, TypedValue.COMPLEX_UNIT_SP, 8f * fs)
                        }
                    }

                    val cellId = context.resources.getIdentifier("cal_d$i", "id", pkg)
                    val dayNum = walk.get(Calendar.DAY_OF_MONTH)
                    val inMonth = walk.get(Calendar.MONTH) == month
                    val isToday = walk.get(Calendar.YEAR) == today.get(Calendar.YEAR) &&
                        walk.get(Calendar.DAY_OF_YEAR) == today.get(Calendar.DAY_OF_YEAR)

                    // 오늘은 셀 전체를 둥근 테두리로 감싼다(삼성 스타일). 나머지는 배경 없음.
                    val contId = context.resources.getIdentifier("cal_c$i", "id", pkg)
                    if (contId != 0) {
                        setInt(contId, "setBackgroundResource",
                            if (isToday) R.drawable.today_box else 0)
                    }

                    if (cellId != 0) {
                        setTextViewText(cellId, dayNum.toString())
                        setTextViewTextSize(cellId, TypedValue.COMPLEX_UNIT_SP, 12f * fs)
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

                    // 날짜별 파스텔 일정 pill (최대 3개).
                    val dayEvents = if (inMonth) events.optJSONArray(dayNum.toString()) else null
                    for (k in 0 until 3) {
                        val eId = context.resources.getIdentifier("cal_e${i}_$k", "id", pkg)
                        if (eId == 0) continue
                        if (dayEvents != null && k < dayEvents.length()) {
                            val pair = dayEvents.optJSONArray(k)
                            val t = pair?.optString(0) ?: ""
                            val ci = (pair?.optInt(1) ?: 0).coerceIn(0, pills.size - 1)
                            setTextViewText(eId, t)
                            setInt(eId, "setBackgroundResource", pills[ci])
                            setTextViewTextSize(eId, TypedValue.COMPLEX_UNIT_SP, 8f * fs)
                            setViewVisibility(eId, View.VISIBLE)
                        } else {
                            setViewVisibility(eId, View.GONE)
                        }
                    }
                    walk.add(Calendar.DAY_OF_MONTH, 1)
                }
                setOnClickPendingIntent(R.id.cal_root, pending)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
