package com.example.myapplication.data

import android.content.Context
import androidx.media3.common.util.UnstableApi
import androidx.media3.database.StandaloneDatabaseProvider
import androidx.media3.datasource.cache.LeastRecentlyUsedCacheEvictor
import androidx.media3.datasource.cache.SimpleCache
import java.io.File

@UnstableApi
class ContentCacheManager(context: Context) {
    private val cacheDir = File(context.cacheDir, "video_cache")
    private val databaseProvider = StandaloneDatabaseProvider(context)
    private val cacheSize = 100 * 1024 * 1024L // 100MB
    
    val simpleCache: SimpleCache by lazy {
        SimpleCache(cacheDir, LeastRecentlyUsedCacheEvictor(cacheSize), databaseProvider)
    }

    companion object {
        private var instance: ContentCacheManager? = null

        fun getInstance(context: Context): ContentCacheManager {
            return instance ?: synchronized(this) {
                instance ?: ContentCacheManager(context).also { instance = it }
            }
        }
    }
}
