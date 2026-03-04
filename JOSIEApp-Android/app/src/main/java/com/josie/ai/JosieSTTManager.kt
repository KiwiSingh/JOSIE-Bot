package com.josie.ai

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import kotlinx.coroutines.flow.MutableStateFlow
import java.util.*

class JosieSTTManager(private val context: Context) : RecognitionListener {
    private var speechRecognizer: SpeechRecognizer? = null
    val transcript = MutableStateFlow("")
    val isListening = MutableStateFlow(false)

    init {
        if (SpeechRecognizer.isRecognitionAvailable(context)) {
            speechRecognizer = SpeechRecognizer.createSpeechRecognizer(context)
            speechRecognizer?.setRecognitionListener(this)
        }
    }

    fun startListening() {
        if (speechRecognizer == null) {
            transcript.value = "Speech recognition is not available on this device."
            return
        }
        
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault())
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
        }
        speechRecognizer?.startListening(intent)
        isListening.value = true
        transcript.value = ""
    }

    fun stopListening() {
        speechRecognizer?.stopListening()
        isListening.value = false
    }

    override fun onReadyForSpeech(params: Bundle?) {}
    override fun onBeginningOfSpeech() {}
    override fun onRmsChanged(rmsdB: Float) {}
    override fun onBufferReceived(buffer: ByteArray?) {}
    override fun onEndOfSpeech() {
        isListening.value = false
    }

    override fun onError(error: Int) {
        isListening.value = false
    }

    override fun onResults(results: Bundle?) {
        val data = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
        transcript.value = data?.get(0) ?: ""
    }

    override fun onPartialResults(partialResults: Bundle?) {
        val data = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
        transcript.value = data?.get(0) ?: ""
    }

    override fun onEvent(eventType: Int, params: Bundle?) {}

    fun destroy() {
        speechRecognizer?.destroy()
    }
}
