package com.ziia.jigeum

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.widget.RemoteViews
import java.io.File

/**
 * 위젯 스튜디오 홈 위젯 — Flutter 가 그려 캡처한 PNG(appWidgetId 별)를
 * ImageView 로 그대로 표시한다(render→image 방식, 레퍼런스 디자인 픽셀 일치).
 *
 * 배치 시 StudioWidgetConfigActivity(구성 액티비티)가 이미지를 저장하고
 * 첫 렌더를 수행한다. 이후 재부팅/갱신 시 onUpdate 가 저장된 이미지를 다시 그린다.
 */
class StudioWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (id in appWidgetIds) render(context, appWidgetManager, id)
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        for (id in appWidgetIds) StudioWidgetStore.delete(context, id)
    }

    companion object {
        /** 저장된 PNG 로 위젯 하나를 그린다. 탭하면 앱을 연다. */
        fun render(context: Context, manager: AppWidgetManager, id: Int) {
            val views = RemoteViews(context.packageName, R.layout.studio_widget)
            val bmp = StudioWidgetStore.load(context, id)
            if (bmp != null) {
                views.setImageViewBitmap(R.id.studio_image, bmp)
            }
            val pending = PendingIntent.getActivity(
                context, 3000 + id,
                Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.studio_image, pending)
            manager.updateAppWidget(id, views)
        }
    }
}

/** appWidgetId 별 렌더 이미지 저장소(내부 저장소 파일). */
object StudioWidgetStore {
    private fun dir(context: Context): File =
        File(context.filesDir, "studio_widget").apply { mkdirs() }

    private fun file(context: Context, id: Int): File = File(dir(context), "$id.png")

    fun save(context: Context, id: Int, png: ByteArray) {
        file(context, id).writeBytes(png)
    }

    fun load(context: Context, id: Int): Bitmap? {
        val f = file(context, id)
        return if (f.exists()) BitmapFactory.decodeFile(f.absolutePath) else null
    }

    fun delete(context: Context, id: Int) {
        file(context, id).delete()
    }
}
