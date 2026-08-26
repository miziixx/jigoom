package com.ziia.jigeum

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import android.widget.SeekBar
import android.widget.TextView

/**
 * 캘린더 위젯 구성 액티비티 — 홈에 곰곰 캘린더 위젯을 얹을 때 먼저 뜬다.
 * 배경 진하기(투명도)를 슬라이더로 정하고 '확인' 하면 그 값으로 위젯이 생성된다.
 * (앱 안 설정이 아니라, 위젯 생성 시점에 위젯별로 정하는 표준 방식.)
 */
class CalendarConfigActivity : Activity() {

    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 그냥 나가면 위젯이 배치되지 않도록 기본은 취소.
        appWidgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID
        setResult(
            RESULT_CANCELED,
            Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        )
        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        setContentView(R.layout.calendar_config)

        val seek = findViewById<SeekBar>(R.id.cfg_seek)
        val pct = findViewById<TextView>(R.id.cfg_pct)
        // 새 위젯 기본값 = 은은한 반투명(40%). 배경화면이 비쳐 보인다.
        val initial = WidgetPrefs.opacityPercentFor(this, appWidgetId).let {
            if (it == 90) 40 else it
        }
        seek.progress = initial
        pct.text = "$initial%"
        seek.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(s: SeekBar?, p: Int, fromUser: Boolean) {
                pct.text = "$p%"
            }
            override fun onStartTrackingTouch(s: SeekBar?) {}
            override fun onStopTrackingTouch(s: SeekBar?) {}
        })

        findViewById<TextView>(R.id.cfg_ok).setOnClickListener {
            WidgetPrefs.setWidgetOpacity(this, appWidgetId, seek.progress)
            CalendarWidgetProvider().onUpdate(
                this, AppWidgetManager.getInstance(this), intArrayOf(appWidgetId)
            )
            setResult(
                RESULT_OK,
                Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            )
            finish()
        }
        findViewById<TextView>(R.id.cfg_cancel).setOnClickListener { finish() }
    }
}
