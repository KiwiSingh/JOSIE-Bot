package com.josie.ai

import java.util.UUID

data class ChatMessage(
    val id: String = UUID.randomUUID().toString(),
    val text: String,
    val isUser: Boolean,
    val timestamp: Long = System.currentTimeMillis()
)

enum class ModelStatus {
    IDLE, LOADING, READY, GENERATING, ERROR
}
