# Chapter 4: Implementation / Methodology

## 4.1 Detailed Explanation of Implementation

### 4.1.1 Core System Architecture

Neurogate implements a **Time Bank + Cognitive Toll** system where parental controls operate through a dopamine-tax mechanism. The fundamental flow is:

```
User Launches App 
    ↓
Check App Tag (Taxed/Free/Blocked)
    ↓
├─ BLOCKED → Show snackbar, deny launch
├─ FREE → Launch immediately, no time deduction
└─ TAXED → Check time bank balance
    ├─ Has time → Launch app + start overlay timer countdown
    └─ No time → Show InterceptorDialog (cognitive toll required)
        ├─ Age 3-5/6-8: Object Hunt challenge (camera + AI vision)
        ├─ Age 9-12: Trivia question challenge
        └─ Age 13-16: Intent evaluation dialogue
        └─ Success → Add exchange_rate minutes to time bank
```

### 4.1.2 State Management: AppState (Central Hub)

The `AppState` class extends `ChangeNotifier` and serves as the single source of truth for all application state:

```dart
class AppState extends ChangeNotifier {
  // Primary State Variables
  int _timeBank = 0;              // Minutes (displayed to user)
  int _timeBankSeconds = 0;       // Seconds (working countdown)
  String _ageGroup = '9-12';      // Developmental stage
  int _exchangeRate = 15;         // Minutes granted after toll success
  String _googleAccessToken = ''; // OAuth token
  String _parentPin = '0000';     // Default PIN for parent panel
  Map<String, String> _appTags;   // Package → "taxed"/"free"/"blocked"
  
  // Persistence Layer
  late SharedPreferences _prefs;  // Local key-value store
}
```

**Core Responsibilities:**
- Persists application state across app sessions via SharedPreferences
- Provides getters/setters that trigger `notifyListeners()` for reactive UI updates
- Manages app-to-tag mappings for access control
- Coordinates with native Android layer for overlay timing
- Supplies Gemini API key for cognitive toll challenges

**Key Operations:**

| Operation | Method | Effect |
|-----------|--------|--------|
| Load state | `init()` | Reads from SharedPreferences, initializes variables |
| Adjust time | `setTimeBank(minutes)` | Updates both `_timeBank` and `_timeBankSeconds` |
| Add time | `addTime(minutes)` | Calls `setTimeBank(_timeBank + minutes)` |
| Remove time | `subtractTime(minutes)` | Calls `setTimeBank(_timeBank - minutes)` with floor at 0 |
| Tag app | `setAppTag(packageName, tag)` | Maps package → "taxed"/"free"/"blocked" |
| Get tag | `getAppTag(packageName)` | Returns `AppTag` enum |
| Change age | `setAgeGroup(newGroup)` | Updates developmental stage trigger for tolls |
| Update PIN | `setParentPin(pin)` | Sets parent panel authentication code |
| Sync overlay | `syncRemainingTime()` | Retrieves countdown value from native service |

### 4.1.3 Authentication Flow (Google OAuth)

**LoginScreen Initialization:**

The application starts by checking authentication status in `main.dart`:

```dart
Consumer<AppState>(
  builder: (context, appState, _) {
    if (!appState.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    
    if (appState.googleAccessToken.isEmpty) {
      return const LoginScreen();  // No token → Show login
    }
    
    return const MainNavigator();  // Token exists → Show app
  },
)
```

**OAuth Flow Steps:**

1. **Initialization** (LoginScreen.initState):
   ```dart
   _googleSignIn = GoogleSignIn(
     serverClientId: '86841428362-n7hnl1itoe4onhfc1envlt7eo27ibgkd.apps.googleusercontent.com',
     scopes: ['email'],
   );
   ```

2. **User Triggers Sign-In**: Taps "Authorize with Google" button

3. **Sign-In Process**:
   ```dart
   final account = await _googleSignIn.signIn();
   // Opens native Google account picker
   // User selects account and grants consent
   ```

4. **Token Extraction**:
   ```dart
   final auth = await account.authentication;
   final token = auth.accessToken;  // OAuth access token
   ```

5. **Persistence**:
   ```dart
   await appState.setGoogleAccessToken(token);
   // Stores in AppState → SharedPreferences as 'googleToken'
   ```

6. **Navigation**: Automatically navigates to `MainNavigator` (HomeTab + ParentPanel)

**Error Handling:**
- ApiException 7 → "Network error. Check internet and Google Play Services"
- ApiException 10 → "SHA-1 fingerprint mismatch. Contact developer"
- ApiException 12500 → "Update Google Play Services to latest version"

### 4.1.4 Platform Integration via MethodChannel

Neurogate communicates with native Android code via Flutter's communication layer:

```dart
const platform = MethodChannel('com.neurogate/apps');
```

This channel enables:

| Method | Input | Output | Purpose |
|--------|-------|--------|---------|
| `getInstalledApps` | none | `List<Map>` | Fetches all device apps |
| `launchApp` | `{packageName}` | void | Launches app by ID |
| `startOverlay` | `{remaining: int, total: int}` | void | Starts visual countdown |
| `stopOverlay` | none | void | Stops overlay timer |
| `canDrawOverlays` | none | `bool` | Checks permission status |
| `requestOverlayPermission` | none | void | Prompts for permission |
| `getRemainingSeconds` | none | `int` | Gets live countdown value |

