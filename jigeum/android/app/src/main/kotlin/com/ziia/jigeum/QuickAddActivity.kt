package com.ziia.jigeum

import android.app.Activity
import android.content.Context
import android.os.Bundle
import android.view.WindowManager
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.CheckBox
import android.widget.EditText
import android.widget.Spinner
import android.widget.Toast
import org.json.JSONArray
import org.json.JSONObject

/**
 * 1×1 위젯에서 뜨는 반투명 빠른 추가 팝업.
 *
 * 제목 + 캘린더(종류) + 종일 여부를 입력받아 SharedPreferences 큐에 쌓는다.
 * 앱이 다음에 열리거나 포그라운드로 올 때 큐를 비워 구글 캘린더로 동기화한다.
 * (앱을 열지 않고 입력만 하는 흐름이므로 여기서 네트워크는 건드리지 않는다.)
 */
class QuickAddActivity : Activity() {

    // 스피너 인덱스 → 캘린더 id (null=기본 캘린더).
    private val calendarIds = ArrayList<String?>()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // 팝업이 홈 위에 뜨는 느낌 — 살짝 어둡게.
        window.setLayout(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.WRAP_CONTENT
        )
        setContentView(R.layout.quick_add_activity)

        val pal = WidgetPrefs.palette(this)
        val input = findViewById<EditText>(R.id.qa_input)
        val spinner = findViewById<Spinner>(R.id.qa_spinner)
        val allDay = findViewById<CheckBox>(R.id.qa_all_day)
        val save = findViewById<Button>(R.id.qa_save)
        val cancel = findViewById<Button>(R.id.qa_cancel)

        // 테마 톤 적용.
        findViewById<android.view.View>(R.id.qa_card)
            .setBackgroundColor(0xFF000000.toInt() or (pal.paper and 0xFFFFFF))
        input.setTextColor(pal.ink)
        input.setHintTextColor(pal.inkSoft)
        allDay.setTextColor(pal.ink)
        save.setTextColor(pal.paper)
        save.setBackgroundColor(0xFF000000.toInt() or (pal.ink and 0xFFFFFF))
        cancel.setTextColor(pal.inkSoft)

        // 캘린더(종류) 목록 채우기.
        val names = ArrayList<String>()
        val raw = getSharedPreferences(WidgetPrefs.FILE, Context.MODE_PRIVATE)
            .getString(WidgetPrefs.KEY_GCAL_CALENDARS, "[]") ?: "[]"
        try {
            val arr = JSONArray(raw)
            for (i in 0 until arr.length()) {
                val o = arr.getJSONObject(i)
                names.add(o.optString("name", "캘린더"))
                calendarIds.add(o.optString("id", null))
            }
        } catch (_: Exception) {
        }
        if (names.isEmpty()) {
            names.add("기본 캘린더")
            calendarIds.add(null)
        }
        val adapter = ArrayAdapter(
            this, android.R.layout.simple_spinner_dropdown_item, names
        )
        spinner.adapter = adapter

        input.requestFocus()
        window.setSoftInputMode(
            WindowManager.LayoutParams.SOFT_INPUT_STATE_VISIBLE
        )

        save.setOnClickListener {
            val title = input.text.toString().trim()
            if (title.isEmpty()) {
                finish()
                return@setOnClickListener
            }
            val pos = spinner.selectedItemPosition
            val calId = if (pos in calendarIds.indices) calendarIds[pos] else null
            enqueue(title, calId, allDay.isChecked)
            Toast.makeText(this, "지금에 담았어요 · 앱 열면 동기화", Toast.LENGTH_SHORT)
                .show()
            finish()
        }
        cancel.setOnClickListener { finish() }
    }

    /** 입력을 SharedPreferences 큐(JSON 배열)에 append. */
    private fun enqueue(title: String, calendarId: String?, allDay: Boolean) {
        val prefs = getSharedPreferences(WidgetPrefs.FILE, Context.MODE_PRIVATE)
        val arr = try {
            JSONArray(prefs.getString(WidgetPrefs.KEY_QUICK_ADD_QUEUE, "[]"))
        } catch (_: Exception) {
            JSONArray()
        }
        val obj = JSONObject().apply {
            put("title", title)
            put("calendarId", calendarId ?: JSONObject.NULL)
            put("allDay", allDay)
            put("at", System.currentTimeMillis())
        }
        arr.put(obj)
        prefs.edit()
            .putString(WidgetPrefs.KEY_QUICK_ADD_QUEUE, arr.toString())
            .apply()
    }
}
