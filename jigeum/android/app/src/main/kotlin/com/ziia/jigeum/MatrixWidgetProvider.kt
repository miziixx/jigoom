package com.ziia.jigeum

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * 매트릭스 위젯 (4×3) — 날짜 + 아이젠하워 2×2. 홈/잠금화면(keyguard) 공용.
 * 투명도는 WidgetPrefs.KEY_OPACITY 로 조절. 탭하면 앱 열기.
 */
class MatrixWidgetProvider : AppWidgetProvider() {

    public override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val prefs = context.getSharedPreferences(WidgetPrefs.FILE, Context.MODE_PRIVATE)
        val q1 = prefs.getString(WidgetPrefs.KEY_Q1, "") ?: ""
        val q2 = prefs.getString(WidgetPrefs.KEY_Q2, "") ?: ""
        val q3 = prefs.getString(WidgetPrefs.KEY_Q3, "") ?: ""
        val q4Count = prefs.getInt(WidgetPrefs.KEY_Q4_COUNT, 0)
        val alpha = WidgetPrefs.bgAlpha(context)
        val pal = WidgetPrefs.palette(context)

        val date = SimpleDateFormat("M월 d일 EEEE", Locale.KOREAN).format(Date())

        val launch = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pending = PendingIntent.getActivity(
            context, 2, launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.matrix_widget).apply {
                setTextViewText(R.id.matrix_date, date)
                setTextViewText(R.id.matrix_q1, q1.ifEmpty { "—" })
                setTextViewText(R.id.matrix_q2, q2.ifEmpty { "—" })
                setTextViewText(R.id.matrix_q3, q3.ifEmpty { "—" })
                setTextViewText(R.id.matrix_q4, "${q4Count}개")
                // 배경: 테마 paper + 투명도(alpha) 를 루트에 직접.
                setInt(R.id.matrix_root, "setBackgroundColor",
                    (alpha shl 24) or (pal.paper and 0xFFFFFF))
                setTextColor(R.id.matrix_date, pal.ink)
                setInt(R.id.matrix_rule, "setBackgroundColor", pal.ink)
                setInt(R.id.matrix_div1, "setBackgroundColor", pal.line)
                setInt(R.id.matrix_div2, "setBackgroundColor", pal.line)
                setInt(R.id.matrix_div3, "setBackgroundColor", pal.line)
                setTextColor(R.id.matrix_l1, pal.mark)
                setTextColor(R.id.matrix_l2, pal.ink)
                setTextColor(R.id.matrix_l3, pal.mark)
                setTextColor(R.id.matrix_l4, pal.inkSoft)
                setTextColor(R.id.matrix_q1, pal.ink)
                setTextColor(R.id.matrix_q2, pal.ink)
                setTextColor(R.id.matrix_q3, pal.ink)
                setTextColor(R.id.matrix_q4, pal.inkSoft)
                setOnClickPendingIntent(R.id.matrix_root, pending)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
