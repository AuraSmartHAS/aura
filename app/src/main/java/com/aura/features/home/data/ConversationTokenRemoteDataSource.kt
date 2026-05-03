package com.aura.features.home.data

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.functions.functions
import io.ktor.client.call.body
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class ConversationTokenRemoteDataSource @Inject constructor(
    private val supabaseClient: SupabaseClient,
) {
    suspend fun fetchToken(): String {
        val response = supabaseClient.functions.invoke(FUNCTION_NAME)
        val dto: ConversationTokenDto = response.body()
        return dto.token
    }

    private companion object {
        const val FUNCTION_NAME = "elevenlabs-token"
    }
}
