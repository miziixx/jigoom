package com.example.memo_app

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import java.util.Calendar

class CalendarRemoteViewsService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        CalendarFactory(applicationContext, intent)
}

class CalendarFactory(
    private val context: Context,
    private val intent: Intent,
) : RemoteViewsService.RemoteViewsFactory {

    private val widgetId = intent.getIntExtra(android.appwidget.AppWidgetManager.EXTRA_APPWIDGET_ID, -1)

    // Each cell: (dayOfMonth or 0 for blank, hasMemo)
    private val cells = mutableListOf<Triple<Int, Boolean, Long>>() // day, hasMemo, epochMs (for intent)

    override fun onCreate() { reload() }
    override fun onDataSetChanged() { reload() }
    override fun onDestroy() {}

    private fun reload() {
        cells.clear()
        val prefs  = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val now    = Calendar.getInstance()
        val year   = prefs.getInt("cal_year_$widgetId", now.get(Calendar.YEAR))
        val month  = prefs.getInt("cal_month_$widgetId", now.get(Calendar.MONTH)) // 0-based

        // Build set of day-numbers that have memos
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
        // Sunday = 1 in Calendar; shift so grid starts on Sunday
        val firstDow = cal.get(Calendar.DAY_OF_WEEK) - 1 // 0-based, 0=Sun
        val daysInMonth = cal.getActualMaximum(Calendar.DAY_OF_MONTH)

        // Blanks before first day
        repeat(firstDow) { cells.add(Triple(0, false, 0L)) }

        for (day in 1..daysInMonth) {
            val epoch = Calendar.getInstance().apply {
                set(year, month, day, 0, 0, 0); set(Calendar.MILLISECOND, 0)
            }.timeInMillis
            cells.add(Triple(day, day in memoDay, epoch))
        }

        // Pad to multiple of 7
        while (cells.size % 7 != 0) cells.add(Triple(0, false, 0L))
    }

    override fun getCount() = cells.size

    override fun getViewAt(position: Int): RemoteViews {
        val c = WidgetDataHelper.widgetColors(context)
        val views = RemoteViews(context.packageName, R.layout.widget_calendar_cell)
        val (day, hasMemo, epochMs) = cells.getOrNull(position) ?: Triple(0, false, 0L)

        if (day == 0) {
            views.setTextViewText(R.id.cal_cell_day, "")
            views.setViewVisibility(R.id.cal_cell_dot, View.GONE)
            views.setInt(R.id.cal_cell_root, "setBackgroundColor", c.bg)
            views.setOnClickFillInIntent(R.id.cal_cell_root, Intent())
        } else {
            views.setTextViewText(R.id.cal_cell_day, day.toString())
            views.setTextColor(R.id.cal_cell_day, if (hasMemo) c.text else c.dim)
            views.setInt(R.id.cal_cell_dot, "setBackgroundColor", c.text)
            views.setViewVisibility(R.id.cal_cell_dot, if (hasMemo) View.VISIBLE else View.GONE)
            views.setInt(R.id.cal_cell_root, "setBackgroundColor", c.bg)

            // Fill-in intent carries year/month/day so provider can open MemoInputActivity
            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val displayYear  = prefs.getInt("cal_year_$widgetId",  Calendar.getInstance().get(Calendar.YEAR))
            val displayMonth = prefs.getInt("cal_month_$widgetId", Calendar.getInstance().get(Calendar.MONTH))

            val fill = Intent().apply {
                putExtra(MemoInputActivity.EXTRA_DATE_YEAR,  displayYear)
                putExtra(MemoInputActivity.EXTRA_DATE_MONTH, displayMonth + 1) // 1-based
                putExtra(MemoInputActivity.EXTRA_DATE_DAY,   day)
            }
            views.setOnClickFillInIntent(R.id.cal_cell_root, fill)
        }
        return views
    }

    override fun getLoadingView() = null
    override fun getViewTypeCount() = 1
    override fun getItemId(position: Int) = position.toLong()
    override fun hasStableIds() = true
}