**Data Format for Installed Apps:**

```dart
List<Map<dynamic, dynamic>> {
  {
    'name': 'YouTube',
    'packageName': 'com.google.android.youtube',
    'icon': '[base64-encoded PNG data]'
  },
  // ... more apps
}
```

**Overlay Lifecycle:**

```
_launchApp(packageName, isTaxed: true)
  ↓
platform.invokeMethod('launchApp', {'packageName': packageName})
  ↓
[App launches]
  ↓
appState.startOverlayTimer()
  ↓
platform.invokeMethod('startOverlay', 
    {'remaining': _timeBankSeconds, 'total': _timeBankSeconds})
  ↓
[Native service counts down on separate thread]
  ↓
[User returns to NeuroGate]
  ↓
didChangeAppLifecycleState(AppLifecycleState.resumed)
  ↓
appState.syncRemainingTime()
  ↓
platform.invokeMethod('getRemainingSeconds')
  ↓
[Update UI and SharedPreferences]
```

### 4.1.5 App Launch Logic

**Launch Decision Tree (HomeTab._handleAppLaunch):**

```dart
void _handleAppLaunch(Map<dynamic, dynamic> app, AppState appState) {
  final String packageName = app['packageName'];
  final tag = appState.getAppTag(packageName);

  switch (tag) {
    case AppTag.blocked:
      // Completely blocked
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            Icon(Icons.block, color: Colors.white),
            SizedBox(width: 10),
            Text('This app has been blocked by your parent.'),
          ]),
          backgroundColor: Colors.redAccent.shade700,
        ),
      );
      return;

    case AppTag.free:
      // No restrictions
      _launchApp(packageName, appState, isTaxed: false);
      return;

    case AppTag.taxed:
      // Requires time bank
      if (appState.timeBankSeconds <= 0) {
        // No time available → Show cognitive toll
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => InterceptorDialog(
            targetApp: app,
            onSuccess: () {
              _launchApp(packageName, appState, isTaxed: true);
            },
          ),
        );
      } else {
        // Has time → Launch immediately
        _launchApp(packageName, appState, isTaxed: true);
      }
  }
}
```

**Grid Display (HomeTab UI):**
- 4-column layout with aspect ratio 0.7
- App icon from base64-decoded metadata
- Colored badges indicating tag status:
  - **Taxed + has time**: Amber icon (⏱️)
  - **Taxed + no time**: Red lock icon (🔴)
  - **Free**: Green badge (✓)
  - **Blocked**: Grey lock icon (🚫)

### 4.1.6 Lifecycle Management

**App Resume Synchronization (HomeTab):**

```dart
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.resumed) {
    // User returned to NeuroGate from launched app
    final appState = Provider.of<AppState>(context, listen: false);
    appState.syncRemainingTime();
    // Native overlay reports back remaining countdown
    // UI refreshes with accurate time value
  }
}
```

This ensures the time bank display always reflects the actual countdown that occurred while the app was in use.

---

## 4.2 Tools and Technologies Used

### 4.2.1 Core Development Framework

| Component | Version | Purpose |
|-----------|---------|---------|
| **Flutter** | 3.11.0+ | Cross-platform UI framework for all 6+ targets |
| **Dart** | 3.11.0+ | Programming language compiled to native code |
| **Material Design** | 3 | UI design system and component library |
| **Android SDK** | API 21+ | Minimum Android version support |

### 4.2.2 State Management & Architecture

| Package | Version | Functionality |
|---------|---------|---------------|
| **provider** | 6.1.5+1 | Reactive state management via ChangeNotifier pattern |
| **flutter (built-in)** | 3.11.0+ | Navigation (MaterialApp, Navigator, routes) |

**Provider Pattern Usage:**
```dart
// In main.dart
ChangeNotifierProvider.value(value: appState, child: NeuroGateLauncher())

// In widgets
Consumer<AppState>(
  builder: (context, appState, _) {
    return Text('Time: ${appState.timeBank} mins');
  },
)
```

### 4.2.3 Authentication & Security

| Package | Version | Feature |
|---------|---------|---------|
| **google_sign_in** | 6.2.1 | OAuth 2.0 authentication with Google |
| **flutter_screen_lock** | 9.2.2+2 | PIN-based access control for parent panel |

**Google Sign-In Configuration:**
- Server Client ID: `86841428362-n7hnl1itoe4onhfc1envlt7eo27ibgkd.apps.googleusercontent.com`
- Scope: `['email']`
- Returns AccessToken for API calls

**Screen Lock Configuration:**
```dart
screenLock(
  context: context,
  correctString: appState.parentPin,  // Default: '0000'
  config: ScreenLockConfig(backgroundColor: Color(0xFF0F172A)),
  onUnlocked: () { setState(() => _authenticated = true); },
  onCancelled: Navigator.of(context).pop,
)
```

