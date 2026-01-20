package com.example.myapplication

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Bundle
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Dashboard
import androidx.compose.material.icons.filled.ExitToApp
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.media3.common.util.UnstableApi
import com.example.myapplication.data.SecureStorageManager
import com.example.myapplication.data.WhitelistManager
import com.example.myapplication.services.TimerService
import com.example.myapplication.ui.AppList
import com.example.myapplication.ui.BrainBreakScreen
import com.example.myapplication.ui.KidMode
import com.example.myapplication.ui.ParentDashboard
import com.example.myapplication.ui.theme.MyApplicationTheme

@UnstableApi
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val whitelistManager = WhitelistManager(this)
        val secureStorageManager = SecureStorageManager(this)

        enableEdgeToEdge()
        setContent {
            MyApplicationTheme {
                var isKidMode by remember { mutableStateOf(secureStorageManager.isKidModeActive()) }
                var showPinDialog by remember { mutableStateOf(false) }
                var showBrainBreak by remember { mutableStateOf(false) }
                var showDashboard by remember { mutableStateOf(false) }
                var showOnboarding by remember { mutableStateOf(!secureStorageManager.isSetupComplete()) }

                DisposableEffect(Unit) {
                    val receiver = object : BroadcastReceiver() {
                        override fun onReceive(context: Context, intent: Intent) {
                            when (intent.action) {
                                TimerService.ACTION_GRAVITY_WARNING -> {
                                    Toast.makeText(context, "1 Minute to Brain Break! Save your game!", Toast.LENGTH_LONG).show()
                                }
                                TimerService.ACTION_INITIATE_LOCK -> {
                                    showBrainBreak = true
                                }
                                TimerService.ACTION_RELEASE_LOCK -> {
                                    showBrainBreak = false
                                }
                            }
                        }
                    }
                    val filter = IntentFilter().apply {
                        addAction(TimerService.ACTION_GRAVITY_WARNING)
                        addAction(TimerService.ACTION_INITIATE_LOCK)
                        addAction(TimerService.ACTION_RELEASE_LOCK)
                    }
                    
                    ContextCompat.registerReceiver(
                        this@MainActivity,
                        receiver,
                        filter,
                        ContextCompat.RECEIVER_NOT_EXPORTED
                    )
                    
                    onDispose {
                        unregisterReceiver(receiver)
                    }
                }

                if (showOnboarding) {
                    OnboardingScreen(
                        onComplete = { pin ->
                            secureStorageManager.setParentPin(pin)
                            secureStorageManager.setSetupComplete(true)
                            showOnboarding = false
                        }
                    )
                } else if (showPinDialog) {
                    PinDialog(
                        correctPin = secureStorageManager.getParentPin(),
                        onDismiss = { showPinDialog = false },
                        onPinVerified = {
                            isKidMode = false
                            secureStorageManager.setKidModeActive(false)
                            showPinDialog = false
                            stopLockTask()
                            stopService(Intent(this@MainActivity, TimerService::class.java))
                        }
                    )
                } else {
                    Box(modifier = Modifier
                        .fillMaxSize()
                        .background(if (isKidMode) Color.Black else MaterialTheme.colorScheme.background)
                    ) {
                        if (isKidMode) {
                            KidMode(
                                onAppLaunch = { startLockTask() },
                                whitelistManager = whitelistManager
                            )
                            
                            IconButton(
                                onClick = { showPinDialog = true },
                                modifier = Modifier
                                    .align(Alignment.TopStart)
                                    .padding(16.dp)
                            ) {
                                Icon(
                                    Icons.Default.ExitToApp, 
                                    contentDescription = "Exit Kid Mode",
                                    tint = Color.Gray,
                                    modifier = Modifier.size(32.dp)
                                )
                            }
                        } else {
                            if (showDashboard) {
                                // "Antigravity App" - The Guardian Console
                                ParentDashboard(
                                    whitelistManager = whitelistManager,
                                    onLaunchKidMode = {
                                        isKidMode = true
                                        secureStorageManager.setKidModeActive(true)
                                        showDashboard = false // Reset dashboard state
                                        startService(Intent(this@MainActivity, TimerService::class.java))
                                    },
                                    onBack = { showDashboard = false }
                                )
                            } else {
                                // "Parent Mode" - The Default Launcher style
                                com.example.myapplication.ui.ParentHomeScreen(
                                    onKidModeClick = { showDashboard = true }
                                )
                            }
                        }
                        
                        if (showBrainBreak) {
                            BrainBreakScreen()
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun OnboardingScreen(onComplete: (String) -> Unit) {
    var pin by remember { mutableStateOf("") }
    var name by remember { mutableStateOf("") }

    Column(
        modifier = Modifier.fillMaxSize().padding(32.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text("Welcome to Chameleon Launcher", style = MaterialTheme.typography.headlineMedium)
        Spacer(Modifier.height(16.dp))
        OutlinedTextField(value = name, onValueChange = { name = it }, label = { Text("Child's Name") })
        Spacer(Modifier.height(16.dp))
        OutlinedTextField(value = pin, onValueChange = { if(it.length <= 4) pin = it }, label = { Text("Set 4-digit Parent PIN") })
        Spacer(Modifier.height(32.dp))
        Button(
            onClick = { if(pin.length == 4) onComplete(pin) },
            enabled = pin.length == 4 && name.isNotEmpty()
        ) {
            Text("Complete Setup")
        }
    }
}

@Composable
fun PinDialog(correctPin: String, onDismiss: () -> Unit, onPinVerified: () -> Unit) {
    var pin by remember { mutableStateOf("") }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Enter PIN") },
        text = {
            Column {
                Text("Enter the 4-digit PIN.")
                Spacer(modifier = Modifier.height(16.dp))
                OutlinedTextField(
                    value = pin,
                    onValueChange = { if(it.length <= 4) pin = it },
                    label = { Text("PIN") }
                )
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    if (pin == correctPin) {
                        onPinVerified()
                    } else {
                        onDismiss()
                    }
                }
            ) {
                Text("Confirm")
            }
        },
        dismissButton = {
            Button(onClick = onDismiss) {
                Text("Cancel")
            }
        }
    )
}
