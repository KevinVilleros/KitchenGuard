import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  String _baseUrl;
  String _apiKey = "";

  ApiService(this._baseUrl);

  String get baseUrl => _baseUrl;
  String get apiKey => _apiKey;

  void updateBaseUrl(String url) {
    _baseUrl = url.endsWith("/") ? url.substring(0, url.length - 1) : url;
  }

  void updateApiKey(String key) {
    _apiKey = key.trim();
  }

  Map<String, String> get _authHeaders => {
        "X-API-Key": _apiKey,
        "Content-Type": "application/json",
      };
  Map<String, String> get _getHeaders => {
        "X-API-Key": _apiKey,
      };

  Future<Map<String, dynamic>> getStatus() async {
    final r = await http.get(
      Uri.parse("$_baseUrl/api/status"),
      headers: _getHeaders,
    ).timeout(const Duration(seconds: 3));
    if (r.statusCode != 200) {
      throw Exception("Estado no disponible (${r.statusCode})");
    }
    return json.decode(r.body);
  }

  Future<Map<String, dynamic>> getConfig() async {
    final r = await http.get(
      Uri.parse("$_baseUrl/api/config"),
      headers: _getHeaders,
    ).timeout(const Duration(seconds: 3));
    if (r.statusCode != 200) {
      throw Exception("Config no disponible (${r.statusCode})");
    }
    return json.decode(r.body);
  }

  Future<bool> updateConfig(Map<String, dynamic> updates) async {
    final r = await http.post(
      Uri.parse("$_baseUrl/api/config"),
      headers: _authHeaders,
      body: json.encode(updates),
    ).timeout(const Duration(seconds: 5));
    if (r.statusCode != 200) return false;
    final data = json.decode(r.body);
    return data["ok"] == true;
  }

  Future<bool> registerToken(String token) async {
    final r = await http.post(
      Uri.parse("$_baseUrl/api/register_token"),
      headers: _authHeaders,
      body: json.encode({"token": token}),
    ).timeout(const Duration(seconds: 5));
    if (r.statusCode != 200) return false;
    final data = json.decode(r.body);
    return data["ok"] == true;
  }

  Future<void> unregisterToken(String token) async {
    await http.post(
      Uri.parse("$_baseUrl/api/unregister_token"),
      headers: _authHeaders,
      body: json.encode({"token": token}),
    ).timeout(const Duration(seconds: 5));
  }

  Future<Map<String, dynamic>> getInfo() async {
    final r = await http.get(
      Uri.parse("$_baseUrl/api/info"),
      headers: _getHeaders,
    ).timeout(const Duration(seconds: 3));
    if (r.statusCode != 200) {
      throw Exception("No autorizado (${r.statusCode})");
    }
    return json.decode(r.body);
  }

  /// Stream URL with API key as query param (for MJPEG/SSE raw sockets
  /// that cannot easily set headers).
  String get streamUrl => "$_baseUrl/api/stream?api_key=$_apiKey";
  String get eventsUrl => "$_baseUrl/api/events?api_key=$_apiKey";

  Future<Map<String, dynamic>> timerStart(int minutes) async {
    final r = await http.post(
      Uri.parse("$_baseUrl/api/timer/start"),
      headers: _authHeaders,
      body: json.encode({"minutes": minutes}),
    ).timeout(const Duration(seconds: 3));
    if (r.statusCode != 200) {
      throw Exception("Timer error (${r.statusCode})");
    }
    return json.decode(r.body);
  }

  Future<void> timerStop() async {
    await http.post(Uri.parse("$_baseUrl/api/timer/stop"), headers: _getHeaders)
        .timeout(const Duration(seconds: 3));
  }

  Future<void> timerPause() async {
    await http.post(Uri.parse("$_baseUrl/api/timer/pause"), headers: _getHeaders)
        .timeout(const Duration(seconds: 3));
  }

  Future<void> timerResume() async {
    await http.post(Uri.parse("$_baseUrl/api/timer/resume"), headers: _getHeaders)
        .timeout(const Duration(seconds: 3));
  }
}