### 4.2.4 Generative AI Integration

| Service | Model | API Type | Use Case |
|---------|-------|----------|----------|
| **Google Generative AI** | gemini-2.5-flash | HTTP REST | Text and vision-based prompts |
| **GeminiService** (custom wrapper) | - | Abstraction | Encapsulates API interaction |

**API Key:**
- Hardcoded in `AppState.geminiApiKey`: `AIzaSyDWQ0n1ePxW0sYvb-1eOQS4hvXgeLEGqis`
- Used for text generation and image analysis

**GeminiService Methods:**

```dart
class GeminiService {
  static const String _modelText = 'gemini-2.5-flash';
  static const String _modelVision = 'gemini-2.5-flash';
  
  Future<String> callGeminiText(String prompt, 
      {bool jsonMode = false}) async {
    // POST to: generativelanguage.googleapis.com/v1beta/models/
    //          gemini-2.5-flash:generateContent
    // Returns: extracted text from response
  }
  
  Future<String> callGeminiVision(String prompt, 
      Uint8List imageBytes, {bool jsonMode = false}) async {
    // Same endpoint with base64-encoded image
    // Returns: text analysis of image
  }
}
```

**System Instruction:**
```
"You are NeuroGate, a child psychology assistant. 
You provide short, engaging, safe content."
```

### 4.2.5 Data Persistence

| Package | Version | Use Case |
|---------|---------|----------|
| **shared_preferences** | 2.5.4 | Key-value storage on device |
| **path_provider** | 2.1.5 | File system paths for media |

**Stored Keys:**
```dart
'timeBank'      // int: Minutes remaining
'ageGroup'      // String: '3-5', '6-8', '9-12', '13-16'
'exchangeRate'  // int: Minutes awarded after toll
'appTags'       // String: JSON-encoded Map<String, String>
'googleToken'   // String: OAuth access token
'parentPin'     // String: PIN code
```

**Persistence Pattern:**
```dart
Future<void> setTimeBank(int newTimeMinutes) async {
  _timeBank = newTimeMinutes;
  _timeBankSeconds = newTimeMinutes * 60;
  await _prefs.setInt('timeBank', _timeBank);
  notifyListeners();  // Updates all Consumer widgets
}
```

### 4.2.6 Media & Sensor Access

| Package | Version | Capability |
|---------|---------|-----------|
| **camera** | 0.11.0+2 | Photo capture (object hunt toll) |
| **audioplayers** | 6.6.0 | Audio playback (currently unused) |

**Camera Initialization (Object Hunt):**
```dart
final cameras = await availableCameras();
_cameraController = CameraController(
  cameras.first,
  ResolutionPreset.medium,
  enableAudio: false,
);
await _cameraController!.initialize();
```

### 4.2.7 Networking

| Package | Version | Purpose |
|---------|---------|---------|
| **http** | 1.6.0 | HTTP client for API calls |

Used by GeminiService for synchronous HTTP POST requests to Google Generative AI endpoint.

### 4.2.8 Utilities & UI

| Package | Version | Purpose |
|---------|---------|---------|
| **cupertino_icons** | 1.0.8 | iOS-style icon set (Material Design 3) |
| **app_settings** | 7.0.0 | Links to native Android system settings |

**App Settings Usage (Parent Panel System Tab):**
```dart
AppSettings.openAppSettings(type: AppSettingsType.security);
AppSettings.openAppSettings(type: AppSettingsType.settings);
// Launches native Android Settings app at specific pages
```

### 4.2.9 Build & Compilation

| Tool | Version | Role |
|------|---------|------|
| **Gradle** | 8.0+ | Android build system |
| **Kotlin/Java** | Latest | Native code for MethodChannel |
| **Flutter toolchain** | 3.11.0+ | Unified build orchestration |

---

## 4.3 Module-Wise Description

### 4.3.1 Authentication Module (`LoginScreen`)

**File:** `lib/screens/login_screen.dart`

**Responsibility:** Authenticate parent/guardian via Google OAuth and establish session

**Key Components:**

```dart
class LoginScreen extends StatefulWidget { }
class _LoginScreenState extends State<LoginScreen> {
  late GoogleSignIn _googleSignIn;
  bool _isLoading = false;
  String? _errorDetail;
}
```

**User Interface:**
- Blue gradient background (Color 0xFF1E293B → 0xFF0F172A)
- Brain/AI icon (96×96, rotated -0.2 rad)
- Title: "NeuroGate AI"
- Description: "Authorize your Google Account to enable Gemini AI cognitive tolls..."
- White "Authorize with Google" button (60px height)
- Error message container (red accent with icon)
- Terms of Service footer text

**Sign-In Flow:**

```
User Taps Button
  ↓
_handleSignIn() called
  ↓
[Sign out first to clear stale sessions]
  ↓
GoogleSignIn.signIn()
  ↓
[Native Google account picker opens]
  ↓
User selects account & grants consent
  ↓
account.authentication → accessToken extracted
  ↓
appState.setGoogleAccessToken(token)
  ↓
[Token persisted to SharedPreferences]
  ↓
[App automatically navigates to MainNavigator]
```

