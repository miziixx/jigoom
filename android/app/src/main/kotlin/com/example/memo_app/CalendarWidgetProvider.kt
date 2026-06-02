package com.example.memo_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import java.util.Calendar

class CalendarWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_PREV = "com.example.memo_app.CAL_PREV"
        const val ACTION_NEXT = "com.example.memo_app.CAL_NEXT"
        const val EXTRA_WIDGET_ID = "cal_widget_id"

        // Static 6x7 grid view ids (replaces the old GridView/RemoteViewsService;
        // weighted cells fill the widget area at any size).
        private val CELL_IDS = intArrayOf(R.id.cal_cell_0, R.id.cal_cell_1, R.id.cal_cell_2, R.id.cal_cell_3, R.id.cal_cell_4, R.id.cal_cell_5, R.id.cal_cell_6, R.id.cal_cell_7, R.id.cal_cell_8, R.id.cal_cell_9, R.id.cal_cell_10, R.id.cal_cell_11, R.id.cal_cell_12, R.id.cal_cell_13, R.id.cal_cell_14, R.id.cal_cell_15, R.id.cal_cell_16, R.id.cal_cell_17, R.id.cal_cell_18, R.id.cal_cell_19, R.id.cal_cell_20, R.id.cal_cell_21, R.id.cal_cell_22, R.id.cal_cell_23, R.id.cal_cell_24, R.id.cal_cell_25, R.id.cal_cell_26, R.id.cal_cell_27, R.id.cal_cell_28, R.id.cal_cell_29, R.id.cal_cell_30, R.id.cal_cell_31, R.id.cal_cell_32, R.id.cal_cell_33, R.id.cal_cell_34, R.id.cal_cell_35, R.id.cal_cell_36, R.id.cal_cell_37, R.id.cal_cell_38, R.id.cal_cell_39, R.id.cal_cell_40, R.id.cal_cell_41)
        private val DAY_IDS  = intArrayOf(R.id.cal_day_0, R.id.cal_day_1, R.id.cal_day_2, R.id.cal_day_3, R.id.cal_day_4, R.id.cal_day_5, R.id.cal_day_6, R.id.cal_day_7, R.id.cal_day_8, R.id.cal_day_9, R.id.cal_day_10, R.id.cal_day_11, R.id.cal_day_12, R.id.cal_day_13, R.id.cal_day_14, R.id.cal_day_15, R.id.cal_day_16, R.id.cal_day_17, R.id.cal_day_18, R.id.cal_day_19, R.id.cal_day_20, R.id.cal_day_21, R.id.cal_day_22, R.id.cal_day_23, R.id.cal_day_24, R.id.cal_day_25, R.id.cal_day_26, R.id.cal_day_27, R.id.cal_day_28, R.id.cal_day_29, R.id.cal_day_30, R.id.cal_day_31, R.id.cal_day_32, R.id.cal_day_33, R.id.cal_day_34, R.id.cal_day_35, R.id.cal_day_36, R.id.cal_day_37, R.id.cal_day_38, R.id.cal_day_39, R.id.cal_day_40, R.id.cal_day_41)
        private val DOT_IDS  = intArrayOf(R.id.cal_dot_0, R.id.cal_dot_1, R.id.cal_dot_2, R.id.cal_dot_3, R.id.cal_dot_4, R.id.cal_dot_5, R.id.cal_dot_6, R.id.cal_dot_7, R.id.cal_dot_8, R.id.cal_dot_9, R.id.cal_dot_10, R.id.cal_dot_11, R.id.cal_dot_12, R.id.cal_dot_13, R.id.cal_dot_14, R.id.cal_dot_15, R.id.cal_dot_16, R.id.cal_dot_17, R.id.cal_dot_18, R.id.cal_dot_19, R.id.cal_dot_20, R.id.cal_dot_21, R.id.cal_dot_22, R.id.cal_dot_23, R.id.cal_dot_24, R.id.cal_dot_25, R.id.cal_dot_26, R.id.cal_dot_27, R.id.cal_dot_28, R.id.cal_dot_29, R.id.cal_dot_30, R.id.cal_dot_31, R.id.cal_dot_32, R.id.cal_dot_33, R.id.cal_dot_34, R.id.cal_dot_35, R.id.cal_dot_36, R.id.cal_dot_37, R.id.cal_dot_38, R.id.cal_dot_39, R.id.cal_dot_40, R.id.cal_dot_41)
        private val WEEK_IDS = intArrayOf(R.id.cal_week_0, R.id.cal_week_1, R.id.cal_week_2, R.id.cal_week_3, R.id.cal_week_4, R.id.cal_week_5)
        private val DOW_IDS  = intArrayOf(R.id.cal_dow_0, R.id.cal_dow_1, R.id.cal_dow_2, R.id.cal_dow_3, R.id.cal_dow_4, R.id.cal_dow_5, R.id.cal_dow_6)
        private val SUN_COLOR = android.graphics.Color.parseColor("#FF1744") // Red A400 — vivid, distinct on any theme

        fun update(context: Context, manager: AppWidgetManager, widgetId: Int) {
            val c = WidgetDataHelper.widgetColors(context)
            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val now = Calendar.getInstance()
            val year  = prefs.getInt("cal_year_$widgetId",  now.get(Calendar.YEAR))
            val month = prefs.getInt("cal_month_$widgetId", now.get(Calendar.MONTH))

            val monthLabel = "%04d.%02d".format(year, month + 1)

            val views = RemoteViews(context.packageName, R.layout.widget_calendar)
            views.setInt(R.id.cal_root, "setBackgroundColor", c.bg)
            views.setInt(R.id.cal_divider, "setBackgroundColor", c.border)
            views.setTextColor(R.id.cal_month_label, c.text)
            views.setTextViewText(R.id.cal_month_label, monthLabel)
            views.setTextColor(R.id.cal_prev, c.dim)
            views.setTextColor(R.id.cal_next, c.dim)

            // DOW header colors: Mon–Fri=dim, Sat=teal, Sun=red
            for (i in 0 until 7) {
                views.setTextColor(DOW_IDS[i], when (i) {
                    5 -> c.teal
                    6 -> SUN_COLOR
                    else -> c.dim
                })
            }

            // Prev / Next month intents
            views.setOnClickPendingIntent(R.id.cal_prev, navIntent(context, widgetId, ACTION_PREV))
            views.setOnClickPendingIntent(R.id.cal_next, navIntent(context, widgetId, ACTION_NEXT))

            // Build the month grid and paint each of the 42 cells directly.
            renderGrid(context, views, widgetId, year, month, c)

            manager.updateAppWidget(widgetId, views)
        }

        /** Populate the static 6x7 grid. Hides trailing empty week-rows so used rows fill height. */
        private fun renderGrid(
            context: Context,
            views: RemoteViews,
            widgetId: Int,
            year: Int,
            month: Int,
            c: WidgetDataHelper.WidgetColors,
        ) {
            // Days that have memos in this month
            val memos = WidgetDataHelper.readMemos(context)
            val memoDay = mutableSetOf<Int>()
            for (i in 0 until memos.length()) {
                val dateKey = WidgetDataHelper.memoDateKey(memos.getJSONObject(i))
                if (dateKey.length == 10) {
                    val y = dateKey.substring(0, 4).toIntOrNull() ?: continue
                    val m = (dateKey.substring(5, 7).toIntOrNull() ?: continue) - 1
                    val d = dateKey.substring(8, 10).toIntOrNull() ?: continue
                    if (y == year && m == month) memoDay.add(d)
                }
            }

            val cal = Calendar.getInstance().apply { set(year, month, 1) }
            // Convert to Monday-first offset (matches Flutter calendar: Mon=0, Sun=6)
            val rawFirstDow = cal.get(Calendar.DAY_OF_WEEK) - 1 // 0=Sun..6=Sat
            val firstDow = (rawFirstDow + 6) % 7               // 0=Mon..6=Sun
            val daysInMonth = cal.getActualMaximum(Calendar.DAY_OF_MONTH)

            val nowCal = Calendar.getInstance()
            val todayYear  = nowCal.get(Calendar.YEAR)
            val todayMonth = nowCal.get(Calendar.MONTH)
            val todayDay   = nowCal.get(Calendar.DAY_OF_MONTH)

            // weeks actually needed (4..6)
            val usedCells = firstDow + daysInMonth
            val usedWeeks = (usedCells + 6) / 7

            for (idx in 0 until 42) {
                val day = idx - firstDow + 1
                val inMonth = day in 1..daysInMonth
                if (inMonth) {
                    val hasMemo = day in memoDay
                    val isToday = year == todayYear && month == todayMonth && day == todayDay
                    val col = idx % 7  // 0=Mon..5=Sat..6=Sun
                    val dayColor = when {
                        col == 6 -> SUN_COLOR          // Sunday: red
                        col == 5 -> c.teal             // Saturday: teal
                        isToday  -> c.text             // Today: text (bold)
                        hasMemo  -> c.text             // Has memo: text
                        else     -> c.dim              // Normal: dim
                    }
                    views.setTextViewText(DAY_IDS[idx], day.toString())
                    views.setTextColor(DAY_IDS[idx], dayColor)
                    views.setTextViewTextSize(DAY_IDS[idx], TypedValue.COMPLEX_UNIT_SP, if (isToday) 15f else 14f)
                    views.setInt(DOT_IDS[idx], "setBackgroundColor", c.mint)
                    views.setViewVisibility(DOT_IDS[idx], if (hasMemo) View.VISIBLE else View.GONE)
                    views.setInt(CELL_IDS[idx], "setBackgroundColor", c.bg)
                    views.setOnClickPendingIntent(CELL_IDS[idx], dayIntent(context, widgetId, year, month, day))
                } else {
                    views.setTextViewText(DAY_IDS[idx], "")
                    views.setViewVisibility(DOT_IDS[idx], View.GONE)
                    views.setInt(CELL_IDS[idx], "setBackgroundColor", c.bg)
                    views.setOnClickPendingIntent(CELL_IDS[idx], null)
                }
            }

            // Show only the week-rows we need so they expand to fill the height.
            for (w in 0 until 6) {
                views.setViewVisibility(WEEK_IDS[w], if (w < usedWeeks) View.VISIBLE else View.GONE)
            }
        }

        /** PendingIntent that opens MemoInputActivity for a specific day. */
        private fun dayIntent(context: Context, widgetId: Int, year: Int, month: Int, day: Int): PendingIntent {
            val intent = Intent(context, MemoInputActivity::class.java).apply {
                putExtra(MemoWidgetProvider.EXTRA_MODE, MemoWidgetProvider.MODE_NORMAL)
                putExtra(MemoInputActivity.EXTRA_DATE_YEAR,  year)
                putExtra(MemoInputActivity.EXTRA_DATE_MONTH, month + 1) // 1-based
                putExtra(MemoInputActivity.EXTRA_DATE_DAY,   day)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            // Unique request code per widget+day
            val reqCode = widgetId * 100 + day + 10000
            return PendingIntent.getActivity(
                context, reqCode, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, CalendarWidgetProvider::class.java)
            )
            ids.forEach { id -> update(context, manager, id) }
        }

        private fun navIntent(context: Context, widgetId: Int, action: String): PendingIntent {
            val intent = Intent(context, CalendarWidgetProvider::class.java).apply {
                this.action = action
                putExtra(EXTRA_WIDGET_ID, widgetId)
            }
            val reqCode = widgetId * 200 + if (action == ACTION_PREV) 1 else 2
            return PendingIntent.getBroadcast(
                context, reqCode, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (id in appWidgetIds) {
            // Init month to current if not set
            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val now = Calendar.getInstance()
            if (!prefs.contains("cal_year_$id")) {
                prefs.edit()
                    .putInt("cal_year_$id",  now.get(Calendar.YEAR))
                    .putInt("cal_month_$id", now.get(Calendar.MONTH))
                    .apply()
            }
            update(context, appWidgetManager, id)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val widgetId = intent.getIntExtra(EXTRA_WIDGET_ID, -1)
        if (widgetId == -1) return

        when (intent.action) {
            ACTION_PREV, ACTION_NEXT -> {
                val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
                val now   = Calendar.getInstance()
                var year  = prefs.getInt("cal_year_$widgetId",  now.get(Calendar.YEAR))
                var month = prefs.getInt("cal_month_$widgetId", now.get(Calendar.MONTH))

                if (intent.action == ACTION_PREV) {
                    month--; if (month < 0) { month = 11; year-- }
                } else {
                    month++; if (month > 11) { month = 0; year++ }
                }

                prefs.edit()
                    .putInt("cal_year_$widgetId",  year)
                    .putInt("cal_month_$widgetId", month)
                    .apply()

                val manager = AppWidgetManager.getInstance(context)
                update(context, manager, widgetId)
            }
        }
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE).edit()
        for (id in appWidgetIds) {
            prefs.remove("cal_year_$id").remove("cal_month_$id")
        }
        prefs.apply()
    }
}
