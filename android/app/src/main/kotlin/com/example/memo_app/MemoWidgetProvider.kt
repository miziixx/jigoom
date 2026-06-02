package com.example.memo_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.view.View
import android.widget.RemoteViews

class MemoWidgetProvider : AppWidgetProvider() {

    companion object {
        const val EXTRA_MODE = "widget_mode"
        const val MODE_NORMAL    = "normal"
        const val MODE_CHECKLIST = "checklist"
        const val MODE_FORMAT    = "format"
        const val MODE_TAG       = "tag"
        const val MODE_REMINDER  = "reminder"
        const val MODE_SIMPLE    = "simple"    // today + 183 days
        const val MODE_DISCOUNT  = "discount"  // today + 120 days
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (id in appWidgetIds) updateWidget(context, appWidgetManager, id)
    }

    private fun updateWidget(context: Context, manager: AppWidgetManager, widgetId: Int) {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)

        // home_widget stores large ARGB ints as Long (values > Int.MAX). Read
        // type-safely so getInt() doesn't throw ClassCastException on a Long.
        val bgColor     = readColor(prefs, "widget_bg",     Color.parseColor("#EDF2ED"))
        val textColor   = readColor(prefs, "widget_text",   Color.parseColor("#556B2F"))
        val dimColor    = readColor(prefs, "widget_dim",    Color.parseColor("#7A8F5A"))
        val borderColor = readColor(prefs, "widget_border", Color.parseColor("#B0C4B0"))
        val isStore     = BuildConfig.FLAVOR == "store"

        val views = RemoteViews(context.packageName, R.layout.memo_widget)

        // Background & colors
        views.setInt(R.id.widget_root,    "setBackgroundColor", bgColor)
        views.setInt(R.id.widget_divider1,"setBackgroundColor", borderColor)
        views.setInt(R.id.widget_divider2,"setBackgroundColor", borderColor)
        views.setTextColor(R.id.widget_title,  textColor)
        views.setTextColor(R.id.widget_hint,   dimColor)
        views.setTextColor(R.id.btn_checklist, dimColor)
        views.setTextColor(R.id.btn_format,    dimColor)
        views.setTextColor(R.id.btn_tag,       dimColor)
        views.setTextColor(R.id.btn_add,       textColor)
        views.setTextColor(R.id.btn_simple,    dimColor)
        views.setTextColor(R.id.btn_discount,  dimColor)

        // Store-only buttons
        views.setViewVisibility(R.id.btn_simple,   if (isStore) View.VISIBLE else View.GONE)
        views.setViewVisibility(R.id.btn_discount, if (isStore) View.VISIBLE else View.GONE)

        // Pending intents for each button
        views.setOnClickPendingIntent(R.id.widget_hint,    makeIntent(context, widgetId, MODE_NORMAL))
        views.setOnClickPendingIntent(R.id.btn_checklist,  makeIntent(context, widgetId, MODE_CHECKLIST))
        views.setOnClickPendingIntent(R.id.btn_format,     makeIntent(context, widgetId, MODE_FORMAT))
        views.setOnClickPendingIntent(R.id.btn_tag,        makeIntent(context, widgetId, MODE_TAG))
        views.setOnClickPendingIntent(R.id.btn_reminder,   makeIntent(context, widgetId, MODE_REMINDER))
        views.setOnClickPendingIntent(R.id.btn_simple,     makeIntent(context, widgetId, MODE_SIMPLE))
        views.setOnClickPendingIntent(R.id.btn_discount,   makeIntent(context, widgetId, MODE_DISCOUNT))
        views.setOnClickPendingIntent(R.id.btn_add,        makeIntent(context, widgetId, MODE_NORMAL))

        manager.updateAppWidget(widgetId, views)
    }

    private fun readColor(
        prefs: android.content.SharedPreferences,
        key: String,
        default: Int
    ): Int {
        return try {
            when (val v = prefs.all[key]) {
                is Int  -> v
                is Long -> v.toInt()
                else    -> default
            }
        } catch (e: Exception) {
            default
        }
    }

    private fun makeIntent(context: Context, widgetId: Int, mode: String): PendingIntent {
        val intent = Intent(context, MemoInputActivity::class.java).apply {
            putExtra(EXTRA_MODE, mode)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val reqCode = widgetId * 100 + mode.hashCode().and(0xFF)
        return PendingIntent.getActivity(
            context, reqCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }
}