**Error Handling:**
- Network errors → Display connection help text
- SHA-1 mismatches → Developer fingerprint message
- Play Services outdated → Update prompt
- User cancellation → Silently handled

**Navigation Guard (main.dart):**
```dart
if (appState.googleAccessToken.isEmpty) {
  return LoginScreen();
} else {
  return MainNavigator();
}
```

---

### 4.3.2 Time Bank Management Module

**Components:**
- `AppState._timeBank`, `_timeBankSeconds` (state)
- `HomeTab._buildTimeBank()` (child display)
- `DashboardTab` (parent control)

**HomeTab Display:**

```dart
Widget _buildTimeBank(AppState appState) {
  return Container(
    margin: EdgeInsets.all(16),
    padding: EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      children: [
        Text('TIME BANK', style: kSmallCaps),
        SizedBox(height: 8),
        Row(
          children: [
            Text(
              '${(appState.timeBankSeconds / 60).ceil()}',
              style: TextStyle(fontSize: 48, color: Colors.blueAccent),
            ),
            SizedBox(width: 8),
            Text('mins'),
          ],
        ),
      ],
    ),
  );
}
```

**Key Features:**
- Displays `ceil(timeBankSeconds / 60)` to show rounded-up minutes
- Blue accent color (Colors.blueAccent)
- Updates reactively via `Consumer<AppState>`
- Centered in SafeArea above app grid

**DashboardTab Controls:**

```dart
_ActionButton(
  label: '− 15 min',
  icon: Icons.remove_circle_outline,
  color: Colors.redAccent,
  onTap: () => appState.subtractTime(15),
),

_ActionButton(
  label: '+ 15 min',
  icon: Icons.add_circle_outline,
  color: Colors.greenAccent,
  onTap: () => appState.addTime(15),
),
```

**Operations:**
| Operation | Method | Result |
|-----------|--------|--------|
| Add time | `appState.addTime(15)` | `timeBank += 15; notify()` |
| Remove time | `appState.subtractTime(15)` | `timeBank -= 15` (floor 0) |
| Set exact | `appState.setTimeBank(120)` | `timeBank = 120; notify()` |

**Lifecycle Sync (HomeTab):**

```dart
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.resumed) {
    final appState = Provider.of<AppState>(context, listen: false);
    appState.syncRemainingTime();
    // Retrieves countdown value from native overlay service
    // Updates UI with accurate remaining time
  }
}
```

---

### 4.3.3 App Tagging & Rules Module

**Files:** 
- `lib/models/app_state.dart` (AppTag enum, tagging logic)
- `lib/screens/parent_panel/app_rules_tab.dart` (UI)

**Enum:**
```dart
enum AppTag { taxed, free, blocked }
```

**Data Structure (AppState):**
```dart
Map<String, String> _appTags = {
  'com.google.android.youtube': 'taxed',
  'com.instagram.android': 'blocked',
  'com.google.play.books': 'free',
  // ... mappings
};
```

**AppRulesTab Features:**

1. **App Discovery:**
   ```dart
   Future<void> _fetchApps() async {
     final List<dynamic>? result = 
         await platform.invokeMethod('getInstalledApps');
     setState(() { _apps = result ?? []; });
   }
   ```

2. **Search Filtering:**
   ```dart
   List<dynamic> get _filteredApps {
     if (_searchQuery.isEmpty) return _apps;
     return _apps.where((app) {
       final name = (app['name'] as String).toLowerCase();
       return name.contains(_searchQuery.toLowerCase());
     }).toList();
   }
   ```

3. **Tag Assignment UI:**
   ```dart
   DropdownButton<AppTag>(
     value: appState.getAppTag(packageName),
     items: [
       DropdownMenuItem(value: AppTag.taxed, 
           child: Text('Taxed (requires time)')),
       DropdownMenuItem(value: AppTag.free, 
           child: Text('Free (no time cost)')),
       DropdownMenuItem(value: AppTag.blocked, 
           child: Text('Blocked (no launch)')),
     ],
     onChanged: (newTag) => 
         appState.setAppTag(packageName, newTag),
   )
   ```

4. **Persistence:**
   ```dart
   Future<void> setAppTag(String packageName, AppTag tag) async {
     _appTags[packageName] = tag.name;  // 'taxed', 'free', 'blocked'
     await _persistAppTags();
     notifyListeners();
   }
   
   Future<void> _persistAppTags() async {
     await _prefs.setString('appTags', 
         jsonEncode(_appTags));
   }
   ```

**Tag Lookup (HomeTab):**
```dart
AppTag getAppTag(String packageName) {
  final raw = _appTags[packageName];
  switch (raw) {
    case 'free': return AppTag.free;
    case 'blocked': return AppTag.blocked;
    default: return AppTag.taxed;  // Default
  }
}

bool isAppTaxed(String packageName) => 
    getAppTag(packageName) == AppTag.taxed;
bool isAppBlocked(String packageName) => 
    getAppTag(packageName) == AppTag.blocked;
```

---

### 4.3.4 Cognitive Toll Module

**File:** `lib/widgets/interceptor_dialog.dart`

