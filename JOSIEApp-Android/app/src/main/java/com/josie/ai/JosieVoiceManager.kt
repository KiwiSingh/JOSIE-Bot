package com.josie.ai

import android.content.Context
import android.speech.tts.TextToSpeech
import java.util.*

class JosieVoiceManager(context: Context) : TextToSpeech.OnInitListener {
    private var tts: TextToSpeech? = TextToSpeech(context, this)
    private var isReady = false
    var isEnabled: Boolean = true
    var pitch: Float = 1.3f
        set(value) {
            field = value
            tts?.setPitch(value)
        }
    var speechRate: Float = 0.9f
        set(value) {
            field = value
            tts?.setSpeechRate(value)
        }

    override fun onInit(status: Int) {
        if (status == TextToSpeech.SUCCESS) {
            tts?.apply {
                // Try to find a female voice
                val femaleVoice = voices?.find { 
                    it.name.lowercase().contains("female") || 
                    it.name.lowercase().contains("en-us-x-sfg") || // Google's common female voice
                    it.name.lowercase().contains("en-us-x-tpd")
                }
                if (femaleVoice != null) {
                    voice = femaleVoice
                }
                
                language = Locale.US
                setPitch(pitch)
                setSpeechRate(speechRate)
                isReady = true
            }
        } else {
            android.util.Log.e("JOSIE_TTS", "TextToSpeech initialization failed with status $status")
        }
    }

    fun speak(text: String) {
        if (!isReady || !isEnabled) return
        val cleanText = text.replace(Regex("[\\x{1F600}-\\x{1F64F}\\x{1F300}-\\x{1F5FF}]"), "")
        tts?.speak(cleanText, TextToSpeech.QUEUE_FLUSH, null, "JOSIE_TTS")
    }

    fun speakIncremental(text: String) {
        if (!isReady || !isEnabled) return
        val cleanText = text.replace(Regex("[\\x{1F600}-\\x{1F64F}\\x{1F300}-\\x{1F5FF}]"), "")
        if (cleanText.isNotBlank()) {
            tts?.speak(cleanText, TextToSpeech.QUEUE_ADD, null, "JOSIE_TTS_CHUNK_" + System.currentTimeMillis())
        }
    }

    fun shutdown() {
        tts?.stop()
        tts?.shutdown()
    }
}
