package com.example.memo_app

import android.app.Activity
import android.app.Dialog
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.text.Editable
import android.text.TextWatcher
import android.view.View
import android.view.Window
import android.view.WindowManager
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsControllerCompat
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

class MemoInputActivity : Activity() {

    companion object {
        const val EXTRA_DATE_YEAR  = "memo_date_year"
        const val EXTRA_DATE_MONTH = "memo_date_month"
        const val EXTRA_DATE_DAY   = "memo_date_day"
    }

    private var reminderMillis: Long? = null
    private var targetDate: Triple<Int, Int, Int>? = null
    private var selectedFolderId: String? = null
    private data class FolderItem(val id: String, val name: String)

    private val prefs by lazy {
        getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
    }

    private fun isLogroomFlavor(): Boolean =
        BuildConfig.FLAVOR == "logroomtemp"

    // v3 defaults used when widget_bg hasn't been synced yet (first launch)
    private val defaultBg   get() = if (isLogroomFlavor()) Color.parseColor("#0C0B09") else Color.parseColor("#EDF2ED")
    private val defaultText get() = if (isLogroomFlavor()) Color.parseColor("#EDE8DF") else Color.parseColor("#556B2F")
    private val defaultDim  get() = if (isLogroomFlavor()) Color.parseColor("#5A5445") else Color.parseColor("#7A8F5A")

    private val bgColor     get() = readColor("widget_bg",     defaultBg)
    private val textColor   get() = readColor("widget_text",   defaultText)
    private val dimColor    get() = readColor("widget_dim",    defaultDim)
    private val borderColor get() = readColor("widget_border", Color.parseColor("#B0C4B0"))
    private val tealColor   get() = readColor("widget_teal",   Color.parseColor("#527A22"))
    private val mintColor   get() = readColor("widget_mint",   Color.parseColor("#556B2F"))