**Responsibility:** Present age-appropriate challenges to unlock time when bank depleted

**Overall Architecture:**

```dart
class InterceptorDialog extends StatefulWidget {
  final Map<dynamic, dynamic> targetApp;
  final VoidCallback onSuccess;
}

class _InterceptorDialogState extends State<InterceptorDialog> {
  late GeminiService _geminiService;
  String _errorMessage = '';
  String _aiFeedback = '';
  
  // Quiz state
  String _question = '';
  String _answer = '';
  
  // Camera state
  CameraController? _cameraController;
  String _targetObject = '';
  XFile? _capturedImage;
}
```

**Initialization Flow:**

```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _initToll();
  });
}

Future<void> _initToll() async {
  final appState = Provider.of<AppState>(context, listen: false);
  _geminiService = GeminiService(apiKey: appState.geminiApiKey);
  final ageGroup = appState.ageGroup;

  try {
    if (ageGroup == '3-5' || ageGroup == '6-8') {
      // Object Hunt
      _targetObject = _objectHuntTargets[Random().nextInt(15)];
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        _cameraController = CameraController(cameras.first, 
            ResolutionPreset.medium);
        await _cameraController!.initialize();
        setState(() { _isCameraReady = true; });
      }
    } else if (ageGroup == '9-12') {
      // Trivia
      _loadOfflineTrivia();
      _tryFetchOnlineTrivia();
    } else if (ageGroup == '13-16') {
      // Intent evaluation
      setState(() => _isLoading = false);
    }
  } catch (e) {
    debugPrint("InitToll error: $e");
    if (_question.isEmpty) _loadOfflineTrivia();
  }
}
```

**Sub-Module A: Object Hunt (Ages 3-5, 6-8)**

**Preloaded Targets (15 objects):**
```dart
const List<String> _objectHuntTargets = [
  "a cup or mug",
  "a book",
  "something red",
  "a shoe or sandal",
  "a spoon or fork",
  "a pillow or cushion",
  "something green",
  "a pencil or pen",
  "a chair",
  "a bottle",
  "a plate or bowl",
  "a remote control",
  "a phone charger or cable",
  "a towel or cloth",
  "a bag or backpack",
];
```

**Submission Flow:**

```dart
Future<void> _submitObjectHunt() async {
  if (_capturedImage == null) {
    setState(() {
      _errorMessage = "Take a photo of $_targetObject first!";
      _isChecking = false;
    });
    return;
  }

  try {
    final imageBytes = await _capturedImage!.readAsBytes();
    
    final prompt = '''
      I asked a child to find "$_targetObject" in their house.
      Look at this photo carefully. Does it show this object 
      or something very similar? Be somewhat lenient for a child.
      Respond ONLY with: {"found": true} or {"found": false}
    ''';
    
    final response = await _geminiService.callGeminiVision(
      prompt, imageBytes, jsonMode: true);
    
    final data = jsonDecode(response);
    
    if (data['found'] == true) {
      setState(() => _aiFeedback = "🎉 Great job! Object found!");
      await Future.delayed(Duration(milliseconds: 500));
      _handleSuccess();
    } else {
      _visionRetries++;
      if (_visionRetries >= 3) {
        // New target
        setState(() {
          _targetObject = _objectHuntTargets[Random().nextInt(15)];
          _errorMessage = "Let's try a new object! Find: $_targetObject";
          _capturedImage = null;
          _visionRetries = 0;
        });
      } else {
        setState(() {
          _errorMessage = 
              "I couldn't spot $_targetObject. Try closer! ($_visionRetries/3)";
          _capturedImage = null;
        });
      }
    }
  } catch (e) {
    debugPrint("Vision error: $e");
    // Handle error gracefully
  }
}
```

**Sub-Module B: Trivia (Age 9-12)**

**Offline Question Pool (50 questions):**

```dart
const List<Map<String, String>> _offlineTrivia = [
  // Science (15)
  {"question": "What planet is known as the Red Planet?", 
   "answer": "mars"},
  {"question": "What gas do plants breathe in?", 
   "answer": "carbon dioxide"},
  // ... more questions
  
  // Animals (15)
  {"question": "How many legs does a spider have?", 
   "answer": "8"},
  // ... more questions
  
  // Geography (10)
  {"question": "What is the largest ocean on Earth?", 
   "answer": "pacific"},
  // ... more questions
  
  // Math (10)
  {"question": "What is half of 100?", 
   "answer": "50"},
  // ... more questions
];
```

**Loading Strategy:**

```dart
void _loadOfflineTrivia() {
  final q = _offlineTrivia[Random().nextInt(50)];
  setState(() {
    _question = q['question']!;
    _answer = q['answer']!.toLowerCase();
    _isOnlineQuestion = false;
    _isLoading = false;
  });
}

Future<void> _tryFetchOnlineTrivia() async {
  try {
    const prompt = '''
      Generate a fun trivia question for a 10 year old 
      about science, animals, or geography. Under 15 words. 
      Answer must be a SINGLE word. 
      Return JSON: {"question":"...","answer":"..."}
    ''';
    
    final response = await _geminiService.callGeminiText(
      prompt, jsonMode: true);
    final data = jsonDecode(response);
    
    if (data['question'] != null && data['answer'] != null) {
      setState(() {
        _question = data['question'];
        _answer = data['answer'].toString().toLowerCase().trim();
        _isOnlineQuestion = true;
      });
    }
  } catch (e) {
    debugPrint("Online trivia failed (using offline): $e");
  }
}
```

