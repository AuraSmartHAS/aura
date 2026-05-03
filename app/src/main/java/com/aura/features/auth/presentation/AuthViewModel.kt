package com.aura.features.auth.presentation

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.providers.builtin.Email
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

private const val TAG = "AuthViewModel"

@HiltViewModel
class AuthViewModel @Inject constructor(
    private val supabaseClient: SupabaseClient,
) : ViewModel() {

    private val _authState = MutableStateFlow<AuthState>(AuthState.Idle)
    val authState: StateFlow<AuthState> = _authState.asStateFlow()

    fun login(email: String, password: String) {
        viewModelScope.launch {
            _authState.value = AuthState.Loading
            runCatching {
                supabaseClient.auth.signInWith(Email) {
                    this.email = email
                    this.password = password
                }
            }.onSuccess {
                _authState.value = AuthState.Success
            }.onFailure {
                Log.e(TAG, "login failed", it)
                _authState.value = AuthState.Error(it.message ?: "Login failed")
            }
        }
    }

    fun signUp(email: String, password: String) {
        viewModelScope.launch {
            _authState.value = AuthState.Loading
            runCatching {
                supabaseClient.auth.signUpWith(Email) {
                    this.email = email
                    this.password = password
                }
            }.onSuccess {
                _authState.value = AuthState.Success
            }.onFailure {
                Log.e(TAG, "signUp failed", it)
                _authState.value = AuthState.Error(it.message ?: "Sign up failed")
            }
        }
    }

    fun resetState() {
        _authState.value = AuthState.Idle
    }
}
