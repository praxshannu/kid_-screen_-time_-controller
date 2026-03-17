package com.neurogate.neurogate

import android.annotation.SuppressLint
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.*
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import android.view.*
import android.widget.FrameLayout

class FloatingTimerService : Service() {
    private var windowManager: WindowManager? = null
    private var floatingView: FrameLayout? = null
    private var timerCanvas: TimerCanvasView? = null

    private var remainingSeconds: Int = 0
    private var totalSeconds: Int = 0
    private val handler = Handler(Looper.getMainLooper())
    private var countdownRunnable: Runnable? = null
    private var isRunning = false

    companion object {
        var instance: FloatingTimerService? = null
        const val ACTION_START = "com.neurogate.START_TIMER"
        const val ACTION_STOP = "com.neurogate.STOP_TIMER"
        const val ACTION_GET_REMAINING = "com.neurogate.GET_REMAINING"
        const val TAG = "FloatingTimer"
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "onStartCommand: action=${intent?.action}")

        when (intent?.action) {
            ACTION_STOP -> {
                stopCountdown()
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_GET_REMAINING -> {
                // Just return, we'll query via method channel
                return START_STICKY
            }
        }

        // Default: START — create overlay and begin countdown
        val newRemaining = intent?.getIntExtra("remaining", 0) ?: 0
        val newTotal = intent?.getIntExtra("total", 1)?.coerceAtLeast(1) ?: 1

        remainingSeconds = newRemaining
        totalSeconds = newTotal
        instance = this

        Log.d(TAG, "Starting overlay: remaining=${remainingSeconds}s, total=${totalSeconds}s")

        if (floatingView == null) {
            createOverlay()
        }

        timerCanvas?.updateTime(remainingSeconds, totalSeconds)

        if (!isRunning) {
            startCountdown()
        }

        return START_STICKY
    }

    @SuppressLint("ClickableViewAccessibility")
    private fun createOverlay() {
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        val density = resources.displayMetrics.density
        val size = (64 * density).toInt()

        val params = WindowManager.LayoutParams(
            size, size,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        )
        params.gravity = Gravity.TOP or Gravity.END
        params.x = (16 * density).toInt()
        params.y = (200 * density).toInt()

        floatingView = FrameLayout(this)
        timerCanvas = TimerCanvasView(this, remainingSeconds, totalSeconds)
        floatingView!!.addView(timerCanvas, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        ))

        // Dragging + Tap
        var initialX = 0
        var initialY = 0
        var initialTouchX = 0f
        var initialTouchY = 0f
        var hasMoved = false

        floatingView!!.setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    initialX = params.x
                    initialY = params.y
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    hasMoved = false
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = (initialTouchX - event.rawX).toInt()
                    val dy = (event.rawY - initialTouchY).toInt()
                    if (Math.abs(dx) > 10 || Math.abs(dy) > 10) hasMoved = true
                    params.x = initialX + dx
                    params.y = initialY + dy
                    try {
                        windowManager?.updateViewLayout(floatingView, params)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error updating layout: ${e.message}")
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (!hasMoved) {
                        // Tap → bring NeuroGate to foreground
                        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
                        launchIntent?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                        launchIntent?.putExtra("triggerChallenge", true)
                        launchIntent?.putExtra("remainingSeconds", remainingSeconds)
                        startActivity(launchIntent)
                    }
                    true
                }
                else -> false
            }
        }

        try {
            windowManager?.addView(floatingView, params)
            Log.d(TAG, "Overlay view added successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Error adding overlay: ${e.message}")
        }
    }

    private fun startCountdown() {
        isRunning = true
        countdownRunnable = object : Runnable {
            override fun run() {
                if (remainingSeconds > 0) {
                    remainingSeconds--
                    timerCanvas?.updateTime(remainingSeconds, totalSeconds)

                    // Save remaining time to SharedPreferences so Flutter can read it
                    val prefs = getSharedPreferences("neurogate_timer", Context.MODE_PRIVATE)
                    prefs.edit().putInt("remainingSeconds", remainingSeconds).apply()

                    if (remainingSeconds <= 0) {
                        // TIME'S UP! Send user home
                        Log.d(TAG, "Time's up! Sending user home")
                        sendUserHome()
                        stopCountdown()
                        removeOverlay()
                        return
                    }

                    handler.postDelayed(this, 1000)
                }
            }
        }
        handler.postDelayed(countdownRunnable!!, 1000)
    }

    private fun stopCountdown() {
        isRunning = false
        countdownRunnable?.let { handler.removeCallbacks(it) }
        countdownRunnable = null
    }

    private fun sendUserHome() {
        val homeIntent = Intent(Intent.ACTION_MAIN)
        homeIntent.addCategory(Intent.CATEGORY_HOME)
        homeIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        startActivity(homeIntent)
    }

    private fun removeOverlay() {
        try {
            if (floatingView != null) {
                windowManager?.removeView(floatingView)
                floatingView = null
                timerCanvas = null
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error removing overlay: ${e.message}")
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "Service destroyed")
        instance = null
        stopCountdown()
        removeOverlay()
    }
}

/**
 * Custom View that draws the circular timer with progress ring.
 */
class TimerCanvasView(context: android.content.Context, private var remaining: Int, private var total: Int) :
    View(context) {

    private val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#DD1E293B")
        style = Paint.Style.FILL
    }

    private val ringBgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#33FFFFFF")
        style = Paint.Style.STROKE
        strokeWidth = 6f
    }

    private val ringPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 6f
        strokeCap = Paint.Cap.ROUND
    }

    private val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        textAlign = Paint.Align.CENTER
        typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
    }

    private val iconPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        textAlign = Paint.Align.CENTER
    }

    fun updateTime(newRemaining: Int, newTotal: Int) {
        remaining = newRemaining
        total = newTotal
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val cx = width / 2f
        val cy = height / 2f
        val radius = (Math.min(width, height) / 2f) - 4f

        // Determine state colors
        val color = when {
            remaining <= 60 -> Color.parseColor("#FF4444")   // Critical red
            remaining <= 180 -> Color.parseColor("#FFB300")  // Warning amber
            else -> Color.parseColor("#00BCD4")              // Normal cyan
        }

        // Background circle with glow for critical
        if (remaining <= 60) {
            val glowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                this.color = Color.parseColor("#44FF4444")
                style = Paint.Style.FILL
                maskFilter = BlurMaskFilter(16f, BlurMaskFilter.Blur.OUTER)
            }
            setLayerType(LAYER_TYPE_SOFTWARE, null)
            canvas.drawCircle(cx, cy, radius + 4, glowPaint)
        }

        canvas.drawCircle(cx, cy, radius, bgPaint)

        // Ring background
        val ringRect = RectF(cx - radius + 6, cy - radius + 6, cx + radius - 6, cy + radius - 6)
        canvas.drawArc(ringRect, -90f, 360f, false, ringBgPaint)

        // Progress ring
        ringPaint.color = color
        val progress = if (total > 0) (remaining.toFloat() / total) * 360f else 0f
        canvas.drawArc(ringRect, -90f, progress, false, ringPaint)

        // Time text
        val timeText = if (remaining >= 60) "${remaining / 60}m" else "${remaining}s"
        textPaint.textSize = radius * 0.55f
        textPaint.color = color
        canvas.drawText(timeText, cx, cy + (textPaint.textSize / 3), textPaint)

        // Lightning icon for critical state
        if (remaining <= 60) {
            iconPaint.textSize = radius * 0.35f
            canvas.drawText("⚡", cx, cy - radius * 0.3f, iconPaint)
        }
    }
}
