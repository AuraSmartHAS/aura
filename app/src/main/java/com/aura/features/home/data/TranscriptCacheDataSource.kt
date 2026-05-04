package com.aura.features.home.data

import com.aura.features.home.domain.TranscriptMessage
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import javax.inject.Inject
import javax.inject.Singleton

private const val INACTIVITY_TIMEOUT_MS = 15 * 60 * 1000L

@Singleton
class TranscriptCacheDataSource @Inject constructor(
    private val dao: TranscriptMessageDao,
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private var inactivityJob: Job? = null

    suspend fun loadMessages(): List<TranscriptMessage> {
        val lastTimestamp = dao.getLastTimestamp() ?: return emptyList()
        val elapsed = System.currentTimeMillis() - lastTimestamp
        return if (elapsed < INACTIVITY_TIMEOUT_MS) {
            scheduleInactivityClear(INACTIVITY_TIMEOUT_MS - elapsed)
            dao.getAll().map { it.toDomain() }
        } else {
            dao.clearAll()
            emptyList()
        }
    }

    suspend fun add(message: TranscriptMessage) {
        dao.insert(message.toEntity())
        resetInactivityTimer()
    }

    suspend fun clear() {
        dao.clearAll()
        inactivityJob?.cancel()
        inactivityJob = null
    }

    private fun resetInactivityTimer() {
        inactivityJob?.cancel()
        inactivityJob = scope.launch {
            delay(INACTIVITY_TIMEOUT_MS)
            clear()
        }
    }

    private fun scheduleInactivityClear(delayMs: Long) {
        inactivityJob?.cancel()
        inactivityJob = scope.launch {
            delay(delayMs.coerceAtLeast(0))
            clear()
        }
    }
}
