import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import '../services/background_service.dart';

class AlarmsProvider extends ChangeNotifier {
  final ApiService api;
  http.Client? _client;
  StreamSubscription<String>? _sub;
  final List<Map<String, dynamic>> _alarms = [];
  bool _connected = false;

  AlarmsProvider(this.api);

  List<Map<String, dynamic>> get alarms => _alarms;
  bool get connected => _connected;

  void connect() {
    disconnect();
    _client = http.Client();
    _startSSE();
  }

  void _startSSE() async {
    try {
      final request = http.Request("GET", Uri.parse("${api.baseUrl}/api/events"));
      final response = await _client!.send(request);

      _connected = true;
      notifyListeners();

      _sub = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (line) {
          if (line.startsWith("data: ")) {
            final data = line.substring(6);
            try {
              final json = jsonDecode(data) as Map<String, dynamic>;
              if (json["_id"] != null) {
                _alarms.insert(0, json);
                if (_alarms.length > 50) _alarms.removeLast();
                notifyListeners();
                _triggerAlarmNotification(json);
              }
            } catch (_) {}
          }
        },
        onDone: () {
          _connected = false;
          notifyListeners();
        },
        onError: (_) {
          _connected = false;
          notifyListeners();
        },
      );
    } catch (_) {
      _connected = false;
      notifyListeners();
    }
  }

  void _triggerAlarmNotification(Map<String, dynamic> alarm) {
    final type = alarm["type"] as String? ?? "unknown";
    final msg = alarm["message"] as String? ?? type;
    BackgroundServiceManager.showAlarm(msg);
    BackgroundServiceManager.updateStatus("⚠️ $type");
  }

  void disconnect() {
    _sub?.cancel();
    _client?.close();
    _client = null;
    _connected = false;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
