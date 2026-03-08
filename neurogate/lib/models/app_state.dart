import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppState extends ChangeNotifier {
  static const String _keyTimeBank = 'timeBank';
  static const String _keyAgeGroup = 'ageGroup';
  static const String _keyExchangeRate = 'exchangeRate';
  static const String _keyLockedApps = 'lockedApps';
  static const String _keyGoogleToken = 'googleToken';

  late SharedPreferences _prefs;
  bool _initialized = false;

  int _timeBank = 0;
  String _ageGroup = '9-12';
  int _exchangeRate = 15;
  String _googleAccessToken = '';
  List<String> _lockedAppPackages = [];

  bool get isInitialized => _initialized;
  int get timeBank => _timeBank;
  String get ageGroup => _ageGroup;
  int get exchangeRate => _exchangeRate;
  String get googleAccessToken => _googleAccessToken;
  List<String> get lockedAppPackages => _lockedAppPackages;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    
    _timeBank = _prefs.getInt(_keyTimeBank) ?? 0;
    _ageGroup = _prefs.getString(_keyAgeGroup) ?? '9-12';
    _exchangeRate = _prefs.getInt(_keyExchangeRate) ?? 15;
    _googleAccessToken = _prefs.getString(_keyGoogleToken) ?? '';
    _lockedAppPackages = _prefs.getStringList(_keyLockedApps) ?? [];
    
    _initialized = true;
    notifyListeners();
  }

  Future<void> setTimeBank(int newTime) async {
    _timeBank = newTime;
    await _prefs.setInt(_keyTimeBank, _timeBank);
    notifyListeners();
  }

  Future<void> addTime(int amount) async {
    await setTimeBank(_timeBank + amount);
  }

  Future<void> subtractTime(int amount) async {
    int newTime = _timeBank - amount;
    if (newTime < 0) newTime = 0;
    await setTimeBank(newTime);
  }

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

  Future<void> toggleAppLock(String packageName) async {
    if (_lockedAppPackages.contains(packageName)) {
      _lockedAppPackages.remove(packageName);
    } else {
      _lockedAppPackages.add(packageName);
    }
    await _prefs.setStringList(_keyLockedApps, _lockedAppPackages);
    notifyListeners();
  }

  bool isAppLocked(String packageName) {
    return _lockedAppPackages.contains(packageName);
  }
}
