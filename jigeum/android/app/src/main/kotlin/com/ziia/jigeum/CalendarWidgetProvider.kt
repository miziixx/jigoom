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
 * 은은한 가로 구분선 + 음력 날짜 + 여러 날 이어지는 색 막대(종일) / 회색 글자(시간).
 * 데이터는 앱이 push 한 그리드칸(0~41) 기준 JSON. 탭하면 앱의 달력 화면으로.
 */
class CalendarWidgetProvider : AppWidgetProvider() {

    // [색인덱스][스타일] → 막대 드로어블. 스타일 0 단독 · 1 시작 · 2 중간 · 3 끝.
    private val barRes = arrayOf(
        intArrayOf(R.drawable.e_bar_0_0, R.drawable.e_bar_0_1, R.drawable.e_bar_0_2, R.drawable.e_bar_0_3),
        intArrayOf(R.drawable.e_bar_1_0, R.drawable.e_bar_1_1, R.drawable.e_bar_1_2, R.drawable.e_bar_1_3),
        intArrayOf(R.drawable.e_bar_2_0, R.drawable.e_bar_2_1, R.drawable.e_bar_2_2, R.drawable.e_bar_2_3),
        intArrayOf(R.drawable.e_bar_3_0, R.drawable.e_bar_3_1, R.drawable.e_bar_3_2, R.drawable.e_bar_3_3),
        intArrayOf(R.drawable.e_bar_4_0, R.drawable.e_bar_4_1, R.drawable.e_bar_4_2, R.drawable.e_bar_4_3),
        intArrayOf(R.drawable.e_bar_5_0, R.drawable.e_bar_5_1, R.drawable.e_bar_5_2, R.drawable.e_bar_5_3)
    )

    public override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val prefs = context.getSharedPreferences(WidgetPrefs.FILE, Context.MODE_PRIVATE)
        val eventsRaw = prefs.getString(WidgetPrefs.KEY_CAL_EVENTS, "") ?: ""
        val lunarRaw = prefs.getString(WidgetPrefs.KEY_CAL_LUNAR, "") ?: ""
        val events: JSONObject = try {
            if (eventsRaw.isNotBlank()) JSONObject(eventsRaw) else JSONObject()
        } catch (e: Exception) { JSONObject() }
        val lunar: JSONObject = try {
            if (lunarRaw.isNotBlank()) JSONObject(lunarRaw) else JSONObject()
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

                    // 음력 날짜(일요일·오늘 칸에만 push 됨).
                    val lunId = context.resources.getIdentifier("cal_l$i", "id", pkg)
                    if (lunId != 0) {
                        val ls = lunar.optString(i.toString(), "")
                        if (ls.isNotEmpty()) {
                            setTextViewText(lunId, ls)
                            setTextColor(lunId, pal.inkSoft)
                            setTextViewTextSize(lunId, TypedValue.COMPLEX_UNIT_SP, 7f * fs)
                            setViewVisibility(lunId, View.VISIBLE)
                        } else {
                            setViewVisibility(lunId, View.GONE)
                        }
                    }

                    // 일정 슬롯 3개 — 종일=색막대(이어짐) / 시간=회색 글자.
                    val dayArr = events.optJSONArray(i.toString())
                    for (k in 0 until 3) {
                        val eId = context.resources.getIdentifier("cal_e${i}_$k", "id", pkg)
                        if (eId == 0) continue
                        val slot = if (dayArr != null && !dayArr.isNull(k))
                            dayArr.optJSONArray(k) else null
                        if (slot != null) {
                            val t = slot.optString(0)
                            val ci = slot.optInt(1).coerceIn(0, barRes.size - 1)
                            val style = slot.optInt(2)
                            setTextViewText(eId, t)
                            setTextViewTextSize(eId, TypedValue.COMPLEX_UNIT_SP, 8f * fs)
                            if (style == 4) {
                                // 시간 일정 — 배경 없이 회색 글자.
                                setInt(eId, "setBackgroundResource", 0)
                                setTextColor(eId, pal.inkSoft)
                            } else {
                                setInt(eId, "setBackgroundResource", barRes[ci][style.coerceIn(0, 3)])
                                setTextColor(eId, 0xFF33291D.toInt())
                            }
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
