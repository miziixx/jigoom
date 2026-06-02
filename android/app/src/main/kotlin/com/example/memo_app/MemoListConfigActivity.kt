package com.example.memo_app

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Bundle
import android.view.View
import android.view.ViewGroup
import android.widget.ArrayAdapter
import android.widget.ListView
import android.widget.TextView
import org.json.JSONArray

class MemoListConfigActivity : Activity() {

    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID
    private var selectedIndex = 0

    data class ConfigItem(val label: String, val type: String, val value: String)

    private val items = mutableListOf<ConfigItem>()

    private val prefs by lazy {
        getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
    }
    private val c by lazy { WidgetDataHelper.widgetColors(this) }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Read widget ID from intent
        appWidgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID

        // Cancelled result by default
        setResult(RESULT_CANCELED, Intent().apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        })

        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) { finish(); return }

        setContentView(R.layout.activity_memo_list_config)
        applyColors()
        buildItems()
        setupList()
    }

    private fun applyColors() {
        findViewById<View>(R.id.config_root).setBackgroundColor(c.bg)
        window.statusBarColor = c.bg
        for (id in listOf(R.id.config_title, R.id.config_btn_ok)) {
            (findViewById<TextView>(id))?.setTextColor(c.text)
        }
        for (id in listOf(R.id.config_label, R.id.config_btn_cancel)) {
            (findViewById<TextView>(id))?.setTextColor(c.dim)
        }
        for (id in listOf(R.id.config_div1, R.id.config_div2)) {
            (findViewById<View>(id))?.setBackgroundColor(c.border)
        }
    }

    private fun buildItems() {
        items.clear()
        items.add(ConfigItem("[ inbox ] (전체)", "all", ""))

        val folders = WidgetDataHelper.readFolders(this)
        for (i in 0 until folders.length()) {
            val f = folders.getJSONObject(i)
            val id   = f.optString("id", "")
            val name = f.optString("name", "")
            if (id.isNotEmpty()) items.add(ConfigItem("  /$name", "folder", id))
        }

        val memos = WidgetDataHelper.readMemos(this)
        val tags = mutableSetOf<String>()
        val tagRegex = Regex("#([a-zA-Z가-힣ㄱ-ㅎㅏ-ㅣ][a-zA-Z0-9_가-힣ㄱ-ㅎㅏ-ㅣ]*)")
        for (i in 0 until memos.length()) {
            val content = memos.getJSONObject(i).optString("content", "")
            tagRegex.findAll(content).forEach { tags.add(it.groupValues[1]) }
        }
        tags.sorted().forEach { tag ->
            items.add(ConfigItem("  #$tag", "tag", tag))
        }
    }

    private fun setupList() {
        val listView = findViewById<ListView>(R.id.config_list)

        val adapter = object : ArrayAdapter<ConfigItem>(this, 0, items) {
            override fun getView(position: Int, convertView: View?, parent: ViewGroup): View {
                val tv = convertView as? TextView ?: TextView(context).apply {
                    setPadding(12, 16, 12, 16)
                    typeface = android.graphics.Typeface.MONOSPACE
                    textSize = 11f
                }
                val item = items[position]
                tv.text = item.label
                tv.setTextColor(if (position == selectedIndex) c.text else c.dim)
                tv.setBackgroundColor(
                    if (position == selectedIndex)
                        Color.argb(30, Color.red(c.text), Color.green(c.text), Color.blue(c.text))
                    else c.bg
                )
                return tv
            }
        }
        listView.adapter = adapter
        listView.setBackgroundColor(c.bg)

        listView.setOnItemClickListener { _, _, position, _ ->
            selectedIndex = position
            adapter.notifyDataSetChanged()
        }

        findViewById<TextView>(R.id.config_btn_cancel).setOnClickListener { finish() }

        findViewById<TextView>(R.id.config_btn_ok).setOnClickListener {
            val item = items[selectedIndex]
            prefs.edit()
                .putString("ml_type_$appWidgetId", item.type)
                .putString("ml_value_$appWidgetId", item.value)
                .apply()

            try {
                val manager = AppWidgetManager.getInstance(this)
                MemoListWidgetProvider.update(this, manager, appWidgetId)
                android.util.Log.d("WIDGET_DEBUG", "updateAppWidget succeeded id=$appWidgetId type=${item.type}")
            } catch (e: Exception) {
                android.util.Log.e("WIDGET_DEBUG", "updateAppWidget FAILED id=$appWidgetId", e)
                // Still return OK — launcher will call onUpdate which retries
            }

            setResult(RESULT_OK, Intent().apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            })
            finish()
        }
    }
}
