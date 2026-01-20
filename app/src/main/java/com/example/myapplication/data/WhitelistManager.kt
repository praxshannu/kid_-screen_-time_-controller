package com.example.myapplication.data

import android.content.Context
import android.content.SharedPreferences

class WhitelistManager(context: Context) {
    private val prefs: SharedPreferences = context.getSharedPreferences("whitelist_prefs", Context.MODE_PRIVATE)

    fun getWhitelist(): Set<String> {
        return prefs.getStringSet("whitelist", emptySet()) ?: emptySet()
    }

    fun addToWhitelist(packageName: String) {
        val whitelist = getWhitelist().toMutableSet()
        whitelist.add(packageName)
        prefs.edit().putStringSet("whitelist", whitelist).apply()
    }

    fun removeFromWhitelist(packageName: String) {
        val whitelist = getWhitelist().toMutableSet()
        whitelist.remove(packageName)
        prefs.edit().putStringSet("whitelist", whitelist).apply()
    }
}
