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

  ServerProvider(this.api, this.discovery, this.settings);

  ConnectionStatus get status => _status;
  String get serverUrl => _serverUrl;
  String get errorMessage => _errorMessage;
  String get version => _version;
  List<String> get ips => _ips;
  ApiService get apiService => api;

  void setServerUrl(String url) {
    _serverUrl = url;
    api.updateBaseUrl(url);
    notifyListeners();
  }

  Future<void> autoConnect() async {
    final saved = await settings.getServerUrl();
    if (saved != null && saved.isNotEmpty) {
      setServerUrl(saved);
      await connect();
    }
    if (_status != ConnectionStatus.connected) {
      await discover();
    }
  }

  Future<void> discover() async {
    _status = ConnectionStatus.connecting;
    notifyListeners();

    final url = await discovery.discover();
    if (url != null) {
      setServerUrl(url);
      await settings.setServerUrl(url);
      await connect();
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
      await settings.setServerUrl(_serverUrl);
    } catch (e) {
      _status = ConnectionStatus.error;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  Future<void> disconnect() async {
    _status = ConnectionStatus.disconnected;
    _serverUrl = "";
    _errorMessage = "";
    notifyListeners();
  }
}
