package com.example.myapplication.receivers

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.example.myapplication.data.SecureStorageManager
import com.example.myapplication.data.WhitelistManager

class AppInstallReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (Intent.ACTION_PACKAGE_ADDED == intent.action) {
            val secureStorageManager = SecureStorageManager(context)
            if (secureStorageManager.isKidModeActive()) {
                val packageName = intent.data?.schemeSpecificPart
                if (packageName != null) {
                    val whitelistManager = WhitelistManager(context)
                    whitelistManager.removeFromWhitelist(packageName) // Ensure new apps are not whitelisted
                }
            }
        }
    }
}
