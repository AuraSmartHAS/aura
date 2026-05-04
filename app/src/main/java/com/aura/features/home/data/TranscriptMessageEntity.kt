package com.aura.features.home.data

import androidx.room.Entity
import androidx.room.PrimaryKey
import com.aura.features.home.domain.TranscriptMessage

@Entity(tableName = "transcript_messages")
data class TranscriptMessageEntity(
    @PrimaryKey(autoGenerate = true) val id: Int = 0,
    val text: String,
    val isUser: Boolean,
    val timestamp: Long = System.currentTimeMillis(),
) {
    fun toDomain() = TranscriptMessage(text = text, isUser = isUser)
}

fun TranscriptMessage.toEntity() = TranscriptMessageEntity(text = text, isUser = isUser)