    private fun readColor(key: String, default: Int): Int {
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

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        window.setBackgroundDrawableResource(android.R.color.transparent)
        setFinishOnTouchOutside(true)
        setContentView(R.layout.activity_memo_input)

        val year  = intent?.getIntExtra(EXTRA_DATE_YEAR, -1) ?: -1
        val month = intent?.getIntExtra(EXTRA_DATE_MONTH, -1) ?: -1
        val day   = intent?.getIntExtra(EXTRA_DATE_DAY, -1) ?: -1
        if (year > 0 && month > 0 && day > 0) {
            targetDate = Triple(year, month, day)
        }

        applyColors()
        setupButtons()
        updateFolderBtn()
        applyInitialMode()

        // 캘린더 위젯에서 진입 시 날짜 레이블 표시 (Flutter TODAY 스타일)
        targetDate?.let { (y, m, d) ->
            val title = findViewById<TextView>(R.id.input_title)
            title.text = "[ %04d.%02d.%02d ]".format(y, m, d)
            title.visibility = View.VISIBLE
        }

        window.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_STATE_VISIBLE)
        findViewById<EditText>(R.id.input_text).requestFocus()
    }

    private fun isLightColor(color: Int): Boolean {
        val r = Color.red(color) / 255.0
        val g = Color.green(color) / 255.0
        val b = Color.blue(color) / 255.0
        return (0.2126 * r + 0.7152 * g + 0.0722 * b) > 0.5
    }

    private fun loadFolders(): List<FolderItem> {
        return try {
            val raw = prefs.getString("widget_folders", "[]") ?: "[]"
            val arr = org.json.JSONArray(raw)
            (0 until arr.length()).map { i ->
                val obj = arr.getJSONObject(i)
                FolderItem(obj.getString("id"), obj.getString("name"))
            }
        } catch (_: Exception) { emptyList() }
    }

    private fun updateFolderBtn() {
        val btn = findViewById<TextView>(R.id.input_btn_folder)
        val label = if (selectedFolderId == null) "[[ ▾ ]]"
                    else "[[ ${loadFolders().find { it.id == selectedFolderId }?.name ?: "?"} ▾ ]]"
        btn.text = label
        btn.setTextColor(if (selectedFolderId != null) textColor else dimColor)
    }

    private fun applyColors() {
        val root      = findViewById<LinearLayout>(R.id.input_root)
        val title     = findViewById<TextView>(R.id.input_title)
        val inputText = findViewById<EditText>(R.id.input_text)

        root.setBackgroundColor(bgColor)
        title.setTextColor(textColor)
        inputText.setTextColor(textColor)
        inputText.setHintTextColor(dimColor)
        inputText.setBackgroundColor(Color.TRANSPARENT)

        window.addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS)
        window.clearFlags(WindowManager.LayoutParams.FLAG_TRANSLUCENT_STATUS)
        window.statusBarColor = bgColor
        WindowInsetsControllerCompat(window, window.decorView)
            .isAppearanceLightStatusBars = isLightColor(bgColor)

        listOf(
            R.id.input_btn_checklist,
            R.id.input_btn_format,
            R.id.input_btn_tag,
            R.id.reminder_clear_btn,
            R.id.input_btn_folder,
        ).forEach { id -> findViewById<TextView>(id)?.setTextColor(dimColor) }

        findViewById<TextView>(R.id.input_btn_reminder)?.setTextColor(dimColor)
        findViewById<TextView>(R.id.input_btn_add).setTextColor(textColor)
        findViewById<TextView>(R.id.mode_reminder_indicator).setTextColor(textColor)

        val isStore = isStoreFlavor()
        val vis = if (isStore) View.VISIBLE else View.GONE
        findViewById<TextView>(R.id.input_btn_simple).visibility   = vis
        findViewById<TextView>(R.id.input_btn_discount).visibility = vis
        if (isStore) {
            findViewById<TextView>(R.id.input_btn_simple).setTextColor(dimColor)
            findViewById<TextView>(R.id.input_btn_discount).setTextColor(dimColor)
        }
    }

    private fun isStoreFlavor(): Boolean =
        BuildConfig.FLAVOR == "store" || BuildConfig.FLAVOR == "nemo2store"

    private fun showFolderPicker() {
        val folders = loadFolders()
        val items = mutableListOf("inbox") + folders.map { it.name }
        android.app.AlertDialog.Builder(this)
            .setTitle("[ 폴더 선택 ]")
            .setItems(items.toTypedArray()) { _, which ->
                selectedFolderId = if (which == 0) null else folders[which - 1].id
                updateFolderBtn()
            }
            .show()
    }

    private fun setupButtons() {
        val inputText = findViewById<EditText>(R.id.input_text)

        findViewById<TextView>(R.id.input_btn_folder).setOnClickListener {
            showFolderPicker()
        }

        findViewById<TextView>(R.id.input_btn_checklist).setOnClickListener {
            insertAt(inputText, "- [ ] ")
        }
        findViewById<TextView>(R.id.input_btn_format).setOnClickListener {
            insertAt(inputText, "• ")
        }
        findViewById<TextView>(R.id.input_btn_tag).setOnClickListener {
            insertAt(inputText, "#")
        }
        findViewById<TextView>(R.id.input_btn_reminder).setOnClickListener {
            showReminderPicker()
        }
        findViewById<TextView>(R.id.reminder_clear_btn).setOnClickListener {
            reminderMillis = null
            val modeRow = findViewById<LinearLayout>(R.id.mode_row)
            modeRow.visibility = View.GONE
        }
        findViewById<TextView>(R.id.input_btn_simple).setOnClickListener {
            setQuickReminder(183, "심플코스")
        }
        findViewById<TextView>(R.id.input_btn_discount).setOnClickListener {
            setQuickReminder(120, "요금할인")
        }
        findViewById<TextView>(R.id.input_btn_add).setOnClickListener {
            saveMemo()
        }
    }

    private fun applyInitialMode() {
        when (intent.getStringExtra(MemoWidgetProvider.EXTRA_MODE)) {
            MemoWidgetProvider.MODE_CHECKLIST -> insertAt(findViewById(R.id.input_text), "- [ ] ")
            MemoWidgetProvider.MODE_FORMAT    -> insertAt(findViewById(R.id.input_text), "• ")
            MemoWidgetProvider.MODE_TAG       -> insertAt(findViewById(R.id.input_text), "#")
            MemoWidgetProvider.MODE_REMINDER  -> showReminderPicker()
            MemoWidgetProvider.MODE_SIMPLE    -> setQuickReminder(183, "심플코스")
            MemoWidgetProvider.MODE_DISCOUNT  -> setQuickReminder(120, "요금할인")
        }
    }

    private fun insertAt(et: EditText, text: String) {
        val start = et.selectionStart.coerceAtLeast(0)
        val end   = et.selectionEnd.coerceAtLeast(start)
        et.text.replace(start, end, text)
        et.setSelection(start + text.length)
        et.requestFocus()
    }

    private fun showReminderPicker() {
        val cal = Calendar.getInstance().apply { add(Calendar.HOUR_OF_DAY, 1) }
        val density = resources.displayMetrics.density

        val view = layoutInflater.inflate(R.layout.dialog_reminder, null)

        val root      = view.findViewById<LinearLayout>(R.id.reminder_root)
        val title     = view.findViewById<TextView>(R.id.reminder_title)
        val div1      = view.findViewById<View>(R.id.reminder_div1)
        val div2      = view.findViewById<View>(R.id.reminder_div2)
        val yearEt    = view.findViewById<EditText>(R.id.reminder_year)
        val monthEt   = view.findViewById<EditText>(R.id.reminder_month)
        val dayEt     = view.findViewById<EditText>(R.id.reminder_day)
        val hourEt    = view.findViewById<EditText>(R.id.reminder_hour)
        val minEt     = view.findViewById<EditText>(R.id.reminder_min)
        val errorTv   = view.findViewById<TextView>(R.id.reminder_error)
        val cancelBtn = view.findViewById<TextView>(R.id.reminder_btn_cancel)
        val setBtn    = view.findViewById<TextView>(R.id.reminder_btn_set)

        val dimLabels = listOf(
            view.findViewById<TextView>(R.id.reminder_date_label),
            view.findViewById<TextView>(R.id.reminder_time_label),
            view.findViewById<TextView>(R.id.reminder_sep1),
            view.findViewById<TextView>(R.id.reminder_sep2),
            view.findViewById<TextView>(R.id.reminder_sep3),
        )

        root.setBackgroundColor(bgColor)
        title.setTextColor(textColor)
        div1.setBackgroundColor(borderColor)
        div2.setBackgroundColor(borderColor)
        dimLabels.forEach { it?.setTextColor(dimColor) }
        cancelBtn.setTextColor(dimColor)
        setBtn.setTextColor(textColor)

        val pad = (4 * density).toInt()
        for (et in listOf(yearEt, monthEt, dayEt, hourEt, minEt)) {
            et.setTextColor(textColor)
            et.setHintTextColor(dimColor)
            et.background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                setStroke((1 * density).toInt(), borderColor)
                setColor(bgColor)
            }
            et.setPadding(pad, pad, pad, pad)
        }

        yearEt.setText("%04d".format(cal.get(Calendar.YEAR)))
        monthEt.setText("%02d".format(cal.get(Calendar.MONTH) + 1))
        dayEt.setText("%02d".format(cal.get(Calendar.DAY_OF_MONTH)))
        hourEt.setText("%02d".format(cal.get(Calendar.HOUR_OF_DAY)))
        minEt.setText("%02d".format(cal.get(Calendar.MINUTE)))

        fun autoAdvance(et: EditText, maxLen: Int, next: EditText?) {
            et.addTextChangedListener(object : TextWatcher {
                override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
                override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
                override fun afterTextChanged(s: Editable?) {
                    if ((s?.length ?: 0) >= maxLen) next?.requestFocus()
                }
            })
        }
        autoAdvance(yearEt, 4, monthEt)
        autoAdvance(monthEt, 2, dayEt)
        autoAdvance(dayEt, 2, hourEt)
        autoAdvance(hourEt, 2, minEt)

        val dialog = Dialog(this)
        dialog.requestWindowFeature(Window.FEATURE_NO_TITLE)
        dialog.setContentView(view)
        dialog.window?.setBackgroundDrawableResource(android.R.color.transparent)
        dialog.window?.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE)

        cancelBtn.setOnClickListener { dialog.dismiss() }

        setBtn.setOnClickListener {
            val y   = yearEt.text.toString().toIntOrNull()
            val mo  = monthEt.text.toString().toIntOrNull()
            val d   = dayEt.text.toString().toIntOrNull()
            val h   = hourEt.text.toString().toIntOrNull()
            val min = minEt.text.toString().toIntOrNull()

            if (y == null || mo == null || d == null || h == null || min == null
                || mo < 1 || mo > 12 || d < 1 || d > 31
                || h < 0 || h > 23 || min < 0 || min > 59) {
                errorTv.text = "// 올바른 날짜/시간을 입력하세요"
                errorTv.visibility = View.VISIBLE
                return@setOnClickListener
            }

            val target = Calendar.getInstance().apply {
                set(y, mo - 1, d, h, min, 0)
                set(Calendar.MILLISECOND, 0)
            }
            if (target.timeInMillis <= System.currentTimeMillis()) {
                errorTv.text = "// 현재 시각 이후로 설정하세요"
                errorTv.visibility = View.VISIBLE
                return@setOnClickListener
            }

            reminderMillis = target.timeInMillis
            val fmt = "%04d.%02d.%02d %02d:%02d".format(y, mo, d, h, min)
            showReminderIndicator("🔔 $fmt")
            dialog.dismiss()
        }

        dialog.show()
    }

    private fun setQuickReminder(days: Int, label: String) {
        val cal = Calendar.getInstance().apply {
            add(Calendar.DAY_OF_YEAR, days)
            set(Calendar.HOUR_OF_DAY, 9)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        reminderMillis = cal.timeInMillis
        val fmt = "%04d.%02d.%02d 09:00".format(
            cal.get(Calendar.YEAR), cal.get(Calendar.MONTH) + 1, cal.get(Calendar.DAY_OF_MONTH)
        )
        showReminderIndicator("🔔 $label: $fmt")
    }

    private fun showReminderIndicator(text: String) {
        val tv = findViewById<TextView>(R.id.mode_reminder_indicator)
        tv.text = text
        val modeRow = findViewById<LinearLayout>(R.id.mode_row)
        modeRow.visibility = View.VISIBLE
    }

    private fun isChecklistContent(content: String): Boolean {
        val lines = content.split("\n").filter { it.trim().isNotEmpty() }
        if (lines.isEmpty()) return false
        return lines.all {
            it.startsWith("- [ ] ") || it.startsWith("- [x] ") || it.startsWith("• ")
        }
    }

    private fun saveMemo() {
        val inputText = findViewById<EditText>(R.id.input_text)
        val content = inputText.text.toString().trim()
        if (content.isEmpty()) { finish(); return }

        val createdAtMs = targetDate?.let { (y, m, d) ->
            val now = Calendar.getInstance()
            Calendar.getInstance().apply {
                set(y, m - 1, d, now.get(Calendar.HOUR_OF_DAY),
                    now.get(Calendar.MINUTE), now.get(Calendar.SECOND))
                set(Calendar.MILLISECOND, 0)
            }.timeInMillis
        } ?: System.currentTimeMillis()

        val cal = Calendar.getInstance().apply { timeInMillis = createdAtMs }
        val createdAtIso = "%04d-%02d-%02dT%02d:%02d:%02d.000".format(
            cal.get(Calendar.YEAR), cal.get(Calendar.MONTH) + 1, cal.get(Calendar.DAY_OF_MONTH),
            cal.get(Calendar.HOUR_OF_DAY), cal.get(Calendar.MINUTE), cal.get(Calendar.SECOND),
        )

        val memo = JSONObject().apply {
            put("content", content)
            put("isChecklist", isChecklistContent(content))
            put("reminderAt", reminderMillis ?: JSONObject.NULL)
            put("folderId", selectedFolderId ?: JSONObject.NULL)
            put("createdAt", createdAtMs)
            put("createdAtIso", createdAtIso)
        }

        val existing = prefs.getString("pending_memos", "[]")
        val arr = try { JSONArray(existing) } catch (_: Exception) { JSONArray() }
        arr.put(memo)
        prefs.edit().putString("pending_memos", arr.toString()).apply()

        val manager = AppWidgetManager.getInstance(this)
        val ids = manager.getAppWidgetIds(ComponentName(this, MemoWidgetProvider::class.java))
        if (ids.isNotEmpty()) {
            val provider = MemoWidgetProvider()
            provider.onUpdate(this, manager, ids)
        }

        Toast.makeText(this, "메모 저장됨", Toast.LENGTH_SHORT).show()
        finish()
    }
}
