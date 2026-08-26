package com.ziia.jigeum

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.widget.LinearLayout
import android.widget.SeekBar
import android.widget.TextView

/**
 * 위젯 생성 설정창(바텀시트) — 홈에 곰곰 위젯을 얹을 때 먼저 뜬다.
 * 배경 진하기(투명도) · 글자 크기 · 테마를 정하고 '확인' 하면 **모든 위젯 공통**으로
 * 적용된다. (앱 안 설정이 아니라 위젯 생성 시점.)
 */
class CalendarConfigActivity : Activity() {

    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID
    private var fontPct = 100
    private var themeKey = "app"

    private val fontChips by lazy {
        listOf(
            findViewById<TextView>(R.id.cfg_f0),
            findViewById<TextView>(R.id.cfg_f1),
            findViewById<TextView>(R.id.cfg_f2),
        )
    }
    private val fontValues = listOf(85, 100, 120)

    // 앱 테마 따라가기 + 곰곰 6테마.
    private val themeOptions = listOf(
        "app" to Pair("앱", 0xFFEAE4D9.toInt()),
        "gomgom" to Pair("곰곰", 0xFFEAE4D9.toInt()),
        "lavender" to Pair("라벤더", 0xFFECE5EF.toInt()),
        "sagemist" to Pair("세이지", 0xFFE7E9DE.toInt()),
        "coastal" to Pair("코스탈", 0xFFF1EADF.toInt()),
        "blush" to Pair("블러시", 0xFFF3E7E4.toInt()),
        "lotus" to Pair("연꽃밤", 0xFF102A22.toInt()),
    )
    private val swatchViews = mutableListOf<View>()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        appWidgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID
        setResult(
            RESULT_CANCELED,
            Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        )
        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish(); return
        }

        setContentView(R.layout.calendar_config)

        // ── 초기값 (전역 위젯 설정) ──
        val prefs = getSharedPreferences(WidgetPrefs.FILE, MODE_PRIVATE)
        val opacity = prefs.getInt(WidgetPrefs.KEY_OPACITY, 40).coerceIn(0, 100)
        fontPct = prefs.getInt(WidgetPrefs.KEY_W_FONTSCALE, 100)
        themeKey = WidgetPrefs.widgetThemeKey(this)

        // ── 배경 진하기 ──
        val seek = findViewById<SeekBar>(R.id.cfg_seek)
        val pct = findViewById<TextView>(R.id.cfg_pct)
        seek.progress = opacity
        pct.text = "$opacity%"
        seek.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(s: SeekBar?, p: Int, u: Boolean) { pct.text = "$p%" }
            override fun onStartTrackingTouch(s: SeekBar?) {}
            override fun onStopTrackingTouch(s: SeekBar?) {}
        })

        // ── 글자 크기 칩 ──
        fontChips.forEachIndexed { i, chip ->
            chip.setOnClickListener { fontPct = fontValues[i]; refreshFontChips() }
        }
        refreshFontChips()

        // ── 테마 스와치 ──
        buildThemeSwatches()

        findViewById<TextView>(R.id.cfg_ok).setOnClickListener {
            prefs.edit()
                .putInt(WidgetPrefs.KEY_OPACITY, seek.progress)
                .putInt(WidgetPrefs.KEY_W_FONTSCALE, fontPct)
                .putString(WidgetPrefs.KEY_W_THEME, themeKey)
                .apply()
            // 이 위젯 + 이미 배치된 모든 위젯에 공통 적용.
            CalendarWidgetProvider().onUpdate(
                this, AppWidgetManager.getInstance(this), intArrayOf(appWidgetId)
            )
            WidgetPrefs.updateAllWidgets(this)
            setResult(
                RESULT_OK,
                Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            )
            finish()
        }
        findViewById<TextView>(R.id.cfg_cancel).setOnClickListener { finish() }
    }

    private fun refreshFontChips() {
        val sel = fontValues.indexOf(fontPct).let { if (it < 0) 1 else it }
        fontChips.forEachIndexed { i, chip ->
            if (i == sel) {
                chip.setBackgroundResource(R.drawable.w_chip_on)
                chip.setTextColor(0xFFF4F1EA.toInt())
            } else {
                chip.setBackgroundResource(R.drawable.w_chip_off)
                chip.setTextColor(0xFF26241F.toInt())
            }
        }
    }

    private fun dp(n: Int) = (n * resources.displayMetrics.density).toInt()

    private fun buildThemeSwatches() {
        val row = findViewById<LinearLayout>(R.id.cfg_themes)
        row.removeAllViews()
        swatchViews.clear()
        themeOptions.forEach { (key, meta) ->
            val (label, paper) = meta
            val col = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER_HORIZONTAL
                setPadding(0, 0, dp(14), 0)
                setOnClickListener { themeKey = key; refreshSwatches() }
            }
            val dot = View(this).apply {
                layoutParams = LinearLayout.LayoutParams(dp(38), dp(38))
            }
            dot.tag = paper
            swatchViews.add(dot)
            val name = TextView(this).apply {
                text = label
                typeface = android.graphics.Typeface.MONOSPACE
                textSize = 9f
                setTextColor(0xFF9A948A.toInt())
                gravity = Gravity.CENTER
                setPadding(0, dp(5), 0, 0)
            }
            col.addView(dot)
            col.addView(name)
            row.addView(col)
        }
        refreshSwatches()
    }

    private fun refreshSwatches() {
        themeOptions.forEachIndexed { i, (key, _) ->
            val dot = swatchViews[i]
            val paper = dot.tag as Int
            val selected = key == themeKey
            val d = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(paper)
                setStroke(
                    dp(if (selected) 3 else 1),
                    if (selected) 0xFFD6852A.toInt() else 0xFFDAD2C3.toInt()
                )
            }
            dot.background = d
        }
    }
}
