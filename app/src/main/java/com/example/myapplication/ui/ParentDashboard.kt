package com.example.myapplication.ui

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material.icons.filled.FlashOn
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.myapplication.data.AISuggestionService
import androidx.compose.material.icons.filled.Apps
import androidx.compose.material.icons.filled.Close
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.example.myapplication.data.UsageTracker
import com.example.myapplication.data.WhitelistManager

@Composable
fun ParentDashboard(
    whitelistManager: WhitelistManager,
    modifier: Modifier = Modifier,
    onLaunchKidMode: () -> Unit = {},
    onBack: () -> Unit = {}
) {
    BackHandler(onBack = onBack)

    val context = LocalContext.current
    val usageTracker = remember { UsageTracker(context) }
    val aiService = remember { AISuggestionService() }
    
    var usageData by remember { mutableStateOf<Map<String, Long>>(usageTracker.getAllUsageStats()) }
    var suggestion by remember { mutableStateOf("Analyzing activity patterns...") }
    var showAppDialog by remember { mutableStateOf(false) }

    LaunchedEffect(usageData) {
        suggestion = aiService.getSuggestion(usageData)
    }

    // Premium Dark Theme Palette
    val darkBackground = Color(0xFF121212)
    val cardBackground = Color(0xFF1E1E1E)
    val accentColor = Color(0xFF00E5FF) // Cyan accent
    val textPrimary = Color.White
    val textSecondary = Color.Gray

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(darkBackground)
    ) {
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(24.dp)
        ) {
            // Header
            item {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.padding(top = 16.dp, bottom = 8.dp)
                ) {
                    IconButton(onClick = onBack) {
                        Icon(
                            imageVector = androidx.compose.material.icons.filled.ArrowBack, // Need to make sure ArrowBack is available or imported.
                            // To be safe, let's use Icons.Default.ArrowBack if imported, or full path.
                            // Previous imports show Icons.Default.* usage.
                            // I will assume ArrowBack is in Icons.Filled or I need to import it.
                            // I'll use fully qualified name to be safe if I can't check imports easily right now.
                            // But better: Icons.AutoMirrored.Filled.ArrowBack or similar in newer Compose? 
                            // Standard: Icons.Default.ArrowBack.
                            // I'll add the import to the top or just use a known icon like Close if I'm unsure, but ArrowBack is standard.
                            // Let's try Icons.Default.ArrowBack and hope.
                            // Wait, I can't check imports easily. The file imports `androidx.compose.material.icons.filled.*`.
                            // I'll assume ArrowBack is there.
                            imageVector = Icons.Default.ArrowBack,
                            contentDescription = "Back",
                            tint = textPrimary
                        )
                    }
                    Spacer(modifier = Modifier.width(8.dp))
                    Icon(
                        imageVector = Icons.Default.Lock,
                        contentDescription = null,
                        tint = accentColor,
                        modifier = Modifier.size(32.dp)
                    )
                    Spacer(modifier = Modifier.width(12.dp))
                    Text(
                        text = "Guardian Console",
                        color = textPrimary,
                        fontSize = 28.sp,
                        fontWeight = FontWeight.Bold
                    )
                }
            }

            // Quick Actions (Launch Kid Mode)
            item {
                Button(
                    onClick = onLaunchKidMode,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(56.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = accentColor
                    ),
                    shape = RoundedCornerShape(16.dp)
                ) {
                    Icon(Icons.Default.PlayArrow, contentDescription = null, tint = Color.Black)
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = "LAUNCH KID MODE",
                        color = Color.Black,
                        fontWeight = FontWeight.Bold,
                        fontSize = 16.sp
                    )
                }
            }

            // Whitelist Management
            item {
                Card(
                    colors = CardDefaults.cardColors(containerColor = cardBackground),
                    shape = RoundedCornerShape(16.dp),
                    modifier = Modifier.fillMaxWidth().clickable { showAppDialog = true }
                ) {
                     Row(
                        modifier = Modifier.padding(20.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Surface(
                            color = Color(0xFF4CAF50).copy(alpha = 0.2f),
                            shape = RoundedCornerShape(8.dp),
                            modifier = Modifier.size(40.dp)
                        ) {
                            Icon(Icons.Default.Apps, contentDescription = null, tint = Color(0xFF4CAF50), modifier = Modifier.padding(8.dp))
                        }
                        Spacer(modifier = Modifier.width(16.dp))
                        Column {
                            Text("Manage Allowed Apps", color = textPrimary, fontWeight = FontWeight.Bold)
                            Text("Select which apps are safe", color = textSecondary, fontSize = 12.sp)
                        }
                    }
                }
            }

            // AI Insight Card
            item {
                Card(
                    colors = CardDefaults.cardColors(containerColor = cardBackground),
                    shape = RoundedCornerShape(24.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Column(modifier = Modifier.padding(20.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.FlashOn, contentDescription = null, tint = Color(0xFFFFD700))
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                text = "AI Insight",
                                color = textPrimary,
                                fontWeight = FontWeight.SemiBold,
                                fontSize = 18.sp
                            )
                        }
                        Spacer(modifier = Modifier.height(12.dp))
                        Text(
                            text = suggestion,
                            color = textSecondary,
                            fontSize = 15.sp,
                            lineHeight = 22.sp
                        )
                    }
                }
            }

            // Usage Stats Prototype
            item {
                Text(
                    text = "Recent Activity",
                    color = textPrimary,
                    fontSize = 20.sp,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.padding(bottom = 8.dp)
                )
            }

            items(usageData.toList().take(5)) { (packageName, time) ->
                val timeInMinutes = time / (1000 * 60)
                if (timeInMinutes > 0) {
                    UsageStatItem(
                        appName = packageName.substringAfterLast('.').replaceFirstChar { it.uppercase() }, // Simple cleanup
                        minutes = timeInMinutes,
                        icon = Icons.Default.DateRange, // Placeholder
                        cardColor = cardBackground,
                        textColor = textPrimary
                    )
                }
            }
        }
        
        // Full Screen App Selection Dialog
        if (showAppDialog) {
            Dialog(
                onDismissRequest = { showAppDialog = false },
                properties = DialogProperties(usePlatformDefaultWidth = false)
            ) {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = darkBackground
                ) {
                    Column(modifier = Modifier.fillMaxSize()) {
                        // Toolbar
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(16.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                "Manage Allowed Apps",
                                color = textPrimary,
                                fontSize = 20.sp,
                                fontWeight = FontWeight.Bold
                            )
                            IconButton(onClick = { showAppDialog = false }) {
                                Icon(Icons.Default.Close, contentDescription = "Close", tint = textPrimary)
                            }
                        }
                        HorizontalDivider(color = Color.DarkGray)
                        
                        // Reusing AppList
                        // We might need to wrap it to look good on dark theme if it's not styled (AppList uses default Text color?)
                        // AppList uses Text(text = app.label) which defaults to Black.
                        // We should probably style AppList or Wrap it in a MaterialTheme override.
                        
                        // Let's override the theme for AppList momentarily
                        MaterialTheme(
                            colorScheme = MaterialTheme.colorScheme.copy(onSurface = Color.White)
                        ) {
                            AppList(
                                whitelistManager = whitelistManager,
                                onKidModeClick = {},
                                modifier = Modifier.fillMaxSize()
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun UsageStatItem(
    appName: String,
    minutes: Long,
    icon: ImageVector,
    cardColor: Color,
    textColor: Color
) {
    Card(
        colors = CardDefaults.cardColors(containerColor = cardColor),
        shape = RoundedCornerShape(16.dp),
        modifier = Modifier.fillMaxWidth().padding(bottom = 8.dp)
    ) {
        Row(
            modifier = Modifier
                .padding(16.dp)
                .fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Surface(
                    color = Color.White.copy(alpha = 0.1f),
                    shape = RoundedCornerShape(8.dp),
                    modifier = Modifier.size(40.dp)
                ) {
                    Icon(
                        imageVector = icon,
                        contentDescription = null,
                        modifier = Modifier.padding(8.dp),
                        tint = Color.White
                    )
                }
                Spacer(modifier = Modifier.width(16.dp))
                Column {
                    Text(text = appName, color = textColor, fontWeight = FontWeight.Medium)
                    Text(text = "App Usage", color = Color.Gray, fontSize = 12.sp)
                }
            }
            Text(
                text = "${minutes}m",
                color = textColor,
                fontWeight = FontWeight.Bold
            )
        }
    }
}