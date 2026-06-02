package com.example.memo_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import org.json.JSONObject

class MemoListWidgetProvider : AppWidgetProvider() {

    companion object {
        fun update(context: Context, manager: AppWidgetManager, widgetId: Int) {
            val c = WidgetDataHelper.widgetColors(context)
            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val type  = prefs.getString("ml_type_$widgetId", "all") ?: "all"
            val value = prefs.getString("ml_value_$widgetId", "") ?: ""

            // Build header label
            val label = when (type) {
                "folder" -> {
                    val folders = WidgetDataHelper.readFolders(context)
                    var name = value
                    for (i in 0 until folders.length()) {
                        val f = folders.getJSONObject(i)
                        if (f.optString("id") == value) { name = f.optString("name", value); break }
                    }
                    "[ /$name ]"
                }
                "tag"    -> "[ #$value ]"
                else     -> "[ inbox ]"
            }

            // Count matching memos
            val memos   = WidgetDataHelper.readMemos(context)
            val folders = WidgetDataHelper.readFolders(context)
            var count   = 0
            for (i in 0 until memos.length()) {
                val memo = memos.getJSONObject(i)
                val match = when (type) {
                    "folder" -> {
                        val ids = WidgetDataHelper.allDescendantIds(folders, value)
                        memo.optString("folderId", "") in ids
                    }
                    "tag" -> {
                        val tagRegex = Regex("#([a-zA-Z가-힣ㄱ-ㅎㅏ-ㅣ][a-zA-Z0-9_가-힣ㄱ-ㅎㅏ-ㅣ]*)")
                        tagRegex.findAll(memo.optString("content", ""))
                            .any { it.groupValues[1] == value }
                    }
                    else -> memo.optString("folderId", "").isEmpty()
                }
                if (match) count++
            }

            val views = RemoteViews(context.packageName, R.layout.widget_memo_list)
            views.setInt(R.id.ml_root, "setBackgroundColor", c.bg)
            views.setInt(R.id.ml_divider, "setBackgroundColor", c.border)
            views.setTextColor(R.id.ml_title, c.text)
            views.setTextColor(R.id.ml_count, c.dim)
            views.setTextViewText(R.id.ml_title, label)
            views.setTextViewText(R.id.ml_count, "$count")

            // Adapter for the ListView
            val serviceIntent = Intent(context, MemoListRemoteViewsService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                // Unique URI needed so Android doesn't cache the wrong factory
                data = android.net.Uri.parse("widget://memo_list/$widgetId")
            }
            views.setRemoteAdapter(R.id.ml_list, serviceIntent)
            // Tap any list item → open main app
            // FLAG_MUTABLE required: system merges FillInIntent extras into template
            val appIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val tapPi = PendingIntent.getActivity(
                context, widgetId + 8000, appIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
            )
            views.setPendingIntentTemplate(R.id.ml_list, tapPi)

            manager.updateAppWidget(widgetId, views)
        }

        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, MemoListWidgetProvider::class.java)
            )
            ids.forEach { id ->
                manager.notifyAppWidgetViewDataChanged(id, R.id.ml_list)
                update(context, manager, id)
            }
        }
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (id in appWidgetIds) update(context, appWidgetManager, id)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: android.os.Bundle,
    ) {
        // Called when widget is resized — re-bind the RemoteAdapter for the new size.
        appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.ml_list)
        update(context, appWidgetManager, appWidgetId)
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE).edit()
        for (id in appWidgetIds) {
            prefs.remove("ml_type_$id").remove("ml_value_$id")
        }
        prefs.apply()
    }
}
