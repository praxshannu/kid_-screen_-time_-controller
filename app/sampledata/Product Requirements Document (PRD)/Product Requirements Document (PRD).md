# Product Requirements Document (PRD)  
**Project Name:** Kid Mode Chameleon Launcher (v2.0) **Version:** 2.0 (Draft) **Status:** Approved for Development **Author:**Senior Android Architect (AI Assistant) **Platform:** Android Native (Kotlin)  
  
## 1. Executive Summary  
The **Kid Mode Chameleon Launcher** is a dual-state Android Home application designed to replace the standard device interface. Unlike traditional "overlay" app lockers which are easily bypassed by restarting the device, this application functions as the default Android Launcher.  
It features a **"Smart Fatigue Timer"** (Pomodoro-style) that intersperses screen time with mandatory educational "Brain Breaks," and an **"AI Guardian"** that analyzes digital usage to suggest physical, real-world activities to parents.  
It features a **"Smart Fatigue Timer"** (Pomodoro-style) that intersperses screen time with mandatory educational "Brain Breaks," and an **"AI Guardian"** that analyzes digital usage to suggest physical, real-world activities to parents.  
  
## 2. Problem Statement & Solution  
* **The Problem:** Traditional parental control apps rely on background services that are killed by modern Android battery optimizations or bypassed via Safe Mode/Reboots. They also focus purely on *restriction* rather than *habit building*.  
* **The Solution:**  
    * **Architecture:** Acting as the Launcher ensures the app *is* the phone's interface. There is no "home" button to escape to.  
    * **Psychology:** Instead of a hard lock, the app uses a diminishing timer (25m -> 15m -> 10m) combined with educational content breaks to naturally reduce dopamine addiction.  
  
## 3. User Personas  
1. **The Guardian (Parent):** Wants a "set and forget" secure mode. Needs reassurance that the child isn't viewing harmful content and wants actionable advice on how to get their kid *off* the phone.  
2. **The Explorer (Child, Ages 4-10):** Wants to play games and watch videos. Dislikes hard blocks but is willing to tolerate short "breaks" to regain access.  
  
## 4. Technical Architecture (The Stack)  

| Component | Technology | Description |
| :--- | :--- | :--- |
| Language | Kotlin | Modern, null-safe Android development. |
| UI Framework | Jetpack Compose | For fluid, reactive UI in both Parent and Kid modes. |
| Architecture | MVVM | Clean separation of UI and Logic. |
| Local Data | EncryptedSharedPreferences | Security Critical. Stores flags like isKidModeActive and local timers. Encrypted via Android Keystore. |
| Cloud Data | Firebase Firestore | Offline-First Sync. Syncs settings (whitelist, timers) across devices. |
| Identity | Firebase Auth (Google) | Secure login for the Parent Dashboard. |
| AI Engine | Gemini Flash / GPT-4o-mini | Analyzing usage logs to generate natural language activity suggestions. |
| Video | ExoPlayer | For playing the cached "Brain Break" educational videos. |
  
Export to Sheets  
  
## 5. Functional Requirements  
## 5.1. The Chameleon Launcher (Core)  
* **FR-001 (Default Home):** App must register with android.intent.category.HOME.  
* **FR-002 (Dual State):**  
    * **Parent Mode:** Displays standard Android app drawer (or a polished custom UI). Full access to all apps.  
    * **Kid Mode:** Displays a simplified grid of *only* whitelisted apps. Hides Status Bar. Disables Notification Shade (if possible via Device Admin).  
