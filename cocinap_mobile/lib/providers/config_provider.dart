import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class ConfigProvider extends ChangeNotifier {
  final ApiService api;
  Map<String, dynamic> _config = {};
  bool _loading = false;

  ConfigProvider(this.api);

  Map<String, dynamic> get config => _config;
  bool get loading => _loading;

  Future<void> loadConfig() async {
    _loading = true;
    notifyListeners();

    try {
      _config = await api.getConfig();
    } catch (_) {}

    _loading = false;
    notifyListeners();
  }

  Future<bool> updateConfig(Map<String, dynamic> updates) async {
    final ok = await api.updateConfig(updates);
    if (ok) {
      _config.addAll(updates);
      notifyListeners();
    }
    return ok;
  }
}
