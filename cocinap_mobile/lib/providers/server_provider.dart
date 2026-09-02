import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../services/discovery_service.dart';
import '../services/settings_service.dart';

enum ConnectionStatus { disconnected, connecting, connected, error }

class ServerProvider extends ChangeNotifier {
  final ApiService api;
  final DiscoveryService discovery;
  final SettingsService settings;

  ConnectionStatus _status = ConnectionStatus.disconnected;
  String _serverUrl = "";
  String _errorMessage = "";
  String _version = "";
  List<String> _ips = [];
  List<DiscoveryResult> _foundServers = [];
  List<String> _recentServers = [];
  bool _autoSearching = false;
  Timer? _searchTimer;
  bool _disposed = false;

  ServerProvider(this.api, this.discovery, this.settings) {
    _loadRecents();
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    final key = await settings.getApiKey();
    if (key.isNotEmpty) {
      api.updateApiKey(key);
    }
  }

  ConnectionStatus get status => _status;
  String get serverUrl => _serverUrl;
  String get errorMessage => _errorMessage;
  String get version => _version;
  List<String> get ips => _ips;
  List<DiscoveryResult> get foundServers => _foundServers;
  List<String> get recentServers => _recentServers;
  bool get autoSearching => _autoSearching;
  ApiService get apiService => api;

  void setServerUrl(String url) {
    _serverUrl = url;
    api.updateBaseUrl(url);
    notifyListeners();
  }

  Future<void> setApiKey(String key) async {
    api.updateApiKey(key);
    await settings.setApiKey(key);
    notifyListeners();
  }

  Future<void> connectTo(String url) async {
    setServerUrl(url);
    await connect();
  }

  Future<void> autoConnect() async {
    final saved = await settings.getServerUrl();
    if (saved != null && saved.isNotEmpty) {
      setServerUrl(saved);
      await connect();
    }
    if (_status != ConnectionStatus.connected) {
      startAutoSearch();
    }
  }

  /// Auto-retry: searches the network every few seconds until connected.
  void startAutoSearch() {
    if (_autoSearching || _disposed) return;
    _autoSearching = true;
    notifyListeners();
    _search();
  }

  void stopAutoSearch() {
    _autoSearching = false;
    _searchTimer?.cancel();
    _searchTimer = null;
    notifyListeners();
  }

  void _search() {
    if (_disposed || !_autoSearching) return;
    if (_status == ConnectionStatus.connected) {
      stopAutoSearch();
      return;
    }
    _searchTimer?.cancel();
    discovery.discover().then((servers) {
      if (_disposed) return;
      _foundServers = servers;
      notifyListeners();
      if (servers.isNotEmpty) {
        for (final s in servers) {
          if (s.url == _serverUrl) {
            _status = ConnectionStatus.connecting;
            notifyListeners();
            connectTo(s.url);
            return;
          }
        }
        if (_status != ConnectionStatus.connected) {
          connectTo(servers.first.url);
        }
      }
    }).whenComplete(() {
      if (_disposed || !_autoSearching) return;
      _searchTimer = Timer(const Duration(seconds: 4), _search);
    });
  }

  Future<void> discover() async {
    _status = ConnectionStatus.connecting;
    notifyListeners();
    final servers = await discovery.discover();
    _foundServers = servers;
    if (servers.isNotEmpty) {
      await connectTo(servers.first.url);
    } else {
      _status = ConnectionStatus.error;
      _errorMessage = "No se encontró servidor CocinaP en la red";
      notifyListeners();
    }
  }

  Future<void> connect() async {
    _status = ConnectionStatus.connecting;
    notifyListeners();

    try {
      final info = await api.getInfo();
      _version = info["version"] ?? "";
      _ips = List<String>.from(info["ips"] ?? []);
      _status = ConnectionStatus.connected;
      _errorMessage = "";
      await settings.setServerUrl(_serverUrl);
      await _loadRecents();
    } catch (e) {
      _status = ConnectionStatus.error;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  Future<void> _loadRecents() async {
    _recentServers = await settings.getRecentServers();
    notifyListeners();
  }

  Future<void> refreshRecents() => _loadRecents();

  Future<void> disconnect() async {
    stopAutoSearch();
    _status = ConnectionStatus.disconnected;
    _serverUrl = "";
    _errorMessage = "";
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _searchTimer?.cancel();
    super.dispose();
  }
}