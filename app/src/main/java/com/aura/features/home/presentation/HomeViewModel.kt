package com.aura.features.home.presentation

import android.content.Context
import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.aura.features.home.domain.ConversationInteractor
import com.aura.features.home.domain.ConversationMode
import com.aura.features.home.domain.ConversationStatus
import dagger.hilt.android.lifecycle.HiltViewModel
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import kotlinx.coroutines.async
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.serialization.json.jsonPrimitive
import javax.inject.Inject

private const val TAG = "HomeViewModel"

@HiltViewModel
class HomeViewModel @Inject constructor(
    private val interactor: ConversationInteractor,
    private val supabaseClient: SupabaseClient,
) : ViewModel() {

    private val _viewState = MutableStateFlow<HomeScreenViewState>(HomeScreenViewState.Loading)
    val viewState: StateFlow<HomeScreenViewState> = _viewState.asStateFlow()

    private var conversationToken: String? = null

    init {
        loadInitialData()
        observeVoiceState()
    }

    fun onMicTapped(context: Context) {
        val current = _viewState.value as? HomeScreenViewState.Success ?: return
        when (current.voice) {
            VoiceUiState.Idle, is VoiceUiState.Error -> startSession(context)
            VoiceUiState.Connecting,
            VoiceUiState.Listening,
            VoiceUiState.Speaking -> interactor.stop()
        }
    }

    fun onRetry() {
        _viewState.value = HomeScreenViewState.Loading
        loadInitialData()
    }

    override fun onCleared() {
        interactor.stop()
        super.onCleared()
    }

    private fun loadInitialData() {
        viewModelScope.launch {
            val profileDeferred = async {
                runCatching { loadProfileName() }
                    .onFailure { Log.e(TAG, "loadProfileName failed", it) }
            }
            val tokenDeferred = async {
                runCatching { interactor.fetchToken() }
                    .onFailure { Log.e(TAG, "fetchToken failed", it) }
            }

            val profileResult = profileDeferred.await()
            val tokenResult = tokenDeferred.await()

            if (profileResult.isSuccess && tokenResult.isSuccess) {
                conversationToken = tokenResult.getOrThrow()
                _viewState.value = HomeScreenViewState.Success(name = profileResult.getOrThrow())
            } else {
                _viewState.value = HomeScreenViewState.Error
            }
        }
    }

    private fun loadProfileName(): String {
        val user = supabaseClient.auth.currentUserOrNull()
        return user?.userMetadata
            ?.get("full_name")
            ?.jsonPrimitive
            ?.content
            ?: "Usuário"
    }

    private fun observeVoiceState() {
        viewModelScope.launch {
            combine(interactor.status, interactor.mode, ::mapVoiceState)
                .collect { voice ->
                    _viewState.update { current ->
                        if (current is HomeScreenViewState.Success) current.copy(voice = voice)
                        else current
                    }
                }
        }
    }

    private fun startSession(context: Context) {
        val token = conversationToken
        if (token == null) {
            Log.e(TAG, "empty token")
            return
        }
        viewModelScope.launch {
            interactor.start(context, token).onFailure { throwable ->
                Log.e(TAG, "startSession failed", throwable)
                val message = throwable.message ?: "Não foi possível iniciar a conversa"
                _viewState.update { current ->
                    if (current is HomeScreenViewState.Success) current.copy(voice = VoiceUiState.Error(message))
                    else current
                }
            }
        }
    }

    private fun mapVoiceState(
        status: ConversationStatus,
        mode: ConversationMode,
    ): VoiceUiState = when (status) {
        ConversationStatus.Disconnected,
        ConversationStatus.Disconnecting -> VoiceUiState.Idle
        ConversationStatus.Connecting -> VoiceUiState.Connecting
        ConversationStatus.Connected -> when (mode) {
            ConversationMode.Listening -> VoiceUiState.Listening
            ConversationMode.Speaking -> VoiceUiState.Speaking
        }
        ConversationStatus.Error -> VoiceUiState.Error("Erro na conexão")
    }
}
