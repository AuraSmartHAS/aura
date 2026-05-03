package com.aura.features.home.domain

import android.content.Context
import com.aura.features.home.data.ConversationRepository
import kotlinx.coroutines.flow.StateFlow
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class ConversationInteractor @Inject constructor(
    private val repository: ConversationRepository,
) {
    val status: StateFlow<ConversationStatus> = repository.status
    val mode: StateFlow<ConversationMode> = repository.mode
    val isMuted: StateFlow<Boolean> = repository.isMuted

    suspend fun fetchToken(): String = repository.fetchToken()

    suspend fun start(context: Context, token: String): Result<Unit> =
        repository.startConversation(context, token)

    fun stop() = repository.endConversation()

    fun toggleMute() = repository.setMicMuted(!isMuted.value)
}
