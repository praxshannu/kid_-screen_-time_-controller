package com.example.myapplication.ui

import android.content.Intent
import android.content.pm.PackageManager
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.Image
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.graphics.Color
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import coil.compose.rememberAsyncImagePainter
import com.example.myapplication.data.WhitelistManager

data class AppInfo(
    val packageName: String,
    val label: String,
    val icon: android.graphics.drawable.Drawable
)

@Composable
@Composable
fun AppList(
    whitelistManager: WhitelistManager, 
    onKidModeClick: () -> Unit, 
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    val packageManager = context.packageManager
    val apps = remember {
        val intent = Intent(Intent.ACTION_MAIN, null).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }
        val allApps = packageManager.queryIntentActivities(intent, 0).map {
            AppInfo(
                packageName = it.activityInfo.packageName,
                label = it.loadLabel(packageManager).toString(),
                icon = it.loadIcon(packageManager)
            )
        }.toMutableList()
        
        // Add Antigravity Dashboard as the first item
        val dashboardApp = AppInfo(
            packageName = "com.antigravity.dashboard",
            label = "Antigravity",
            icon = context.getDrawable(android.R.drawable.sym_def_app_icon)!! // Fallback or use R.mipmap.ic_launcher if available
        )
        allApps.add(0, dashboardApp)
        allApps
    }

    LazyVerticalGrid(
        columns = GridCells.Fixed(4), // 4 columns looks more like a launcher
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
        horizontalArrangement = Arrangement.spacedBy(16.dp),
        modifier = modifier
    ) {
        items(apps) { app ->
            if (app.packageName == "com.antigravity.dashboard") {
               DashboardIcon(app = app, onClick = onKidModeClick)
            } else {
               AppIcon(app = app, whitelistManager = whitelistManager)
            }
        }
    }
}

@Composable
fun DashboardIcon(app: AppInfo, onClick: () -> Unit) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier.clickable { onClick() }
    ) {
        Surface(
            modifier = Modifier.size(56.dp),
             shape = androidx.compose.foundation.shape.CircleShape,
            color = Color(0xFF00E5FF) // Cyan for Antigravity
        ) {
             // You might want an icon here, using the app.icon for now or a hardcoded one
             // Image(...)
             Icon(
                imageVector = androidx.compose.material.icons.Icons.Default.Dashboard,
                contentDescription = "Antigravity",
                modifier = Modifier.padding(12.dp),
                tint = Color.Black
             )
        }
        Spacer(modifier = Modifier.height(4.dp))
        Text(
            text = app.label,
            color = Color.White,
            style = MaterialTheme.typography.bodySmall,
            maxLines = 1,
            overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis
        )
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun AppIcon(app: AppInfo, whitelistManager: WhitelistManager, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    var isWhitelisted by remember { mutableStateOf(whitelistManager.getWhitelist().contains(app.packageName)) }

    // Card-based design for apps
    Card(
        colors = CardDefaults.cardColors(
            containerColor = if (isWhitelisted) Color(0xFF00E5FF).copy(alpha = 0.15f) else Color(0xFF1E1E1E)
        ),
        border = if (isWhitelisted) androidx.compose.foundation.BorderStroke(1.dp, Color(0xFF00E5FF)) else null,
        modifier = modifier
            .fillMaxWidth()
            .aspectRatio(0.85f)
            .combinedClickable(
                onClick = {
                    val launchIntent = context.packageManager.getLaunchIntentForPackage(app.packageName)
                    if (launchIntent != null) {
                       context.startActivity(launchIntent)
                    }
                },
                onLongClick = {
                    if (isWhitelisted) {
                        whitelistManager.removeFromWhitelist(app.packageName)
                    } else {
                        whitelistManager.addToWhitelist(app.packageName)
                    }
                    isWhitelisted = !isWhitelisted
                }
            )
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(12.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Image(
                painter = rememberAsyncImagePainter(model = app.icon),
                contentDescription = app.label,
                modifier = Modifier.size(48.dp)
            )
            Spacer(modifier = Modifier.height(12.dp))
            Text(
                text = app.label,
                color = Color.White,
                style = MaterialTheme.typography.bodyMedium,
                maxLines = 1,
                overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis
            )
            Spacer(modifier = Modifier.height(8.dp))
            Checkbox(
                checked = isWhitelisted,
                onCheckedChange = { checked ->
                    if (checked) {
                        whitelistManager.addToWhitelist(app.packageName)
                    } else {
                        whitelistManager.removeFromWhitelist(app.packageName)
                    }
                    isWhitelisted = checked
                },
                colors = CheckboxDefaults.colors(
                    checkedColor = Color(0xFF00E5FF),
                    uncheckedColor = Color.Gray,
                    checkmarkColor = Color.Black
                )
            )
        }
    }
}
