package com.aura.commons.database

import android.content.Context
import androidx.room.Room
import com.aura.features.home.data.TranscriptMessageDao
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object DatabaseModule {

    @Provides
    @Singleton
    fun provideAppDatabase(@ApplicationContext context: Context): AppDatabase =
        Room.databaseBuilder(context, AppDatabase::class.java, "aura_db").build()

    @Provides
    fun provideTranscriptMessageDao(database: AppDatabase): TranscriptMessageDao =
        database.transcriptMessageDao()
}
