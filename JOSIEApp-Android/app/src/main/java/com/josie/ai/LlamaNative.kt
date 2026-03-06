package com.josie.ai

class LlamaNative {
    companion object {
        init {
            System.loadLibrary("josie-llama")
        }
    }

    interface StreamCallback {
        fun onToken(token: String)
    }

    external fun loadModel(modelPath: String): Boolean
    external fun generateStream(prompt: String, callback: StreamCallback)
}
