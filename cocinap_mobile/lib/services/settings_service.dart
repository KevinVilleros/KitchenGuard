import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _keyServerUrl = 'server_url';
  static const _keyAutoConnect = 'auto_connect';
  static const _keyRecentServers = 'recent_servers';
  static const _maxRecents = 5;

  Future<String?> getServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyServerUrl);
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