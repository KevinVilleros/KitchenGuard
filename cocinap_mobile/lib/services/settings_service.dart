import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'remote_cloud_service.dart';

class SettingsService {
  static const _keyServerUrl = 'server_url';
  static const _keyRecentServers = 'recent_servers';
  static const _keyApiKey = 'api_key';
  static const _keyDesktopHostApiKey = 'desktop_host_api_key';
  static const _keyDesktopRemoteHostEnabled = 'desktop_remote_host_enabled';
  static const _keyCloudGatewayUrl = 'cloud_gateway_url';
  static const _keyCloudDeviceId = 'cloud_device_id';
  static const _keyCloudOwnerKey = 'cloud_owner_key';
  static const _keyCloudViewerKey = 'cloud_viewer_key';
  static const _keyCloudHostEnabled = 'cloud_host_enabled';
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
  static final _secureRandom = Random.secure();
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device),
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

  Future<String> getDesktopHostApiKey() async {
    final key = await _secureStorage.read(key: _keyDesktopHostApiKey);
    if (key != null && key.isNotEmpty) return key;

    final bytes = List<int>.generate(32, (_) => _secureRandom.nextInt(256));
    final generated =
        bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    await _secureStorage.write(key: _keyDesktopHostApiKey, value: generated);
    return generated;
  }

  Future<bool> getDesktopRemoteHostEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyDesktopRemoteHostEnabled) ?? false;
  }

  Future<void> setDesktopRemoteHostEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDesktopRemoteHostEnabled, enabled);
  }

  Future<RemoteCloudCredentials?> getRemoteCloudCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final gatewayUrl = prefs.getString(_keyCloudGatewayUrl);
    final deviceId = prefs.getString(_keyCloudDeviceId);
    final ownerKey = await _secureStorage.read(key: _keyCloudOwnerKey);
    final viewerKey = await _secureStorage.read(key: _keyCloudViewerKey);
    if (gatewayUrl == null ||
        deviceId == null ||
        viewerKey == null ||
        viewerKey.isEmpty) {
      return null;
    }
    return RemoteCloudCredentials.fromJson({
      'gatewayUrl': gatewayUrl,
      'deviceId': deviceId,
      'ownerKey': ownerKey ?? '',
      'viewerKey': viewerKey,
    });
  }

  Future<void> setRemoteCloudCredentials(
    RemoteCloudCredentials? credentials,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    if (credentials == null) {
      await prefs.remove(_keyCloudGatewayUrl);
      await prefs.remove(_keyCloudDeviceId);
      await _secureStorage.delete(key: _keyCloudOwnerKey);
      await _secureStorage.delete(key: _keyCloudViewerKey);
      return;
    }
    await prefs.setString(_keyCloudGatewayUrl, credentials.gatewayUrl);
    await prefs.setString(_keyCloudDeviceId, credentials.deviceId);
    if (credentials.ownerKey.isEmpty) {
      await _secureStorage.delete(key: _keyCloudOwnerKey);
    } else {
      await _secureStorage.write(
        key: _keyCloudOwnerKey,
        value: credentials.ownerKey,
      );
    }
    await _secureStorage.write(
      key: _keyCloudViewerKey,
      value: credentials.viewerKey,
    );
  }

  Future<bool> getRemoteCloudHostEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyCloudHostEnabled) ?? false;
  }

  Future<void> setRemoteCloudHostEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyCloudHostEnabled, enabled);
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
    final source = switch (index) {
      1 => 'ip',
      2 => 'remote',
      3 => 'cloud',
      _ => 'phone',
    };
    await prefs.setString(_keyStandaloneSource, source);
  }

  Future<String> getStandaloneCameraUrl() async {
    final secureUrl = await _secureStorage.read(key: _keyStandaloneCameraUrl);
    if (secureUrl != null && secureUrl.isNotEmpty) return secureUrl;

    // Migrate any URL (which may contain camera credentials) to secure storage.
    final prefs = await SharedPreferences.getInstance();
    final legacyUrl = prefs.getString(_keyStandaloneCameraUrl) ?? "";
    if (legacyUrl.isNotEmpty) {
      await _secureStorage.write(
        key: _keyStandaloneCameraUrl,
        value: legacyUrl,
      );
      await prefs.remove(_keyStandaloneCameraUrl);
      return legacyUrl;
    }
    return "";
  }

  Future<void> setStandaloneCameraUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    if (url.isEmpty) {
      await _secureStorage.delete(key: _keyStandaloneCameraUrl);
    } else {
      await _secureStorage.write(key: _keyStandaloneCameraUrl, value: url);
    }
    await prefs.remove(_keyStandaloneCameraUrl);
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
