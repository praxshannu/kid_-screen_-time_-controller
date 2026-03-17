import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/gemini_service.dart';
import '../services/local_ai_service.dart';

/// Per-app control tag used by the Parent Control Panel.
enum AppTag { taxed, free, blocked }

class AppState extends ChangeNotifier {
  static const String _keyTimeBank = 'timeBank';
  static const String _keyAgeGroup = 'ageGroup';
  static const String _keyExchangeRate = 'exchangeRate';
  static const String _keyAppTags = 'appTags';
  static const String _keyGoogleToken = 'googleToken';
  static const String _keyParentPin = 'parentPin';
  static const String _keyParentModeActive = 'parentModeActive';
  static const String _keySetupComplete = 'setupComplete';
  static const String _keyVerificationQuestions = 'verificationQuestions';

  late SharedPreferences _prefs;
  bool _initialized = false;
  bool _useLocalAI = false;
  late LocalAIService _localAIService;
  late GeminiService _geminiService;

  int _timeBank = 0; // in MINUTES (what the parent sets)
  int _timeBankSeconds = 0; // live countdown in seconds
  String _ageGroup = '9-12';
  int _exchangeRate = 15;
  String _googleAccessToken = '';
  String _parentPin = '0000';
  bool _parentModeActive = false;
  bool _setupComplete = false;

  /// Personal verification questions set by the parent.
  /// Each entry is {"question": "...", "answer": "..."}
  List<Map<String, String>> _verificationQuestions = [];

  /// Maps package names → tag strings ("taxed", "free", "blocked").
  Map<String, String> _appTags = {};

  static const _platform = MethodChannel('com.neurogate/apps');
  bool _overlayActive = false;

  bool get isInitialized => _initialized;
  int get timeBank => _timeBank;
  int get timeBankSeconds => _timeBankSeconds;
  String get ageGroup => _ageGroup;
  int get exchangeRate => _exchangeRate;
  String get googleAccessToken => _googleAccessToken;
  String get parentPin => _parentPin;
  bool get parentModeActive => _parentModeActive;
  bool get setupComplete => _setupComplete;
  List<Map<String, String>> get verificationQuestions => _verificationQuestions;
  bool get useLocalAI => _useLocalAI;
  LocalAIService get localAIService => _localAIService;
  GeminiService get geminiService => _geminiService;

  /// The Gemini API key from the Firebase project.
  String get geminiApiKey => 'AIzaSyDWQ0n1ePxW0sYvb-1eOQS4hvXgeLEGqis';

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    _timeBank = _prefs.getInt(_keyTimeBank) ?? 0;
    _timeBankSeconds = _timeBank * 60;
    _ageGroup = _prefs.getString(_keyAgeGroup) ?? '9-12';
    _exchangeRate = _prefs.getInt(_keyExchangeRate) ?? 15;
    _googleAccessToken = _prefs.getString(_keyGoogleToken) ?? '';
    _parentPin = _prefs.getString(_keyParentPin) ?? '0000';
    _parentModeActive = _prefs.getBool(_keyParentModeActive) ?? false;
    _setupComplete = _prefs.getBool(_keySetupComplete) ?? false;
    _useLocalAI = _prefs.getBool('useLocalAI') ?? false;

    _localAIService = LocalAIService();
    await _localAIService.init();
    _geminiService = GeminiService(apiKey: geminiApiKey);

    // Deserialise verification questions.
    final vqJson = _prefs.getString(_keyVerificationQuestions);
    if (vqJson != null) {
      try {
        final decoded = jsonDecode(vqJson) as List;
        _verificationQuestions = decoded
            .map((e) => Map<String, String>.from(e as Map))
            .toList();
      } catch (_) {
        _verificationQuestions = [];
      }
    }

    // Deserialise per-app tags (stored as JSON map).
    final tagsJson = _prefs.getString(_keyAppTags);
    if (tagsJson != null) {
      try {
        _appTags = Map<String, String>.from(jsonDecode(tagsJson) as Map);
      } catch (_) {
        _appTags = {};
      }
    }

    // Migrate legacy locked-app list (if present).
    final legacyLocked = _prefs.getStringList('lockedApps');
    if (legacyLocked != null && legacyLocked.isNotEmpty) {
      for (final pkg in legacyLocked) {
        _appTags.putIfAbsent(pkg, () => 'taxed');
      }
      await _prefs.remove('lockedApps');
      await _persistAppTags();
    }

    // Listen for overlay tap events from native side
    _platform.setMethodCallHandler((call) async {
      if (call.method == 'onOverlayTapped') {
        _onOverlayTapCallback?.call();
      }
    });

