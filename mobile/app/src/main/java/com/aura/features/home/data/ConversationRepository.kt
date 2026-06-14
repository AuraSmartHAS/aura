package com.aura.features.home.data

import android.content.Context
import android.util.Log
import com.aura.features.home.domain.ConversationMode
import com.aura.features.home.domain.ConversationStatus
import com.aura.features.home.domain.TranscriptMessage
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.withContext
import javax.inject.Inject
import javax.inject.Singleton

private const val TAG = "ConversationRepository"

@Singleton
class ConversationRepository @Inject constructor(
    private val tokenDataSource: ConversationTokenRemoteDataSource,
    private val sessionDataSource: ElevenLabsSessionDataSource,
) {
    val status: StateFlow<ConversationStatus> = sessionDataSource.status
    val mode: StateFlow<ConversationMode> = sessionDataSource.mode
    val isMuted: StateFlow<Boolean> = sessionDataSource.isMuted
    val transcript: StateFlow<List<TranscriptMessage>> = sessionDataSource.transcript

    suspend fun fetchToken(): String = tokenDataSource.fetchToken()

    suspend fun startConversation(context: Context, token: String): Result<Unit> = withContext(
        Dispatchers.IO
    ) {
        runCatching {
            sessionDataSource.start(token, context)
        }.onFailure { Log.e(TAG, "startConversation failed", it) }
    }

    fun endConversation() = sessionDataSource.stop()

    fun setMicMuted(muted: Boolean) = sessionDataSource.setMicMuted(muted)
}
