package com.josie.ai

import androidx.annotation.Keep // 1. Add this import

class LlamaNative {
    companion object {
        init {
            System.loadLibrary("josie-llama")
        }
    }

    @Keep // 2. Protect the interface from obfuscation
    interface StreamCallback {
        @Keep // 3. Protect the exact method name and signature
        fun onToken(bytes: ByteArray)
    }

    external fun loadModel(modelPath: String): Boolean
    external fun generateStream(prompt: String, callback: StreamCallback)
    external fun unload()
}