**Answer Submission:**

```dart
void _submitTrivia() {
  final userAnswer = _textController.text.toLowerCase().trim();
  final isCorrect = userAnswer == _answer;
  
  if (isCorrect) {
    setState(() => _aiFeedback = "✨ Correct! Great job!");
    Future.delayed(Duration(milliseconds: 500), _handleSuccess);
  } else {
    setState(() {
      _errorMessage = "Not quite right. Try again!";
      _isChecking = false;
    });
  }
}
```

**Sub-Module C: Intent Evaluation (Age 13-16)**

```dart
Future<void> _submitIntentEvaluation() async {
  final appState = Provider.of<AppState>(context, listen: false);
  
  setState(() {
    _isChecking = true;
    _aiFeedback = '';
  });

  try {
    final prompt = '''
      Ask a 15-year-old a thoughtful question about 
      why they want to use the app right now. 
      Evaluate their response for maturity and intent.
      Response JSON: {"approved": boolean, "feedback": "..."}
    ''';
    
    final response = await _geminiService.callGeminiText(
      prompt, jsonMode: true);
    final data = jsonDecode(response);
    
    if (data['approved'] == true) {
      setState(() => _aiFeedback = data['feedback']);
      Future.delayed(Duration(milliseconds: 500), _handleSuccess);
    } else {
      setState(() {
        _errorMessage = data['feedback'] ?? 
            "Reflect on your choice and try again later.";
        _isChecking = false;
      });
    }
  } catch (e) {
    debugPrint("Intent evaluation error: $e");
  }
}
```

**Success Handler (Universal):**

```dart
void _handleSuccess() {
  final appState = Provider.of<AppState>(context, listen: false);
  appState.addTime(appState.exchangeRate);
  Navigator.pop(context);
  // InterceptorDialog.onSuccess callback fires
  // App launches in parent context
}
```

---

### 4.3.5 Parent Control Panel Module

**File:** `lib/screens/parent_panel_screen.dart`

**Architecture:**
```
ParentPanelScreen
  ├─ PIN Lock Screen (flutter_screen_lock)
  │   └─ _showPinLock() → correctString: appState.parentPin
  └─ Tabbed Content (3 tabs)
      ├─ DashboardTab
      ├─ AppRulesTab
      └─ SystemTab
```

**PIN Authentication:**

```dart
class ParentPanelScreen extends StatefulWidget { }

class _ParentPanelScreenState extends State<ParentPanelScreen> {
  bool _authenticated = false;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_authenticated) _showPinLock();
    });
  }
  
  void _showPinLock() {
    final appState = Provider.of<AppState>(context, listen: false);
    
    screenLock(
      context: context,
      correctString: appState.parentPin,
      canCancel: true,
      title: const Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: Text('Enter Parent PIN'),
      ),
      config: ScreenLockConfig(
        backgroundColor: const Color(0xFF0F172A),
      ),
      onCancelled: Navigator.of(context).pop,
      onUnlocked: () {
        Navigator.of(context).pop();
        setState(() => _authenticated = true);
      },
    );
  }
}
```

**Tab 1: Dashboard (`dashboard_tab.dart`)**

**Widgets:**
- **Time Bank Card**: Display + ± 15 min buttons
- **Age Group Selector**: Dropdown (3-5, 6-8, 9-12, 13-16)
- **Exchange Rate Slider**: Minutes awarded per toll (default 15)

**Code:**
```dart
class DashboardTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    
    return ListView(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      children: [
        _buildHeader('Dashboard'),
        
        _buildCard(
          child: Column(
            children: [
              Text('TIME BANK'),
              Row(children: [
                Text('${appState.timeBank}', 
                    style: TextStyle(fontSize: 48, color: Colors.blueAccent)),
                Text('mins'),
              ]),
              RoundIconButton('− 15 min', Colors.redAccent, 
                  () => appState.subtractTime(15)),
              RoundIconButton('+ 15 min', Colors.greenAccent, 
                  () => appState.addTime(15)),
            ],
          ),
        ),
        
        _buildCard(
          child: Column(
            children: [
              Text('Developmental Stage (Toll Type)'),
              DropdownButton<String>(
                value: appState.ageGroup,
                items: [
                  DropdownMenuItem(value: '3-5', 
                      child: Text('3–5 yrs (✨ Object Hunt)')),
                  DropdownMenuItem(value: '6-8', 
                      child: Text('6–8 yrs (✨ Object Hunt)')),
                  DropdownMenuItem(value: '9-12', 
                      child: Text('9–12 yrs (📚 Trivia)')),
                  DropdownMenuItem(value: '13-16', 
                      child: Text('13–16 yrs (💭 Reflection)')),
                ],
                onChanged: (value) => appState.setAgeGroup(value!),
              ),
            ],
          ),
        ),
        
        _buildCard(
          child: Column(
            children: [
              Text('Dopamine Tax (Exchange Rate)'),
              Slider(
                value: appState.exchangeRate.toDouble(),
                min: 5,
                max: 60,
                onChanged: (value) => 
                    appState.setExchangeRate(value.toInt()),
              ),
              Text('${appState.exchangeRate} minutes per successful toll'),
            ],
          ),
        ),
      ],
    );
  }
}
```

