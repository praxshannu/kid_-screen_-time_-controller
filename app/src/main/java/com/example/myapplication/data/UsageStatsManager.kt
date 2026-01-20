package com.example.myapplication.data

import android.app.usage.UsageStatsManager
import android.content.Context
import java.util.Calendar

class UsageTracker(context: Context) {
    private val usageStatsManager = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager

    fun getUsageTimeForPackage(packageName: String): Long {
        val calendar = Calendar.getInstance()
        calendar.add(Calendar.DAY_OF_YEAR, -1)
        val stats = usageStatsManager.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY,
            calendar.timeInMillis,
            System.currentTimeMillis()
        )
        return stats.find { it.packageName == packageName }?.totalTimeInForeground ?: 0L
    }

    fun getAllUsageStats(): Map<String, Long> {
        val calendar = Calendar.getInstance()
        calendar.add(Calendar.DAY_OF_YEAR, -1)
        val stats = usageStatsManager.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY,
            calendar.timeInMillis,
            System.currentTimeMillis()
        )
        return stats.associate { it.packageName to it.totalTimeInForeground }
    }
}
