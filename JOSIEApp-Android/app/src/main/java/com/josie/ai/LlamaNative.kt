package com.josie.ai

class LlamaNative {
    companion object {
        init {
            System.loadLibrary("josie-llama")
        }
    }

    interface StreamCallback {
        // Receives raw bytes from llama_token_to_piece — may not be valid UTF-8.
        // Decode with Charsets.UTF_8 + REPLACE to safely handle byte-fallback tokens.
        fun onToken(bytes: ByteArray)
    }

    external fun loadModel(modelPath: String): Boolean
    external fun generateStream(prompt: String, callback: StreamCallback)
    external fun unload()
}
