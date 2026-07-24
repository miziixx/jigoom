package com.ziia.jigeum

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * 'jigeum/stt' MethodChannel — 온디바이스 SpeechRecognizer(한국어) 브리지.
 *
 * Dart→네이티브 명령: requestPermission / isAvailable / start / stop / cancel.
 * 네이티브→Dart 콜백: onPartial / onResult / onStatus / onError.
 * (Dart 쪽 계약은 [MethodChannelSttService] 참조)
 *
 * SpeechRecognizer 는 메인 스레드에서만 생성·구동해야 한다. MethodChannel
 * 핸들러가 메인 스레드에서 호출되므로 그대로 사용한다.
 */
class SttBridge(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : RecognitionListener {

    companion object {
        const val CHANNEL = "jigeum/stt"
        const val REQ_AUDIO_PERM = 7110
    }

    private val channel = MethodChannel(messenger, CHANNEL)
    private var recognizer: SpeechRecognizer? = null
    private var permResult: MethodChannel.Result? = null

    init {
        channel.setMethodCallHandler { call, result -> handle(call, result) }
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" ->
                result.success(SpeechRecognizer.isRecognitionAvailable(activity))
            "requestPermission" -> {
                if (hasAudioPermission()) {
                    result.success(true)
                } else {
                    permResult = result
                    ActivityCompat.requestPermissions(
                        activity,
                        arrayOf(Manifest.permission.RECORD_AUDIO),
                        REQ_AUDIO_PERM
                    )
                }
            }
            "start" -> {
                startListening(call.argument<String>("localeId") ?: "ko_KR")
                result.success(null)
            }
            "stop" -> {
                recognizer?.stopListening()
                result.success(null)
            }
            "cancel" -> {
                recognizer?.cancel()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun hasAudioPermission(): Boolean =
        ContextCompat.checkSelfPermission(
            activity, Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED

    /** MainActivity.onRequestPermissionsResult 에서 위임. */
    fun onAudioPermissionResult(granted: Boolean) {
        permResult?.success(granted)
        permResult = null
    }

    private fun startListening(localeId: String) {
        recognizer?.destroy()
        val r = SpeechRecognizer.createSpeechRecognizer(activity)
        r.setRecognitionListener(this)
        recognizer = r
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM
            )
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, localeId)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            // 온디바이스 우선(가능 기기에서 오프라인). 미지원이면 시스템이 무시.
            putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
        }
        notifyStatus("listening")
        r.startListening(intent)
    }

    fun dispose() {
        recognizer?.destroy()
        recognizer = null
        channel.setMethodCallHandler(null)
    }

    // ---------------------------------------------------- RecognitionListener

    override fun onPartialResults(partialResults: Bundle?) =
        emit("onPartial", partialResults)

    override fun onResults(results: Bundle?) {
        emit("onResult", results)
    }

    override fun onError(error: Int) {
        notifyStatus("error")
        channel.invokeMethod("onError", mapOf("code" to error))
    }

    override fun onReadyForSpeech(params: Bundle?) = notifyStatus("listening")
    override fun onEndOfSpeech() = notifyStatus("done")

    override fun onBeginningOfSpeech() {}
    override fun onRmsChanged(rmsdB: Float) {}
    override fun onBufferReceived(buffer: ByteArray?) {}
    override fun onEvent(eventType: Int, params: Bundle?) {}

    // ---------------------------------------------------------------- helpers

    private fun emit(method: String, bundle: Bundle?) {
        val texts = bundle?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
        val scores = bundle?.getFloatArray(SpeechRecognizer.CONFIDENCE_SCORES)
        val text = texts?.firstOrNull() ?: ""
        val confidence = scores?.firstOrNull()?.toDouble() ?: -1.0
        channel.invokeMethod(
            method, mapOf("text" to text, "confidence" to confidence)
        )
    }

    private fun notifyStatus(status: String) {
        channel.invokeMethod("onStatus", mapOf("status" to status))
    }
}