**Tab 2: App Rules (`app_rules_tab.dart`)**

```dart
class AppRulesTab extends StatefulWidget { }

class _AppRulesTabState extends State<AppRulesTab> {
  List<dynamic> _apps = [];
  String _searchQuery = '';
  
  @override
  void initState() {
    super.initState();
    _fetchApps();
  }
  
  Future<void> _fetchApps() async {
    try {
      final List<dynamic>? result = 
          await platform.invokeMethod('getInstalledApps');
      setState(() { _apps = result ?? []; });
    } catch (e) {
      debugPrint("Failed to get apps: $e");
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    
    return Column(
      children: [
        _buildHeader('App Rules'),
        TextField(
          onChanged: (q) => setState(() => _searchQuery = q),
          decoration: InputDecoration(hintText: 'Search apps…'),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: _filteredApps.length,
            itemBuilder: (context, index) {
              final app = _filteredApps[index];
              final tag = appState.getAppTag(app['packageName']);
              
              return _AppRuleItem(
                name: app['name'],
                packageName: app['packageName'],
                currentTag: tag,
                onTagChanged: (newTag) => 
                    appState.setAppTag(app['packageName'], newTag),
              );
            },
          ),
        ),
      ],
    );
  }
}
```

**Tab 3: System (`system_tab.dart`)**

Provides permission setup cards:

```dart
class SystemTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      children: [
        _buildHeader('System'),
        
        _PermissionCard(
          icon: Icons.data_usage,
          title: 'Usage Access',
          description: 'Allows NeuroGate to see which apps are used.',
          onTap: () => AppSettings.openAppSettings(
              type: AppSettingsType.security),
        ),
        
        _PermissionCard(
          icon: Icons.layers,
          title: 'Draw Over Other Apps',
          description: 'Allows overlay countdown timer.',
          onTap: () => AppSettings.openAppSettings(
              type: AppSettingsType.settings),
        ),
        
        _PermissionCard(
          icon: Icons.notifications_active,
          title: 'Notification Access',
          description: 'Allows reminder notifications.',
          onTap: () => AppSettings.openAppSettings(
              type: AppSettingsType.notification),
        ),
        
        _PermissionCard(
          icon: Icons.battery_charging_full,
          title: 'Battery Optimisation',
          description: 'Disable optimization for reliable background service.',
          onTap: () => AppSettings.openAppSettings(
              type: AppSettingsType.batteryOptimization),
        ),
      ],
    );
  }
}
```

---

### 4.3.6 Gem ini Service Module

**File:** `lib/services/gemini_service.dart`

**Wrapper for Google Generative AI API:**

```dart
class GeminiService {
  static const String _modelText = 'gemini-2.5-flash';
  static const String _modelVision = 'gemini-2.5-flash';
  
  final String apiKey;
  
  GeminiService({required this.apiKey});
  
  /// Text-based generation
  Future<String> callGeminiText(String prompt, 
      {bool jsonMode = false}) async {
    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/'
        '$_modelText:generateContent?key=$apiKey');
    
    final Map<String, dynamic> payload = {
      "contents": [{"parts": [{"text": prompt}]}],
      "systemInstruction": {
        "parts": [{
          "text": "You are NeuroGate, a child psychology assistant. "
                  "You provide short, engaging, safe content."
        }]
      },
    };
    
    if (jsonMode) {
      payload["generationConfig"] = {
        "responseMimeType": "application/json"
      };
    }
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      
      if (response.statusCode != 200) {
        debugPrint("Gemini Error: ${response.statusCode}");
        return jsonMode ? "{}" : "Error connecting to AI.";
      }
      
      final data = jsonDecode(response.body);
      return data['candidates']?[0]?['content']?['parts']?[0]?['text'] 
          ?? (jsonMode ? "{}" : "Error connecting to AI.");
    } catch (e) {
      debugPrint("Gemini Exception: $e");
      return jsonMode ? "{}" : "Error connecting to AI.";
    }
  }
  
  /// Vision-based analysis
  Future<String> callGeminiVision(String prompt, 
      Uint8List imageBytes, {bool jsonMode = false}) async {
    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/'
        '$_modelVision:generateContent?key=$apiKey');
    
    final Map<String, dynamic> payload = {
      "contents": [{
        "parts": [
          {"text": prompt},
          {
            "inline_data": {
              "mime_type": "image/jpeg",
              "data": base64Encode(imageBytes)
            }
          }
        ]
      }],
    };
    
    if (jsonMode) {
      payload["generationConfig"] = {
        "responseMimeType": "application/json"
      };
    }
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      
      if (response.statusCode != 200) {
        return jsonMode ? "{}" : "Error connecting to AI.";
      }
      
      final data = jsonDecode(response.body);
      return data['candidates']?[0]?['content']?[0]?['text'] 
          ?? (jsonMode ? "{}" : "Error connecting to AI.");
    } catch (e) {
      debugPrint("Vision Exception: $e");
      return jsonMode ? "{}" : "Error connecting to AI.";
    }
  }
}
```

