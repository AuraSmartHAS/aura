package com.aura.features.home.domain

enum class ConversationStatus {
    Disconnected,
    Connecting,
    Connected,
    Disconnecting,
    Error,
}

enum class ConversationMode {
    Listening,
    Speaking,
}

data class TranscriptMessage(val text: String, val isUser: Boolean)
