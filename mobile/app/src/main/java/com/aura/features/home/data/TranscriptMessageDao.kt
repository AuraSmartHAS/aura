package com.aura.features.home.data

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query

@Dao
interface TranscriptMessageDao {

    @Query("SELECT * FROM transcript_messages ORDER BY id ASC")
    suspend fun getAll(): List<TranscriptMessageEntity>

    @Query("SELECT MAX(timestamp) FROM transcript_messages")
    suspend fun getLastTimestamp(): Long?

    @Insert
    suspend fun insert(message: TranscriptMessageEntity)

    @Query("DELETE FROM transcript_messages")
    suspend fun clearAll()
}
