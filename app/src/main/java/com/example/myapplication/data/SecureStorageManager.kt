package com.example.myapplication.data

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

class SecureStorageManager(context: Context) {
    private val masterKey = MasterKey.Builder(context)
        .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
        .build()

    private val sharedPreferences: SharedPreferences = EncryptedSharedPreferences.create(
        context,
        "secure_prefs",
        masterKey,
        EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
        EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
    )

    fun setKidModeActive(isActive: Boolean) {
        sharedPreferences.edit().putBoolean("is_kid_mode_active", isActive).apply()
    }

    fun isKidModeActive(): Boolean {
        return sharedPreferences.getBoolean("is_kid_mode_active", false)
    }

    fun isSetupComplete(): Boolean {
        return sharedPreferences.getBoolean("is_setup_complete", false)
    }

    fun setSetupComplete(isComplete: Boolean) {
        sharedPreferences.edit().putBoolean("is_setup_complete", isComplete).apply()
    }

    fun getParentPin(): String {
        return sharedPreferences.getString("parent_pin", "1234") ?: "1234"
    }

    fun setParentPin(pin: String) {
        sharedPreferences.edit().putString("parent_pin", pin).apply()
    }
}
