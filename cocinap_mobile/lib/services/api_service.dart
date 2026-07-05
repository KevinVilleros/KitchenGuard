import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  String _baseUrl;

  ApiService(this._baseUrl);

  String get baseUrl => _baseUrl;

  void updateBaseUrl(String url) {
    _baseUrl = url.endsWith("/") ? url.substring(0, url.length - 1) : url;
  }

  Future<Map<String, dynamic>> getStatus() async {
    final r = await http.get(Uri.parse("$_baseUrl/api/status"))
        .timeout(const Duration(seconds: 3));
    return json.decode(r.body);
  }

  Future<Map<String, dynamic>> getConfig() async {
    final r = await http.get(Uri.parse("$_baseUrl/api/config"))
        .timeout(const Duration(seconds: 3));
    return json.decode(r.body);
  }

  Future<bool> updateConfig(Map<String, dynamic> updates) async {
    final r = await http.post(
      Uri.parse("$_baseUrl/api/config"),
      headers: {"Content-Type": "application/json"},
      body: json.encode(updates),
    ).timeout(const Duration(seconds: 5));
    final data = json.decode(r.body);
    return data["ok"] == true;
  }

  Future<bool> registerToken(String token) async {
    final r = await http.post(
      Uri.parse("$_baseUrl/api/register_token"),
      headers: {"Content-Type": "application/json"},
      body: json.encode({"token": token}),
    ).timeout(const Duration(seconds: 5));
    final data = json.decode(r.body);
    return data["ok"] == true;
  }

  Future<void> unregisterToken(String token) async {
    await http.post(
      Uri.parse("$_baseUrl/api/unregister_token"),
      headers: {"Content-Type": "application/json"},
      body: json.encode({"token": token}),
    ).timeout(const Duration(seconds: 5));
  }

  Future<Map<String, dynamic>> getInfo() async {
    final r = await http.get(Uri.parse("$_baseUrl/api/info"))
        .timeout(const Duration(seconds: 3));
    return json.decode(r.body);
  }

  String get streamUrl => "$_baseUrl/api/stream";
}
