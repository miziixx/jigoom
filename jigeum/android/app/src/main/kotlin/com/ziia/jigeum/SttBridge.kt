package com.ziia.jigeum

import android.Manifest
import android.app.Activity
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognitionService
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
        const val REQ_SPEECH = 7111
    }

    private val channel = MethodChannel(messenger, CHANNEL)
    private var recognizer: SpeechRecognizer? = null
    private var permResult: MethodChannel.Result? = null

    /** 마지막 start 의 로케일 — 다이얼로그 폴백 때 재사용. */
    private var currentLocale: String = "ko_KR"

    /** 이번 세션에서 다이얼로그 폴백을 이미 썼는지(무한 폴백 방지). */
    private var dialogFallbackUsed = false

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
                // 앱 안에서 바로 받아쓰기(팝업 없음). 부분결과가 실시간으로
                // Dart(onPartial)로 흘러 화면에 글자가 찍힌다. 이 기기가 한국어
                // 인라인 인식을 못 하면 onError 에서 구글 다이얼로그로 1회 폴백.
                currentLocale = call.argument<String>("localeId") ?: "ko_KR"
                dialogFallbackUsed = false
                startListening(currentLocale)
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

    /**
     * 구글 음성 인식 서비스를 우선 사용한다. 삼성 등 일부 기기는 기본 인식기가
     * 구글이 아니어서(빅스비 등) 한국어 데이터를 받아도 "언어 없음"이 나온다.
     * 구글 서비스가 있으면 그걸 콕 집어 쓰고, 없으면 시스템 기본으로 폴백.
     */
    private fun createRecognizer(): SpeechRecognizer {
        try {
            val services = activity.packageManager.queryIntentServices(
                Intent(RecognitionService.SERVICE_INTERFACE), 0
            )
            val google = services.firstOrNull {
                it.serviceInfo?.packageName == "com.google.android.googlequicksearchbox"
            }
            if (google != null) {
                val comp = ComponentName(
                    google.serviceInfo.packageName, google.serviceInfo.name)
                return SpeechRecognizer.createSpeechRecognizer(activity, comp)
            }
        } catch (_: Exception) {
            // 조회 실패 시 기본 인식기로 폴백.
        }
        return SpeechRecognizer.createSpeechRecognizer(activity)
    }

    private fun startListening(localeId: String) {
        recognizer?.destroy()
        val r = createRecognizer()
        r.setRecognitionListener(this)
        recognizer = r
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM
            )
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, localeId)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, localeId)
            putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, activity.packageName)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            // 오프라인 강제 금지 — 한국어 온디바이스 모델이 없는 폰에서 오프라인을
            // 강제하면 결과 없이 조용히 실패한다. 온라인 인식으로 폴백되게 둔다.
            putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, false)
            // 말 끝나자마자 잘리는 것 완화 — 한 박자 쉬어도 이어 말하게 침묵
            // 허용을 넉넉히. (엔진이 무시할 수도 있는 advisory 값)
            putExtra(
                RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS,
                2000L
            )
            putExtra(
                RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS,
                2000L
            )
            putExtra(
                RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS,
                1500L
            )
        }
        notifyStatus("listening")
        r.startListening(intent)
    }

    /**
     * 구글 기본 음성 입력 다이얼로그(ACTION_RECOGNIZE_SPEECH)를 띄운다.
     * 백그라운드 SpeechRecognizer 서비스가 일부 기기(삼성 등)에서 "언어 없음"을
     * 뱉는 문제를 우회 — 다이얼로그 방식은 구글 앱이 온라인/다운로드를 스스로
     * 처리해 거의 모든 기기에서 동작한다. 결과는 [onSpeechResult] 로 돌아온다.
     */
    private fun launchRecognitionDialog(localeId: String) {
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM
            )
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, localeId)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, localeId)
            putExtra(RecognizerIntent.EXTRA_PROMPT, "말해 주세요")
            putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, activity.packageName)
        }
        try {
            notifyStatus("listening")
            activity.startActivityForResult(intent, REQ_SPEECH)
        } catch (_: Exception) {
            notifyStatus("error")
            channel.invokeMethod(
                "onError",
                mapOf("code" to -1, "message" to "음성 입력을 열 수 없어요 (구글 앱 필요)")
            )
        }
    }

    /** MainActivity.onActivityResult 에서 위임 — 다이얼로그 결과 처리. */
    fun onSpeechResult(resultCode: Int, data: Intent?) {
        if (resultCode != Activity.RESULT_OK || data == null) {
            notifyStatus("done") // 사용자가 취소.
            return
        }
        val texts =
            data.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)
        val text = texts?.firstOrNull()?.trim() ?: ""
        if (text.isEmpty()) {
            notifyStatus("done")
            channel.invokeMethod(
                "onError",
                mapOf("code" to -2, "message" to "못 알아들었어요 (다시 말해줘)")
            )
            return
        }
        channel.invokeMethod(
            "onResult", mapOf("text" to text, "confidence" to -1.0)
        )
        notifyStatus("done")
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
        // 인라인 인식기가 이 기기에서 한국어를 못 돌리는 부류의 오류면(삼성 등
        // 기본 인식기가 빅스비라 "언어 없음"), 구글 음성 다이얼로그로 1회만
        // 조용히 폴백한다. 사용자가 안 말해서 난 no-match/timeout 은 그대로 알린다.
        if (!dialogFallbackUsed && shouldFallbackToDialog(error)) {
            dialogFallbackUsed = true
            recognizer?.destroy()
            recognizer = null
            launchRecognitionDialog(currentLocale)
            return
        }
        notifyStatus("error")
        channel.invokeMethod(
            "onError", mapOf("code" to error, "message" to errorMessage(error)))
    }

    /** 인라인 인식이 이 기기에서 불가능함을 뜻하는 오류인가(→ 다이얼로그 폴백). */
    private fun shouldFallbackToDialog(code: Int): Boolean = when (code) {
        SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED,
        SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE,
        SpeechRecognizer.ERROR_CLIENT -> true
        else -> false
    }

    /** SpeechRecognizer 오류 코드를 사람이 읽을 한국어 메시지로. */
    private fun errorMessage(code: Int): String = when (code) {
        SpeechRecognizer.ERROR_AUDIO -> "마이크 오류"
        SpeechRecognizer.ERROR_CLIENT -> "인식기 준비 실패 (다시 시도)"
        SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "마이크 권한이 없어요"
        SpeechRecognizer.ERROR_NETWORK -> "네트워크 오류 (온라인 인식 필요)"
        SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "네트워크 시간 초과"
        SpeechRecognizer.ERROR_NO_MATCH -> "못 알아들었어요 (다시 말해줘)"
        SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "인식기가 바빠요 (잠시 후)"
        SpeechRecognizer.ERROR_SERVER -> "음성 서버 오류"
        SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "말이 없어서 종료했어요"
        SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED -> "한국어 미지원 기기"
        SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE ->
            "한국어 음성 데이터 없음 (구글 앱에서 다운로드 필요)"
        else -> "음성 인식 오류 (코드 $code)"
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
