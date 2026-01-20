package com.example.myapplication.services

sealed class TimerState(val durationMinutes: Int, val isLockState: Boolean) {
    object HighOrbit : TimerState(25, false) // 25 Min Play
    object CorrectionBurn : TimerState(5, true) // 5 Min Lock
    object LowOrbit : TimerState(15, false) // 15 Min Play
    object DecayOrbit : TimerState(10, false) // 10 Min Play
    
    // Correction Burn 2 is same as Correction Burn 1, so we can reuse the object or create a new one if we need distinct ID.
    // The cycle is: High(25) -> Correction(5) -> Low(15) -> Correction(5) -> Decay(10) -> Correction(5) -> Decay(10)...
    // Actually the user said: "Loop: After State E (Decay), go to State D (Correction), then E again (5m Lock -> 10m Play loop)."
    // So the sequence is: High -> Correction -> Low -> Correction -> Decay -> Correction -> Decay ...
}
