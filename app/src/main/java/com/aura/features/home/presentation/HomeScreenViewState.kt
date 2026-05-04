package com.aura.features.home.presentation

import com.aura.features.home.domain.TranscriptMessage

sealed class HomeScreenViewState {
    data object Loading : HomeScreenViewState()
    data object Error : HomeScreenViewState()
    data class Success(
        val name: String,
        val voice: VoiceUiState = VoiceUiState.Idle,
        val transcript: List<TranscriptMessage> = emptyList(),
    ) : HomeScreenViewState()
}

sealed interface VoiceUiState {
    data object Idle : VoiceUiState
    data object Connecting : VoiceUiState
    data object Listening : VoiceUiState
    data object Speaking : VoiceUiState
    data class Error(val message: String) : VoiceUiState
}
