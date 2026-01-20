package com.example.myapplication.ui

import android.content.Intent
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.myapplication.data.WhitelistManager

@Composable
fun KidMode(onAppLaunch: (String) -> Unit, whitelistManager: WhitelistManager, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val packageManager = context.packageManager
    
    val apps = remember {
        val intent = Intent(Intent.ACTION_MAIN, null).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }
        val whitelist = whitelistManager.getWhitelist()
        packageManager.queryIntentActivities(intent, 0)
            .filter { whitelist.contains(it.activityInfo.packageName) }
            .map {
                AppInfo(
                    packageName = it.activityInfo.packageName,
                    label = it.loadLabel(packageManager).toString(),
                    icon = it.loadIcon(packageManager)
                )
            }.shuffled()
    }

    LazyColumn(
        modifier = modifier
            .fillMaxSize()
            .padding(horizontal = 32.dp, vertical = 64.dp)
    ) {
        items(apps) { app ->
            Text(
                text = app.label,
                fontSize = 28.sp,
                color = Color.White,
                modifier = Modifier
                    .padding(vertical = 12.dp)
                    .clickable {
                        onAppLaunch(app.packageName)
                        val launchIntent = packageManager.getLaunchIntentForPackage(app.packageName)
                        context.startActivity(launchIntent)
                    }
            )
        }
    }
}
