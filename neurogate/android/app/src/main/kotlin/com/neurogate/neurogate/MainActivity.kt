package com.neurogate.neurogate

import android.content.Intent
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.neurogate/apps"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getInstalledApps") {
                val apps = getInstalledApps()
                result.success(apps)
            } else if (call.method == "launchApp") {
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
            } else {
                result.notImplemented()
            }
        }
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
            appInfo["packageName"] = app.activityInfo.packageName
            appInfo["activityName"] = app.activityInfo.name
            appList.add(appInfo)
        }
        return appList
    }
}
