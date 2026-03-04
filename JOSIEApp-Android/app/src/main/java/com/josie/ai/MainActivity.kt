package com.josie.ai

import android.Manifest
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import androidx.core.app.ActivityCompat

class MainActivity : ComponentActivity() {
    private val brain: JosieBrain by viewModels()
    private lateinit var modelManager: ModelManager
    private lateinit var voiceManager: JosieVoiceManager
    private lateinit var sttManager: JosieSTTManager

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.RECORD_AUDIO), 1)

        modelManager = ModelManager(this)
        voiceManager = JosieVoiceManager(this)
        sttManager = JosieSTTManager(this)

        setContent {
            JOSIETheme {
                ChatScreen(brain, modelManager, voiceManager, sttManager)
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        voiceManager.shutdown()
        sttManager.destroy()
    }
}
