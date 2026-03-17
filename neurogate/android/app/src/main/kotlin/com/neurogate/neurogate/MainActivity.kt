package com.neurogate.neurogate

import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.neurogate/apps"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInstalledApps" -> {
                    val apps = getInstalledApps()
                    result.success(apps)
                }
                "launchApp" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
                        if (launchIntent != null) {
                            startActivity(launchIntent)
                            result.success(null)
                        } else {
                            result.error("APP_NOT_FOUND", "App not found", null)
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "Package name is required", null)
                    }
                }
                "getForegroundApp" -> {
                    result.success(getForegroundApp())
                }
                "goHome" -> {
                    val startMain = Intent(Intent.ACTION_MAIN)
                    startMain.addCategory(Intent.CATEGORY_HOME)
                    startMain.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    startActivity(startMain)
                    result.success(null)
                }
                // --- Floating Overlay ---
                "canDrawOverlays" -> {
                    result.success(Settings.canDrawOverlays(this))
                }
                "requestOverlayPermission" -> {
                    val intent = Intent(
                        Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                        Uri.parse("package:$packageName")
                    )
                    intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    startActivity(intent)
                    result.success(null)
                }
                "startOverlay" -> {
                    val remaining = call.argument<Int>("remaining") ?: 0
                    val total = call.argument<Int>("total") ?: 1
                    val intent = Intent(this, FloatingTimerService::class.java)
                    intent.putExtra("remaining", remaining)
                    intent.putExtra("total", total)
                    startService(intent)
                    result.success(null)
                }
                "getRemainingSeconds" -> {
                    val prefs = getSharedPreferences("neurogate_timer", MODE_PRIVATE)
                    val remaining = prefs.getInt("remainingSeconds", -1)
                    result.success(remaining)
                }
                "stopOverlay" -> {
                    val intent = Intent(this, FloatingTimerService::class.java)
                    intent.action = FloatingTimerService.ACTION_STOP
                    startService(intent)
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // When overlay is tapped, it brings us back with triggerChallenge=true
        if (intent.getBooleanExtra("triggerChallenge", false)) {
            val channel = flutterEngine?.dartExecutor?.binaryMessenger?.let {
                MethodChannel(it, CHANNEL)
            }
            channel?.invokeMethod("onOverlayTapped", mapOf(
                "remainingSeconds" to intent.getIntExtra("remainingSeconds", 0)
            ))
        }
    }

    private fun getForegroundApp(): String? {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val time = System.currentTimeMillis()
        val stats = usageStatsManager.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, time - 1000 * 10, time)
        if (stats != null && stats.isNotEmpty()) {
            var latestStats = stats[0]
            for (usageStats in stats) {
                if (usageStats.lastTimeUsed > latestStats.lastTimeUsed) {
                    latestStats = usageStats
                }
            }
            return latestStats.packageName
        }
        return null
    }

    private fun getInstalledApps(): List<Map<String, String>> {
        val packageManager = packageManager
        val intent = Intent(Intent.ACTION_MAIN, null)
        intent.addCategory(Intent.CATEGORY_LAUNCHER)
        val apps = packageManager.queryIntentActivities(intent, 0)
        
        val appList = mutableListOf<Map<String, String>>()
        for (app in apps) {
            val appInfo = mutableMapOf<String, String>()
            appInfo["name"] = app.loadLabel(packageManager).toString()
            val packageName = app.activityInfo.packageName
            appInfo["packageName"] = packageName
            appInfo["activityName"] = app.activityInfo.name
            
            try {
                val icon = app.loadIcon(packageManager)
                val bitmap = drawableToBitmap(icon)
                val stream = ByteArrayOutputStream()
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
                val byteArray = stream.toByteArray()
                appInfo["icon"] = Base64.encodeToString(byteArray, Base64.NO_WRAP)
            } catch (e: Exception) {
                appInfo["icon"] = ""
            }
            
            appList.add(appInfo)
        }
        return appList
    }

    private fun drawableToBitmap(drawable: Drawable): Bitmap {
        if (drawable is android.graphics.drawable.BitmapDrawable) {
            return drawable.bitmap
        }
        val bitmap = Bitmap.createBitmap(
            drawable.intrinsicWidth.coerceAtLeast(1),
            drawable.intrinsicHeight.coerceAtLeast(1),
            Bitmap.Config.ARGB_8888
        )
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, canvas.width, canvas.height)
        drawable.draw(canvas)
        return bitmap
    }
}