* **FR-003 (The Vanish):** Upon activation of Kid Mode, the "Kid Mode App" icon must disappear from the grid to prevent tampering.  
## 5.2. Security & Locking  
* **FR-004 (The Secret Gesture):** A gesture detector must listen for **Triple Swipe (Right-to-Left)** on the bottom 20% of the screen to trigger the Exit PIN dialog.  
* **FR-005 (Persistence):** If the device reboots, the app must check the encrypted isKidModeActive flag. If true, it immediately launches in Kid Mode.  
* **FR-006 (App Installation):** If a new app is installed via Play Store auto-update while in Kid Mode, it must be automatically hidden/locked unless whitelisted.  
## 5.3. The "Smart Fatigue" Timer (Pomodoro Logic)  
* **FR-007 (Cycle Logic):**  
    * **Phase 1:** 25 Minutes Uninterrupted Play.  
    * **Phase 2:** 5 Minute "Brain Break" (Locked).  
    * **Phase 3:** 15 Minutes Play.  
    * **Phase 4:** 5 Minute "Brain Break" (Locked).  
    * **Phase 5:** 10 Minutes Play (Repeats hereafter).  
* **FR-008 (Soft Warning):** A "Toast" or banner must appear 60 seconds before a Break begins: *"1 Minute to Brain Break! Save your game!"*  
## 5.4. The "Brain Break" Module  
* **FR-009 (Video Enforcement):**  
    * Overlay screen covers the UI.  
    * Plays educational video based on Child's Interests (defined in Onboarding).  
    * "Skip" button is **disabled** for the first 50% of video duration.  
* **FR-010 (Content Buffer):** App must cache 3-5 videos over Wi-Fi to ensure breaks work offline.  
## 5.5. AI Guardian & Insights  
* **FR-011 (Usage Tracking):** App logs usage time per category (e.g., "Gaming", "Education", "Video").  
* **FR-012 (AI Prompting):** Once per day, send usage summary to Backend.  
    * *Input:* "Child played Minecraft (Creative) for 45m."  
    * *Output:* "Suggestion: Build a cardboard fort in the living room."  
* **FR-013 (Parent Dashboard):** Display these tips in a "Daily Insights" card.  
  
## 6. Non-Functional Requirements (Performance & Safety)  
* **NFR-001 (Latency):** The "Block" screen for non-whitelisted apps must render within **200ms**.  
* **NFR-002 (Battery):** Background monitoring must consume < 3% battery per charge cycle.  
* **NFR-003 (Privacy):** No camera/microphone data is ever accessed. Usage logs are anonymized before AI processing.  
* **NFR-004 (Offline Capable):** Core blocking and Timer features must function 100% without internet.  
  
## 7. User Interface (UI) Guidelines  
* **Kid Mode:**  
    * **Grid:** Large icons (4 columns), rounded corners.  
    * **Wallpaper:** customizable or default "Playful" theme.  
    * **Break Screen:** Calming colors (Pastel Blue/Green) to lower stimulation. *Avoid aggressive Red/Yellow.*  
* **Parent Dashboard:**  
    * Clean, professional "Settings" style. Dark Mode support.  
    * Data visualization (Bar charts for screen time).  
  
## 8. Data Model (Schema Draft)  
**User Profile (Firestore/Local Encrypted):**  
JSON  
  
```
{
  "child_name": "Alex",
  "dob": "2018-05-20",
  "interests": ["Dinosaurs", "Space", "Drawing"],
  "settings": {
    "strict_mode": true,
    "daily_limit_min": 120,
    "whitelisted_packages": [
      "com.google.android.youtube.kids",
      "com.mojang.minecraftpe"
    ]
  },
  "state": {
    "current_timer_cycle": "25m",
    "is_locked": true
  }
}

```
  
## 9. Implementation Roadmap  
## Phase 1: The Foundation  
* Build Basic Launcher (Home Intent).  
* Implement App Drawer (List installed apps).  
* Implement "Kid Grid" (Whitelist logic).  
## Phase 2: The Security  
* Implement EncryptedSharedPreferences.  
* Implement "Triple Swipe" gesture & PIN dialog.  
* Implement BOOT_COMPLETED receiver.  
## Phase 3: The Logic  
* Build the Timer Engine (Service).  
* Implement the "Brain Break" Video Overlay (ExoPlayer).  
* Add Soft Warnings.  
## Phase 4: The Intelligence  
* Integrate Firebase Auth & Firestore.  
* Build "Usage Stats" Aggregator.  
* Connect Gemini/OpenAI API for suggestions.  
  
## End of Document  
