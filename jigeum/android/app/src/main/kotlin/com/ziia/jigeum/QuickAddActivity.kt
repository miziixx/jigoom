package com.ziia.jigeum

import android.app.Activity
import android.app.DatePickerDialog
import android.content.Context
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.view.View
import android.view.WindowManager
import android.widget.ArrayAdapter
import android.widget.CheckBox
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.Spinner
import android.widget.TextView
import android.widget.Toast
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

/**
 * 홈에서 뜨는 빠른 담기 팝업(에디토리얼). 앱을 열지 않고 할 일·일정·메모를 바로 담는다.
 *
 * 입력을 SharedPreferences 큐(quick_add_queue)에 쌓고, 앱이 다음에 열리거나
 * 포그라운드로 올 때 큐를 비워 각 종류로 반영한다(할일·메모→노드, 일정→일정).
 */
class QuickAddActivity : Activity() {

    private val calendarIds = ArrayList<String?>()
    private var type = "todo" // todo | schedule | memo

    // 일정 기간(시작~종료). 기본 오늘 하루.
    private val startCal = midnight()
    private val endCal = midnight()

    // 새싹 초록 포인트(선택 밑줄).
    private val sprout = 0xFF4E6659.toInt()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.setLayout(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.WRAP_CONTENT
        )
        setContentView(R.layout.quick_add_activity)

        val pal = WidgetPrefs.palette(this)
        val density = resources.displayMetrics.density

        val card = findViewById<LinearLayout>(R.id.qa_card)
        val eyebrow = findViewById<TextView>(R.id.qa_eyebrow)
        val title = findViewById<TextView>(R.id.qa_title)
        val input = findViewById<EditText>(R.id.qa_input)
        val spinner = findViewById<Spinner>(R.id.qa_spinner)
        val allDay = findViewById<CheckBox>(R.id.qa_all_day)
        val save = findViewById<TextView>(R.id.qa_save)
        val cancel = findViewById<TextView>(R.id.qa_cancel)

        // 카드·버튼을 테마 색으로 틴트(라운드 유지).
        (card.background as? GradientDrawable)?.apply {
            setColor(0xFF000000.toInt() or (pal.paper and 0xFFFFFF))
            setStroke(density.toInt().coerceAtLeast(1),
                0xFF000000.toInt() or (pal.line and 0xFFFFFF))
        }
        (save.background as? GradientDrawable)?.setColor(
            0xFF000000.toInt() or (pal.ink and 0xFFFFFF)
        )
        eyebrow.setTextColor(pal.inkSoft)
        title.setTextColor(pal.ink)
        input.setTextColor(pal.ink)
        input.setHintTextColor(pal.inkSoft)
        allDay.setTextColor(pal.ink)
        save.setTextColor(pal.paper)
        cancel.setTextColor(pal.inkSoft)

        // 종류 탭.
        findViewById<View>(R.id.qa_type_todo).setOnClickListener { selectType("todo", pal) }
        findViewById<View>(R.id.qa_type_schedule).setOnClickListener { selectType("schedule", pal) }
        findViewById<View>(R.id.qa_type_memo).setOnClickListener { selectType("memo", pal) }
        selectType("todo", pal)

        // 기간(시작~종료) 날짜 칩.
        val startChip = findViewById<TextView>(R.id.qa_date_start)
        val endChip = findViewById<TextView>(R.id.qa_date_end)
        val lineColor = 0xFF000000.toInt() or (pal.line and 0xFFFFFF)
        (startChip.background as? GradientDrawable)?.setStroke(
            density.toInt().coerceAtLeast(1), lineColor)
        (endChip.background as? GradientDrawable)?.setStroke(
            density.toInt().coerceAtLeast(1), lineColor)
        startChip.setTextColor(pal.ink)
        endChip.setTextColor(pal.ink)
        fun refreshDates() {
            startChip.text = fmtDate(startCal)
            endChip.text = fmtDate(endCal)
        }
        refreshDates()
        startChip.setOnClickListener {
            pickDate(startCal) {
                // 시작이 종료보다 뒤면 종료를 시작으로 맞춘다.
                if (startCal.timeInMillis > endCal.timeInMillis) {
                    endCal.timeInMillis = startCal.timeInMillis
                }
                refreshDates()
            }
        }
        endChip.setOnClickListener {
            pickDate(endCal) {
                if (endCal.timeInMillis < startCal.timeInMillis) {
                    endCal.timeInMillis = startCal.timeInMillis
                }
                refreshDates()
            }
        }

