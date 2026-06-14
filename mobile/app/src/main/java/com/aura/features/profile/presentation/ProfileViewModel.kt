package com.aura.features.profile.presentation

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.serialization.json.jsonPrimitive
import javax.inject.Inject

@HiltViewModel
class ProfileViewModel @Inject constructor(
    private val supabaseClient: SupabaseClient,
) : ViewModel() {

    private val _userName = MutableStateFlow("")
    val userName: StateFlow<String> = _userName.asStateFlow()

    init {
        loadUserName()
    }

    fun signOut() {
        viewModelScope.launch {
            runCatching { supabaseClient.auth.signOut() }
        }
    }

    private fun loadUserName() {
        val user = supabaseClient.auth.currentUserOrNull()
        _userName.value = user?.userMetadata
            ?.get("full_name")
            ?.jsonPrimitive
            ?.content
            ?: "Usuário"
    }
}
