import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _keyServerUrl = 'server_url';
  static const _keyRecentServers = 'recent_servers';
  static const _keyApiKey = 'api_key';
  static const _keyStandaloneDuration = 'standalone_duration';
  static const _keyStandaloneNoPerson = 'standalone_no_person_seconds';
  static const _keyStandaloneDanger = 'standalone_danger_minutes';
  static const _keyStandaloneConfidence = 'standalone_confidence';
  static const _keyStandaloneSource = 'standalone_source';
  static const _keyStandaloneCameraUrl = 'standalone_camera_url';
  static const _keyHasSeenOnboarding = 'has_seen_onboarding';
  static const _keyHasSeenInstallGuide = 'has_seen_install_guide';
  static const _keyHasSeenAppTour = 'has_seen_app_tour';
  static const _keyLanguage = 'app_language';
  static const _keyAlertIntervals = 'alert_intervals_minutes';
  static const _keyIntervalAlertsEnabled = 'alert_intervals_enabled';
  static const _keyAlertRepeatMode = 'alert_repeat_mode';
  static const _maxRecents = 5;
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  Future<String> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLanguage) ?? 'en';
  }

  Future<void> setLanguage(String lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLanguage, lang == 'en' ? 'en' : 'es');
  }

  Future<String?> getServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyServerUrl);
  }

  Future<String> getApiKey() async {
    final secureKey = await _secureStorage.read(key: _keyApiKey);
    if (secureKey != null && secureKey.isNotEmpty) return secureKey;

    // One-time migration from legacy SharedPreferences storage.
    final prefs = await SharedPreferences.getInstance();
    final legacyKey = prefs.getString(_keyApiKey) ?? '';
    if (legacyKey.isNotEmpty) {
      await _secureStorage.write(key: _keyApiKey, value: legacyKey);
      await prefs.remove(_keyApiKey);
      return legacyKey;
    }
    return '';
  }

  Future<void> setApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    if (key.isEmpty) {
      await _secureStorage.delete(key: _keyApiKey);
    } else {
      await _secureStorage.write(key: _keyApiKey, value: key);
    }
    await prefs.remove(_keyApiKey);
  }

  Future<int> getStandaloneDuration() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyStandaloneDuration) ?? 30;
  }

  Future<void> setStandaloneDuration(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyStandaloneDuration, value);
  }

  Future<int> getStandaloneNoPersonSeconds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyStandaloneNoPerson) ?? 30;
  }

  Future<void> setStandaloneNoPersonSeconds(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyStandaloneNoPerson, value);
  }

  Future<int> getStandaloneDangerMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyStandaloneDanger) ?? 5;
  }

  Future<void> setStandaloneDangerMinutes(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyStandaloneDanger, value);
  }

  Future<double> getStandaloneConfidence() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyStandaloneConfidence) ?? 0.5;
  }

  Future<void> setStandaloneConfidence(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyStandaloneConfidence, value);
  }

  Future<String> getStandaloneSource() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyStandaloneSource) ?? 'phone';
  }

  Future<void> setStandaloneSourceIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyStandaloneSource, index == 1 ? 'ip' : 'phone');
  }

  Future<String> getStandaloneCameraUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyStandaloneCameraUrl) ?? "";
  }

  Future<void> setStandaloneCameraUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyStandaloneCameraUrl, url);
  }

  Future<bool> getHasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyHasSeenOnboarding) ?? false;
  }

  Future<void> setHasSeenOnboarding(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHasSeenOnboarding, value);
  }

  Future<bool> getHasSeenInstallGuide() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyHasSeenInstallGuide) ?? false;
  }

  Future<void> setHasSeenInstallGuide(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHasSeenInstallGuide, value);
  }

  Future<bool> getHasSeenAppTour() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyHasSeenAppTour) ?? false;
  }

  Future<void> setHasSeenAppTour(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHasSeenAppTour, value);
  }

  /// Intervalos de alerta (en minutos) configurados por el usuario.
  Future<List<int>> getAlertIntervals() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_keyAlertIntervals);
    if (list == null || list.isEmpty) return const [10, 15, 20, 30];
    final parsed = list
        .map(int.tryParse)
        .whereType<int>()
        .where((m) => m >= 1 && m <= 240)
        .toSet()
        .toList()
      ..sort();
    return parsed.isEmpty ? const [10, 15, 20, 30] : parsed;
  }

  Future<void> setAlertIntervals(List<int> minutes) async {
    final prefs = await SharedPreferences.getInstance();
    final sorted = minutes.where((m) => m >= 1 && m <= 240).toSet().toList()
      ..sort();
    await prefs.setStringList(
      _keyAlertIntervals,
      sorted.map((m) => m.toString()).toList(),
    );
  }

  Future<bool> getIntervalAlertsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIntervalAlertsEnabled) ?? true;
  }

  Future<void> setIntervalAlertsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIntervalAlertsEnabled, value);
  }

  /// Modo de repetición: 'repeatLast' o 'oncePerInterval'.
  Future<String> getAlertRepeatMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAlertRepeatMode) ?? 'repeatLast';
  }

  Future<void> setAlertRepeatMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyAlertRepeatMode,
      mode == 'oncePerInterval' ? 'oncePerInterval' : 'repeatLast',
    );
  }

  Future<void> setServerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyServerUrl, url);
    await _addRecent(prefs, url);
  }

  Future<List<String>> getRecentServers() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyRecentServers) ?? [];
  }

  Future<void> removeRecentServer(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_keyRecentServers) ?? [];
    list.remove(url);
    await prefs.setStringList(_keyRecentServers, list);
  }

  Future<void> _addRecent(SharedPreferences prefs, String url) async {
    final list = prefs.getStringList(_keyRecentServers) ?? [];
    list.remove(url);
    list.insert(0, url);
    if (list.length > _maxRecents) {
      list.removeRange(_maxRecents, list.length);
    }
    await prefs.setStringList(_keyRecentServers, list);
  }
}