        // 캘린더(종류) 목록.
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
        spinner.adapter = ArrayAdapter(
            this, android.R.layout.simple_spinner_dropdown_item, names
        )

        input.requestFocus()
        window.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_STATE_VISIBLE)

        save.setOnClickListener {
            val text = input.text.toString().trim()
            if (text.isEmpty()) {
                finish()
                return@setOnClickListener
            }
            val pos = spinner.selectedItemPosition
            val calId = if (pos in calendarIds.indices) calendarIds[pos] else null
            enqueue(text, calId, allDay.isChecked)
            val msg = when (type) {
                "schedule" -> "일정 담았어요 · 앱 열면 반영"
                "memo" -> "메모 담았어요"
                else -> "할 일 담았어요"
            }
            Toast.makeText(this, msg, Toast.LENGTH_SHORT).show()
            finish()
        }
        cancel.setOnClickListener { finish() }
    }

    /** 종류 선택 — 밑줄·색·일정 전용 옵션·힌트를 갱신. */
    private fun selectType(t: String, pal: WidgetPrefs.Palette) {
        type = t
        val rows = listOf(
            Triple(R.id.qa_type_todo_t, R.id.qa_ul_todo, "todo"),
            Triple(R.id.qa_type_schedule_t, R.id.qa_ul_schedule, "schedule"),
            Triple(R.id.qa_type_memo_t, R.id.qa_ul_memo, "memo"),
        )
        for ((textId, ulId, key) in rows) {
            val on = key == t
            findViewById<TextView>(textId).setTextColor(if (on) pal.ink else pal.inkSoft)
            findViewById<View>(ulId)
                .setBackgroundColor(if (on) sprout else 0x00000000)
        }
        findViewById<View>(R.id.qa_schedule_extra).visibility =
            if (t == "schedule") View.VISIBLE else View.GONE
        findViewById<EditText>(R.id.qa_input).hint = when (t) {
            "schedule" -> "일정 제목을 적어요"
            "memo" -> "메모를 적어요"
            else -> "할 일을 적어요"
        }
    }

    /** 입력을 SharedPreferences 큐(JSON 배열)에 append. */
    private fun enqueue(text: String, calendarId: String?, allDay: Boolean) {
        val prefs = getSharedPreferences(WidgetPrefs.FILE, Context.MODE_PRIVATE)
        val arr = try {
            JSONArray(prefs.getString(WidgetPrefs.KEY_QUICK_ADD_QUEUE, "[]"))
        } catch (_: Exception) {
            JSONArray()
        }
        val obj = JSONObject().apply {
            put("type", type)
            put("title", text)
            put("calendarId", calendarId ?: JSONObject.NULL)
            put("allDay", allDay)
            put("at", System.currentTimeMillis())
            // 일정 기간(날짜만, epoch millis). 종료>시작이면 다일 일정.
            put("startDate", startCal.timeInMillis)
            put("endDate", endCal.timeInMillis)
        }
        arr.put(obj)
        prefs.edit()
            .putString(WidgetPrefs.KEY_QUICK_ADD_QUEUE, arr.toString())
            .apply()
    }

    /** 날짜 선택 다이얼로그 — cal 을 갱신하고 onSet 호출. */
    private fun pickDate(cal: Calendar, onSet: () -> Unit) {
        DatePickerDialog(
            this,
            { _, y, m, d ->
                cal.set(y, m, d, 0, 0, 0)
                cal.set(Calendar.MILLISECOND, 0)
                onSet()
            },
            cal.get(Calendar.YEAR),
            cal.get(Calendar.MONTH),
            cal.get(Calendar.DAY_OF_MONTH)
        ).show()
    }

    /** 오늘이면 "오늘", 아니면 "M월 d일". */
    private fun fmtDate(cal: Calendar): String {
        val today = midnight()
        return if (cal.timeInMillis == today.timeInMillis) "오늘"
        else SimpleDateFormat("M월 d일", Locale.KOREA).format(cal.time)
    }

    companion object {
        /** 오늘 자정 Calendar. */
        private fun midnight(): Calendar = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
    }
}
