package com.katala.app.bridges

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Native Android SpeechBridge implementation.
 *
 * Enforces on-device recognition on Android 13+ (API 33+) via
 * [SpeechRecognizer.createOnDeviceSpeechRecognizer].
 * Uses EXTRA_PREFER_OFFLINE on Android 10-12 (API 29-32).
 */
class SpeechBridgeImpl(
    private val context: Context,
    messenger: BinaryMessenger
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "com.katala.app/speech"
        private const val MAX_SESSION_DURATION_MS = 30000L
    }

    private val channel = MethodChannel(messenger, CHANNEL_NAME)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager

    private var speechRecognizer: SpeechRecognizer? = null
    private var isListening = false
    private var accumulatedTranscript: String = ""
    private var silenceRunnable: Runnable? = null
    private var maxSessionRunnable: Runnable? = null
    private var audioFocusRequest: AudioFocusRequest? = null
    private var activeRecognizerIntent: Intent? = null

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getAvailability" -> {
                result.success(checkAvailability())
            }
            "isOnDeviceAvailable" -> {
                result.success(isOnDeviceRecognitionAvailable())
            }
            "startListening" -> {
                val silenceTimeoutSec = call.argument<Double>("silenceTimeout")
                startListening(silenceTimeoutSec, result)
            }
            "stopListening" -> {
                stopListening(result)
            }
            "cancelListening", "cancel" -> {
                cancelListening(result)
            }
            "dispose" -> {
                dispose()
                result.success(null)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun checkAvailability(): String {
        val hasPermission = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED

        if (!hasPermission) {
            return "restricted"
        }

        if (!SpeechRecognizer.isRecognitionAvailable(context)) {
            return "notSupported"
        }

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (SpeechRecognizer.isOnDeviceRecognitionAvailable(context)) {
                "available"
            } else {
                "notSupported"
            }
        } else {
            // Android 10-12: best-effort offline preference
            "available"
        }
    }

    private fun isOnDeviceRecognitionAvailable(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            SpeechRecognizer.isOnDeviceRecognitionAvailable(context)
        } else {
            // Android 10-12 cannot strictly guarantee on-device
            false
        }
    }

    private fun startListening(silenceTimeoutSec: Double?, result: MethodChannel.Result) {
        val hasPermission = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED

        if (!hasPermission) {
            result.error("PERMISSION_DENIED", "RECORD_AUDIO permission not granted", null)
            return
        }

        if (!SpeechRecognizer.isRecognitionAvailable(context)) {
            result.error("SPEECH_NOT_AVAILABLE", "Speech recognizer is not available on this device", null)
            return
        }

        mainHandler.post {
            try {
                cleanupRecognizer()
                requestAudioFocus()
                accumulatedTranscript = ""

                val recognizer = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    if (SpeechRecognizer.isOnDeviceRecognitionAvailable(context)) {
                        SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
                    } else {
                        SpeechRecognizer.createSpeechRecognizer(context)
                    }
                } else {
                    SpeechRecognizer.createSpeechRecognizer(context)
                }

                speechRecognizer = recognizer

                val recognizerIntent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                    putExtra(
                        RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                        RecognizerIntent.LANGUAGE_MODEL_FREE_FORM
                    )
                    putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                    putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
                    putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
                    putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 3500L)
                    putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, 3000L)
                    putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS, 1500L)
                }

                activeRecognizerIntent = recognizerIntent

                recognizer.setRecognitionListener(object : RecognitionListener {
                    override fun onReadyForSpeech(params: Bundle?) {
                        resetSilenceTimer(silenceTimeoutSec)
                    }

                    override fun onBeginningOfSpeech() {
                        cancelSilenceTimer()
                    }

                    override fun onRmsChanged(rmsdB: Float) {}

                    override fun onBufferReceived(buffer: ByteArray?) {}

                    override fun onEndOfSpeech() {
                        cancelSilenceTimer()
                    }

                    override fun onError(error: Int) {
                        // If no match on intermediate pause, restart recognizer if session is still alive
                        if (error == SpeechRecognizer.ERROR_NO_MATCH || error == SpeechRecognizer.ERROR_SPEECH_TIMEOUT) {
                            if (isListening && activeRecognizerIntent != null) {
                                mainHandler.post {
                                    try {
                                        speechRecognizer?.startListening(activeRecognizerIntent!!)
                                    } catch (_: Exception) {}
                                }
                                return
                            }
                        }

                        val mappedError = mapErrorCode(error)
                        channel.invokeMethod(
                            "onSpeechError",
                            mapOf("error" to mappedError.first, "message" to mappedError.second)
                        )
                        cleanupRecognizer()
                    }

                    override fun onResults(results: Bundle?) {
                        val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        val text = matches?.firstOrNull() ?: ""
                        if (text.isNotEmpty()) {
                            accumulatedTranscript = if (accumulatedTranscript.isEmpty()) text else "$accumulatedTranscript $text"
                        }

                        channel.invokeMethod(
                            "onSpeechResult",
                            mapOf("text" to accumulatedTranscript, "isFinal" to false)
                        )

                        // If user hasn't explicitly stopped listening, keep listening for follow-up phrases
                        if (isListening && activeRecognizerIntent != null) {
                            mainHandler.post {
                                try {
                                    speechRecognizer?.startListening(activeRecognizerIntent!!)
                                } catch (_: Exception) {}
                            }
                        }
                    }

                    override fun onPartialResults(partialResults: Bundle?) {
                        val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        val text = matches?.firstOrNull() ?: ""
                        if (text.isNotEmpty()) {
                            val liveText = if (accumulatedTranscript.isEmpty()) text else "$accumulatedTranscript $text"
                            channel.invokeMethod(
                                "onSpeechResult",
                                mapOf("text" to liveText, "isFinal" to false)
                            )
                        }
                    }

                    override fun onEvent(eventType: Int, params: Bundle?) {}
                })

                recognizer.startListening(recognizerIntent)
                isListening = true

                // Max session timeout (30 seconds per spec)
                maxSessionRunnable = Runnable {
                    if (isListening) {
                        stopListeningInternal()
                    }
                }
                mainHandler.postDelayed(maxSessionRunnable!!, MAX_SESSION_DURATION_MS)

                result.success(true)
            } catch (e: Exception) {
                cleanupRecognizer()
                result.error("SPEECH_NOT_AVAILABLE", e.message, null)
            }
        }
    }

    private fun stopListening(result: MethodChannel.Result) {
        mainHandler.post {
            val finalTranscript = stopListeningInternal()
            result.success(finalTranscript)
        }
    }

    private fun stopListeningInternal(): String {
        isListening = false
        val finalResult = accumulatedTranscript.trim()
        channel.invokeMethod(
            "onSpeechResult",
            mapOf("text" to finalResult, "isFinal" to true)
        )
        cleanupRecognizer()
        return finalResult
    }

    private fun cancelListening(result: MethodChannel.Result) {
        mainHandler.post {
            cleanupRecognizer()
            result.success(true)
        }
    }

    private fun resetSilenceTimer(silenceTimeoutSec: Double?) {
        cancelSilenceTimer()
        val timeoutMs = ((silenceTimeoutSec ?: 5.0) * 1000).toLong().coerceAtLeast(1000L)
        silenceRunnable = Runnable {
            if (isListening) {
                // If we already have partial speech, don't abort with error
                if (accumulatedTranscript.isNotEmpty()) {
                    stopListeningInternal()
                } else {
                    channel.invokeMethod(
                        "onSpeechError",
                        mapOf("error" to "NO_SPEECH_DETECTED", "message" to "Speech timeout")
                    )
                    cleanupRecognizer()
                }
            }
        }
        mainHandler.postDelayed(silenceRunnable!!, timeoutMs)
    }

    private fun cancelSilenceTimer() {
        silenceRunnable?.let {
            mainHandler.removeCallbacks(it)
            silenceRunnable = null
        }
    }

    private fun cancelMaxSessionTimer() {
        maxSessionRunnable?.let {
            mainHandler.removeCallbacks(it)
            maxSessionRunnable = null
        }
    }

    private fun requestAudioFocus() {
        audioManager?.let { am ->
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val playbackAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ASSISTANCE_ACCESSIBILITY)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build()
                val focusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                    .setAudioAttributes(playbackAttributes)
                    .setOnAudioFocusChangeListener { focusChange ->
                        if (focusChange == AudioManager.AUDIOFOCUS_LOSS ||
                            focusChange == AudioManager.AUDIOFOCUS_LOSS_TRANSIENT
                        ) {
                            channel.invokeMethod(
                                "onSpeechError",
                                mapOf("error" to "AUDIO_INTERRUPTED", "message" to "Audio focus lost")
                            )
                            cleanupRecognizer()
                        }
                    }
                    .build()
                audioFocusRequest = focusRequest
                am.requestAudioFocus(focusRequest)
            } else {
                @Suppress("DEPRECATION")
                am.requestAudioFocus(
                    { focusChange ->
                        if (focusChange == AudioManager.AUDIOFOCUS_LOSS ||
                            focusChange == AudioManager.AUDIOFOCUS_LOSS_TRANSIENT
                        ) {
                            channel.invokeMethod(
                                "onSpeechError",
                                mapOf("error" to "AUDIO_INTERRUPTED", "message" to "Audio focus lost")
                            )
                            cleanupRecognizer()
                        }
                    },
                    AudioManager.STREAM_VOICE_CALL,
                    AudioManager.AUDIOFOCUS_GAIN_TRANSIENT
                )
            }
        }
    }

    private fun abandonAudioFocus() {
        audioManager?.let { am ->
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                audioFocusRequest?.let { am.abandonAudioFocusRequest(it) }
                audioFocusRequest = null
            } else {
                @Suppress("DEPRECATION")
                am.abandonAudioFocus(null)
            }
        }
    }

    private fun cleanupRecognizer() {
        isListening = false
        activeRecognizerIntent = null
        cancelSilenceTimer()
        cancelMaxSessionTimer()
        abandonAudioFocus()
        try {
            speechRecognizer?.destroy()
        } catch (_: Exception) {}
        speechRecognizer = null
    }

    private fun mapErrorCode(error: Int): Pair<String, String> {
        return when (error) {
            SpeechRecognizer.ERROR_AUDIO -> "SPEECH_NOT_AVAILABLE" to "Audio recording error"
            SpeechRecognizer.ERROR_CLIENT -> "SPEECH_NOT_AVAILABLE" to "Client side error"
            SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "PERMISSION_DENIED" to "Insufficient permissions"
            SpeechRecognizer.ERROR_NETWORK, SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "SPEECH_NOT_AVAILABLE" to "Network error"
            SpeechRecognizer.ERROR_NO_MATCH -> "NO_SPEECH_DETECTED" to "No speech detected or matched"
            SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "SPEECH_NOT_AVAILABLE" to "Speech recognition service busy"
            SpeechRecognizer.ERROR_SERVER -> "SPEECH_NOT_AVAILABLE" to "Server error"
            SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "NO_SPEECH_DETECTED" to "Speech input timeout"
            else -> "SPEECH_NOT_AVAILABLE" to "Speech recognition error ($error)"
        }
    }

    fun dispose() {
        cleanupRecognizer()
        channel.setMethodCallHandler(null)
    }
}
