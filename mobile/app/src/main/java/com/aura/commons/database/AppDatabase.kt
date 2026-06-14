package com.aura.commons.database

import androidx.room.Database
import androidx.room.RoomDatabase
import com.aura.features.home.data.TranscriptMessageDao
import com.aura.features.home.data.TranscriptMessageEntity

@Database(entities = [TranscriptMessageEntity::class], version = 1)
abstract class AppDatabase : RoomDatabase() {
    abstract fun transcriptMessageDao(): TranscriptMessageDao
}
