import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _keyServerUrl = 'server_url';
  static const _keyAutoConnect = 'auto_connect';
  static const _keyRecentServers = 'recent_servers';
  static const _keyApiKey = 'api_key';
  static const _keyStandaloneDuration = 'standalone_duration';
  static const _keyStandaloneNoPerson = 'standalone_no_person_seconds';
  static const _keyStandaloneDanger = 'standalone_danger_minutes';
  static const _keyStandaloneConfidence = 'standalone_confidence';
  static const _maxRecents = 5;

  Future<String?> getServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyServerUrl);
  }

  Future<String> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyApiKey) ?? "";
  }

  Future<void> setApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyApiKey, key);
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

  Future<void> setServerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyServerUrl, url);
    await _addRecent(prefs, url);
  }

  Future<bool> getAutoConnect() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAutoConnect) ?? true;
  }

  Future<void> setAutoConnect(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoConnect, value);
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