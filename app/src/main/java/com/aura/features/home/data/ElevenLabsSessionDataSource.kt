package com.aura.features.home.data

import android.content.Context
import android.util.Log
import com.aura.features.home.domain.ConversationMode
import com.aura.features.home.domain.ConversationStatus
import io.elevenlabs.ConversationClient
import io.elevenlabs.ConversationConfig
import io.elevenlabs.ConversationSession
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import io.elevenlabs.models.ConversationMode as SdkConversationMode
import io.elevenlabs.models.ConversationStatus as SdkConversationStatus
import io.elevenlabs.models.DisconnectionDetails
import javax.inject.Inject
import javax.inject.Singleton

private const val TAG = "ElevenLabsDataSource"

@Singleton
class ElevenLabsSessionDataSource @Inject constructor() {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var session: ConversationSession? = null

    private val _status = MutableStateFlow(ConversationStatus.Disconnected)
    val status: StateFlow<ConversationStatus> = _status.asStateFlow()

    private val _mode = MutableStateFlow(ConversationMode.Listening)
    val mode: StateFlow<ConversationMode> = _mode.asStateFlow()

    private val _isMuted = MutableStateFlow(false)
    val isMuted: StateFlow<Boolean> = _isMuted.asStateFlow()

    suspend fun start(token: String, context: Context) {
        // Ensure any previous session is fully ended before starting a new one
        stop()

        val config = ConversationConfig(
            conversationToken = token,
            onStatusChange = { sdkStatus ->
                Log.d(TAG, "Status changed: $sdkStatus")
                _status.value = sdkStatus.toDomain()
            },
            onModeChange = { sdkMode ->
                Log.d(TAG, "Mode changed: $sdkMode")
                _mode.value = sdkMode.toDomain()
            },
            onDisconnect = { details ->
                Log.d(TAG, "Disconnected: $details")
                if (details is DisconnectionDetails.Error) {
                    Log.e(TAG, "Session error: ${details.exception.message}", details.exception)
                }
            }
        )

        try {
            session = withContext(Dispatchers.IO) {
                ConversationClient.startSession(config, context)
            }
            _isMuted.value = false
            Log.d(TAG, "Session started successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start session", e)
            throw e
        }
    }

    fun stop() {
        val current = session ?: return
        session = null
        scope.launch {
            try {
                current.endSession()
                Log.d(TAG, "Session ended")
            } catch (e: Exception) {
                Log.e(TAG, "Error ending session", e)
            }
        }
        _status.value = ConversationStatus.Disconnected
        _mode.value = ConversationMode.Listening
        _isMuted.value = false
    }

    fun setMicMuted(muted: Boolean) {
        val current = session ?: return
        _isMuted.value = muted
        scope.launch {
            current.setMicMuted(muted)
        }
    }

    private fun SdkConversationStatus.toDomain(): ConversationStatus = when (this) {
        SdkConversationStatus.CONNECTED -> ConversationStatus.Connected
        SdkConversationStatus.CONNECTING -> ConversationStatus.Connecting
        SdkConversationStatus.DISCONNECTED -> ConversationStatus.Disconnected
        SdkConversationStatus.DISCONNECTING -> ConversationStatus.Disconnecting
        SdkConversationStatus.ERROR -> ConversationStatus.Error
    }

    private fun SdkConversationMode.toDomain(): ConversationMode = when (this) {
        SdkConversationMode.LISTENING -> ConversationMode.Listening
        SdkConversationMode.SPEAKING -> ConversationMode.Speaking
    }
}
