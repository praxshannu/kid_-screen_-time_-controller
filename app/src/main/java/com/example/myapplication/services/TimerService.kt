package com.example.myapplication.services

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.lifecycle.LifecycleService
import androidx.lifecycle.lifecycleScope
import androidx.localbroadcastmanager.content.LocalBroadcastManager
import com.example.myapplication.R
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

class TimerService : LifecycleService() {

    companion object {
        const val CHANNEL_ID = "antigravity_core"
        const val NOTIFICATION_ID = 999
        
        // Broadcast Actions
        const val ACTION_GRAVITY_WARNING = "com.example.myapplication.ACTION_GRAVITY_WARNING"
        const val ACTION_INITIATE_LOCK = "com.example.myapplication.ACTION_INITIATE_LOCK"
        const val ACTION_RELEASE_LOCK = "com.example.myapplication.ACTION_RELEASE_LOCK"
        
        // Debug Flag - Set to true to treat minutes as seconds
        private const val IS_ACCELERATED_MODE = false
    }

    private var timerJob: Job? = null
    private var currentState: TimerState = TimerState.HighOrbit
    private var timeRemainingSeconds: Long = 0
    private var sequenceIndex = 0


    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForegroundService()
        
        // Initialize the cycle
        startCycle(TimerState.HighOrbit)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        super.onStartCommand(intent, flags, startId)
        return START_STICKY
    }

    private fun startForegroundService() {
        val notification = buildNotification("Antigravity Active", "System Monitoring Child Usage")
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val type = if (Build.VERSION.SDK_INT >= 34) {
                // In Android 14 we use specialUse, but we must use the value since it might not be in the SDK yet if we are compiling against older API but targeting newer. 
                // However, constants are usually available if compileSdk is high.
                // ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE is available in API 34.
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            } else {
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC // Fallback for 10-13 if needed, or just 0
            }
            try {
                startForeground(NOTIFICATION_ID, notification, type)
            } catch (e: Exception) {
               // Fallback if permission missing or type issue
               startForeground(NOTIFICATION_ID, notification) 
            }
        } else {
             startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun startCycle(state: TimerState) {
        currentState = state
        
        // Calculate duration
        // logic: if IS_ACCELERATED_MODE, durationMinutes becomes seconds.
        val durationVal = state.durationMinutes
        timeRemainingSeconds = if (IS_ACCELERATED_MODE) {
            durationVal.toLong()
        } else {
            durationVal * 60L
        }

        startTimer()
    }

    private fun startTimer() {
        timerJob?.cancel()
        timerJob = lifecycleScope.launch {
            while (isActive && timeRemainingSeconds > 0) {
                // Check for Warning (T-minus 60 seconds)
                if (timeRemainingSeconds == 60L && !currentState.isLockState) {
                     sendBroadcast(ACTION_GRAVITY_WARNING)
                }
                
                // Update notification every minute or so if we wanted, but let's keep it static for now to save battery
                // Or maybe update it:
                // updateNotification("Time remaining: ${formatTime(timeRemainingSeconds)}")

                delay(1000)
                timeRemainingSeconds--
            }
            
            // Timer finished
            onTimerFinished()
        }
    }
    
    private fun onTimerFinished() {
        if (currentState.isLockState) {
             // We just finished a lock. Unlock the UI.
             sendBroadcast(ACTION_RELEASE_LOCK)
        } else {
             // We just finished playing. Lock the UI.
             sendBroadcast(ACTION_INITIATE_LOCK)
        }
        
        advanceSequence()
    }

    private fun advanceSequence() {
        sequenceIndex++
        
        val nextState = when (sequenceIndex) {
            0 -> TimerState.HighOrbit
            1 -> TimerState.CorrectionBurn
            2 -> TimerState.LowOrbit
            3 -> TimerState.CorrectionBurn
            4 -> TimerState.DecayOrbit
            else -> {
                // Loop behavior: 5, 6, 7, 8...
                if (sequenceIndex % 2 != 0) {
                    // Odd numbers > 4 are CorrectionBurn (5, 7, 9...)
                    TimerState.CorrectionBurn
                } else {
                    // Even numbers > 4 are DecayOrbit (6, 8, 10...)
                    TimerState.DecayOrbit
                }
            }
        }
        
        startCycle(nextState)
    }

    private fun sendBroadcast(action: String) {
        val intent = Intent(action)
        intent.setPackage(packageName) // Security: Restrict to our own app
        sendBroadcast(intent)
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "Antigravity Core"
            val descriptionText = "Ensures the Antigravity engine is running"
            val importance = NotificationManager.IMPORTANCE_LOW 
            val channel = NotificationChannel(CHANNEL_ID, name, importance).apply {
                description = descriptionText
            }
            val notificationManager: NotificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(title: String, content: String): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(content)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .build()
    }
}