**Error Resilience:**
- Network errors → Return default error message
- JSON parse failures → Attempt raw text extraction
- Vision failures → Fall back to trivia after 3 retries

---

### 4.3.7 Home Tab Module

**File:** `lib/screens/home_tab.dart`

**Responsibility:** Child-facing app launcher interface

**Key Features:**

```dart
class HomeTab extends StatefulWidget { }

class _HomeTabState extends State<HomeTab> with WidgetsBindingObserver {
  List<dynamic> _apps = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchApps();
    _requestOverlayPermission();
  }
  
  Future<void> _fetchApps() async {
    try {
      final List<dynamic>? result = 
          await platform.invokeMethod('getInstalledApps');
      setState(() {
        _apps = result ?? [];
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Failed to get apps: $e");
    }
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final appState = Provider.of<AppState>(context, listen: false);
      appState.syncRemainingTime();
    }
  }
  
  Widget _buildAppGrid(AppState appState) {
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 32,
        crossAxisSpacing: 16,
        childAspectRatio: 0.7,
      ),
      itemCount: _apps.length,
      itemBuilder: (context, index) {
        final app = _apps[index];
        final tag = appState.getAppTag(app['packageName']);
        
        return GestureDetector(
          onTap: () => _handleAppLaunch(app, appState),
          child: Column(
            children: [
              Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      color: Color(0xFF1E293B),
                    ),
                    child: Image.memory(
                      base64Decode(app['icon']),
                      fit: BoxFit.cover,
                    ),
                  ),
                  _buildTagBadge(tag, appState),
                ],
              ),
              SizedBox(height: 8),
              Text(app['name'], maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildTagBadge(AppTag tag, AppState appState) {
    final (color, icon) = switch (tag) {
      AppTag.taxed => (
        appState.timeBank > 0 ? Colors.amber : Colors.redAccent,
        appState.timeBank > 0 ? Icons.timer : Icons.lock
      ),
      AppTag.free => (Colors.greenAccent, null),
      AppTag.blocked => (Colors.grey, Icons.block),
    };
    
    return Positioned(
      bottom: -8,
      right: -8,
      child: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
        child: icon != null 
            ? Icon(icon, color: Colors.white, size: 16)
            : null,
      ),
    );
  }
}
```

---

### 4.3.8 Main App & Navigation

**File:** `lib/main.dart`

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final appState = AppState();
  await appState.init();  // Load from SharedPreferences
  
  runApp(
    ChangeNotifierProvider.value(
      value: appState,
      child: const NeuroGateLauncher(),
    ),
  );
}

class NeuroGateLauncher extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NeuroGate',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: Consumer<AppState>(
        builder: (context, appState, _) {
          if (!appState.isInitialized) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          
          if (appState.googleAccessToken.isEmpty) {
            return const LoginScreen();
          }
          
          return const MainNavigator();
        },
      ),
    );
  }
}

class MainNavigator extends StatefulWidget {
  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  int _currentIndex = 0;
  
  void _onTabTapped(int index) {
    if (index == 1) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ParentPanelScreen()),
      );
      return;
    }
    setState(() => _currentIndex = index);
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const HomeTab(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.security), label: 'Parent'),
        ],
      ),
    );
  }
}
```

**Navigation Flow:**
```
NeuroGateLauncher (MaterialApp root)
  ├─ Not Initialized → Loading spinner
  ├─ No Token → LoginScreen
  └─ Token Exists → MainNavigator
      ├─ HomeTab (child interface)
      └─ ParentPanelScreen (PIN-protected, 3 tabs)
```

---

## Summary Table: Modules and Responsibilities

| Module | File | Responsibility |
|--------|------|-----------------|
| **Authentication** | `login_screen.dart` | Google OAuth sign-in |
| **State Management** | `app_state.dart` | Central state & persistence |
| **Time Bank** | `home_tab.dart`, `dashboard_tab.dart` | Display, adjust, sync countdown |
| **App Rules** | `app_rules_tab.dart` | Tag apps (taxed/free/blocked) |
| **Cognitive Toll** | `interceptor_dialog.dart` | Object Hunt, Trivia, Intent Eval |
| **Parent Panel** | `parent_panel_screen.dart` | PIN lock + 3-tab dashboard |
| **Dashboard** | `dashboard_tab.dart` | Time, age, exchange rate controls |
| **System Settings** | `system_tab.dart` | Permission guidance cards |
| **Gemini Integration** | `gemini_service.dart` | AI API wrapper (text + vision) |
| **Navigation** | `main.dart` | App root, tab routing |

---

**End of Chapter 4: Implementation / Methodology**
