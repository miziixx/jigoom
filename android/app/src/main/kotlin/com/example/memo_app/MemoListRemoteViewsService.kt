package com.example.memo_app

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONObject

class MemoListRemoteViewsService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        MemoListFactory(applicationContext, intent)
}

class MemoListFactory(
    private val context: Context,
    private val intent: Intent,
) : RemoteViewsService.RemoteViewsFactory {

    private val widgetId = intent.getIntExtra(android.appwidget.AppWidgetManager.EXTRA_APPWIDGET_ID, -1)
    private val memoRows = mutableListOf<Pair<String, String>>() // time, content

    override fun onCreate() { reload() }
    override fun onDataSetChanged() { reload() }
    override fun onDestroy() {}

    private fun reload() {
        memoRows.clear()
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val type  = prefs.getString("ml_type_$widgetId", "all") ?: "all"
        val value = prefs.getString("ml_value_$widgetId", "") ?: ""

        val allMemos = WidgetDataHelper.readMemos(context)
        val folders  = WidgetDataHelper.readFolders(context)

        val list = mutableListOf<JSONObject>()
        for (i in 0 until allMemos.length()) {
            val memo = allMemos.getJSONObject(i)
            val include = when (type) {
                "folder" -> {
                    val ids = WidgetDataHelper.allDescendantIds(folders, value)
                    memo.optString("folderId", "") in ids
                }
                "tag" -> {
                    val tagRegex = Regex("#([a-zA-Z가-힣ㄱ-ㅎㅏ-ㅣ][a-zA-Z0-9_가-힣ㄱ-ㅎㅏ-ㅣ]*)")
                    tagRegex.findAll(memo.optString("content", ""))
                        .any { it.groupValues[1] == value }
                }
                else -> true // "all" or inbox (folderId == "")
            }
            if (type == "all" && memo.optString("folderId", "").isNotEmpty()) continue
            if (type != "all" && !include) continue
            list.add(memo)
        }

        // Sort descending by createdAt
        list.sortByDescending { it.optString("createdAt", "") }

        for (memo in list) {
            memoRows.add(
                WidgetDataHelper.memoTimeStr(memo) to WidgetDataHelper.memoFirstLine(memo)
            )
        }
    }

    override fun getCount() = memoRows.size

    override fun getViewAt(position: Int): RemoteViews {
        val c = WidgetDataHelper.widgetColors(context)
        val views = RemoteViews(context.packageName, R.layout.widget_memo_list_item)
        val (time, content) = memoRows.getOrNull(position) ?: ("" to "")
        views.setTextViewText(R.id.ml_item_time, time)
        views.setTextViewText(R.id.ml_item_content, content.ifEmpty { "..." })
        views.setTextColor(R.id.ml_item_time, c.dim)
        views.setTextColor(R.id.ml_item_content, c.text)
        views.setInt(R.id.ml_item_root, "setBackgroundColor", c.bg)
        // FillInIntent for tap → open app
        views.setOnClickFillInIntent(R.id.ml_item_root, Intent())
        return views
    }

    override fun getLoadingView() = null
    override fun getViewTypeCount() = 1
    override fun getItemId(position: Int) = position.toLong()
    override fun hasStableIds() = true
}