    _initialized = true;
    notifyListeners();
  }

  // Callback for when overlay is tapped
  VoidCallback? _onOverlayTapCallback;
  void setOverlayTapCallback(VoidCallback? callback) {
    _onOverlayTapCallback = callback;
  }

  // ──────────────────── Parent Mode ────────────────────

  Future<void> setParentModeActive(bool active) async {
    _parentModeActive = active;
    await _prefs.setBool(_keyParentModeActive, active);
    notifyListeners();
  }

  Future<void> setSetupComplete(bool complete) async {
    _setupComplete = complete;
    await _prefs.setBool(_keySetupComplete, complete);
    notifyListeners();
  }

  Future<void> setUseLocalAI(bool use) async {
    _useLocalAI = use;
    await _prefs.setBool('useLocalAI', use);
    notifyListeners();
  }

  // ──────────────────── Verification Questions ────────────────────

  Future<void> setVerificationQuestions(List<Map<String, String>> questions) async {
    _verificationQuestions = questions;
    await _prefs.setString(_keyVerificationQuestions, jsonEncode(questions));
    notifyListeners();
  }

  Future<void> addVerificationQuestion(String question, String answer) async {
    _verificationQuestions.add({
      'question': question,
      'answer': answer.toLowerCase().trim(),
    });
    await _prefs.setString(_keyVerificationQuestions, jsonEncode(_verificationQuestions));
    notifyListeners();
  }

  Future<void> removeVerificationQuestion(int index) async {
    if (index >= 0 && index < _verificationQuestions.length) {
      _verificationQuestions.removeAt(index);
      await _prefs.setString(_keyVerificationQuestions, jsonEncode(_verificationQuestions));
      notifyListeners();
    }
  }

  /// Called when returning to NeuroGate — sync remaining time from native service.
  Future<void> syncRemainingTime() async {
    try {
      final remaining = await _platform.invokeMethod('getRemainingSeconds') as int;
      if (remaining >= 0) {
        _timeBankSeconds = remaining;
        _timeBank = (_timeBankSeconds / 60).ceil();
        await _prefs.setInt(_keyTimeBank, _timeBank);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error syncing remaining time: $e");
    }
  }

  /// Start the floating overlay countdown when launching a taxed app.
  Future<void> startOverlayTimer() async {
    if (_timeBankSeconds <= 0) return;
    try {
      final canDraw = await _platform.invokeMethod('canDrawOverlays') as bool;
      if (!canDraw) {
        debugPrint("Cannot draw overlays — permission not granted");
        return;
      }
      await _platform.invokeMethod('startOverlay', {
        'remaining': _timeBankSeconds,
        'total': _timeBankSeconds, // total = current remaining, so ring starts full
      });
      _overlayActive = true;
      debugPrint("Overlay started: ${_timeBankSeconds}s remaining");
    } catch (e) {
      debugPrint("Error starting overlay: $e");
    }
  }

  /// Stop the overlay (when user returns home).
  Future<void> stopOverlayTimer() async {
    if (!_overlayActive) return;
    try {
      await syncRemainingTime(); // Sync remaining time first
      await _platform.invokeMethod('stopOverlay');
      _overlayActive = false;
    } catch (e) {
      debugPrint("Error stopping overlay: $e");
    }
  }

  // ──────────────────── Time Bank ────────────────────

  Future<void> setTimeBank(int newTimeMinutes) async {
    _timeBank = newTimeMinutes;
    _timeBankSeconds = newTimeMinutes * 60;
    await _prefs.setInt(_keyTimeBank, _timeBank);
    notifyListeners();
  }

  Future<void> addTime(int amountMinutes) async {
    await setTimeBank(_timeBank + amountMinutes);
  }

  Future<void> subtractTime(int amountMinutes) async {
    int newTime = _timeBank - amountMinutes;
    if (newTime < 0) newTime = 0;
    await setTimeBank(newTime);
  }

  // ──────────────────── Settings ────────────────────

  Future<void> setAgeGroup(String newAgeGroup) async {
    _ageGroup = newAgeGroup;
    await _prefs.setString(_keyAgeGroup, _ageGroup);
    notifyListeners();
  }

  Future<void> setExchangeRate(int newRate) async {
    _exchangeRate = newRate;
    await _prefs.setInt(_keyExchangeRate, _exchangeRate);
    notifyListeners();
  }

  Future<void> setGoogleAccessToken(String token) async {
    _googleAccessToken = token;
    await _prefs.setString(_keyGoogleToken, _googleAccessToken);
    notifyListeners();
  }

  Future<void> setParentPin(String pin) async {
    _parentPin = pin;
    await _prefs.setString(_keyParentPin, _parentPin);
    notifyListeners();
  }

  // ──────────────────── Per-App Tags ────────────────────

  AppTag getAppTag(String packageName) {
    final raw = _appTags[packageName];
    switch (raw) {
      case 'free':
        return AppTag.free;
      case 'blocked':
        return AppTag.blocked;
      default:
        return AppTag.taxed;
    }
  }

  Future<void> setAppTag(String packageName, AppTag tag) async {
    _appTags[packageName] = tag.name;
    await _persistAppTags();
    notifyListeners();
  }

  // ──────────────────── Safe Browser Logic ────────────────────

  /// Returns a list of known third-party browser package names.
  List<String> getKnownBrowserPackages() {
    return [
      'com.android.chrome',
      'org.mozilla.firefox',
      'com.opera.browser',
      'com.brave.browser',
      'com.sec.android.app.sbrowser', // Samsung Internet
      'com.microsoft.emmx', // Edge
      'com.duckduckgo.mobile.android',
      'mobi.mgeek.TunnyBrowser', // Dolphin
      'com.UCMobile.intl', // UC Browser
      'com.yandex.browser',
      'com.vivaldi.browser'
    ];
  }

  /// Iterates through installed apps and sets known browsers to 'blocked'.
  Future<void> autoBlockBrowsers(List<dynamic> installedApps) async {
    final knownBrowsers = getKnownBrowserPackages();
    bool updated = false;

    for (final app in installedApps) {
      final pkg = (app as Map)['packageName']?.toString() ?? '';
      if (knownBrowsers.contains(pkg)) {
        // If it's not currently tagged as free (parent explicitly allowed it), block it
        if (_appTags[pkg] != 'free') {
          _appTags[pkg] = 'blocked';
          updated = true;
        }
      }
    }

    if (updated) {
      await _persistAppTags();
      notifyListeners();
    }
  }

  Future<void> _persistAppTags() async {
    await _prefs.setString(_keyAppTags, jsonEncode(_appTags));
  }

  bool isAppTaxed(String packageName) =>
      getAppTag(packageName) == AppTag.taxed;

  bool isAppBlocked(String packageName) =>
      getAppTag(packageName) == AppTag.blocked;
}
