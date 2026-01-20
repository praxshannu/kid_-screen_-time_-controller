package com.example.myapplication.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
fun ParentHomeScreen(
    onKidModeClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    // Colorful gradient background mimicking Image 1
    val backgroundBrush = Brush.verticalGradient(
        colors = listOf(
            Color(0xFF7B1FA2), // Purple top
            Color(0xFFE91E63), // Pink middle
            Color(0xFF2196F3), // Blue bottom
        )
    )

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(backgroundBrush)
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(top = 64.dp, start = 24.dp, end = 24.dp, bottom = 32.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            // Header: Date and Weather
            Column(
                modifier = Modifier.fillMaxWidth(),
                horizontalAlignment = Alignment.Start
            ) {
                Text(
                    text = "Wednesday, Jan 14",
                    color = Color.White,
                    fontSize = 20.sp,
                    fontWeight = FontWeight.Bold
                )
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        imageVector = Icons.Default.WbSunny,
                        contentDescription = null,
                        tint = Color.White,
                        modifier = Modifier.size(24.dp)
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = "72°F",
                        color = Color.White,
                        fontSize = 20.sp
                    )
                }
            }

            Spacer(modifier = Modifier.height(48.dp))

            // Main App Grid
            val mainApps = listOf(
                AppItemData("Kid Mode", Icons.Default.Face, Color(0xFFCE93D8), onKidModeClick),
                AppItemData("Photos", Icons.Default.Image, Color(0xFFFFF176)),
                AppItemData("Maps", Icons.Default.Place, Color(0xFF81C784)),
                AppItemData("Gmail", Icons.Default.Email, Color(0xFFE57373)),
                AppItemData("YouTube", Icons.Default.PlayArrow, Color(0xFFFF5252)),
                AppItemData("Music", Icons.Default.MusicNote, Color(0xFFFFB74D)),
                AppItemData("Calendar", Icons.Default.DateRange, Color(0xFF64B5F6)),
                AppItemData("Settings", Icons.Default.Settings, Color(0xFFBDBDBD))
            )

            LazyVerticalGrid(
                columns = GridCells.Fixed(4),
                modifier = Modifier.weight(1f),
                contentPadding = PaddingValues(vertical = 16.dp),
                verticalArrangement = Arrangement.spacedBy(24.dp),
                horizontalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                items(mainApps) { app ->
                    AppIcon(app)
                }
            }

            // Bottom Search Bar
            Surface(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp)
                    .padding(horizontal = 8.dp),
                shape = RoundedCornerShape(28.dp),
                color = Color.White.copy(alpha = 0.9f)
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(horizontal = 16.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(Icons.Default.Search, contentDescription = null, tint = Color.Gray)
                    Spacer(modifier = Modifier.width(12.dp))
                    Text(text = "Search...", color = Color.Gray, modifier = Modifier.weight(1f))
                    Icon(Icons.Default.Mic, contentDescription = null, tint = Color.Gray)
                    Spacer(modifier = Modifier.width(12.dp))
                    Icon(Icons.Default.CameraAlt, contentDescription = null, tint = Color.Gray)
                }
            }

            Spacer(modifier = Modifier.height(24.dp))

            // Dock
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 16.dp),
                horizontalArrangement = Arrangement.SpaceAround
            ) {
                val dockApps = listOf(
                    AppItemData("", Icons.Default.Call, Color(0xFF66BB6A)),
                    AppItemData("", Icons.Default.Chat, Color(0xFF42A5F5)),
                    AppItemData("", Icons.Default.Language, Color(0xFFFFCA28)),
                    AppItemData("", Icons.Default.CameraAlt, Color(0xFF263238))
                )
                dockApps.forEach { AppIcon(it, showLabel = false) }
            }
        }
    }
}

data class AppItemData(
    val label: String,
    val icon: ImageVector,
    val color: Color,
    val onClick: () -> Unit = {}
)

@Composable
fun AppIcon(app: AppItemData, showLabel: Boolean = true) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier.clickable { app.onClick() }
    ) {
        Surface(
            modifier = Modifier.size(56.dp),
            shape = CircleShape,
            color = app.color
        ) {
            Icon(
                imageVector = app.icon,
                contentDescription = app.label,
                modifier = Modifier
                    .padding(14.dp)
                    .fillMaxSize(),
                tint = Color.White
            )
        }
        if (showLabel) {
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = app.label,
                color = Color.White,
                fontSize = 12.sp,
                maxLines = 1
            )
        }
    }
}
