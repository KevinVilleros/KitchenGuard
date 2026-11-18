import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class RemoteDesktopService {
  static const _responseLimit = 64 * 1024;
  static final _apiKeyPattern = RegExp(r'^[a-fA-F0-9]{64}$');

  static Uri parseBaseUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        uri.scheme.toLowerCase() != 'https' ||
        !uri.host.toLowerCase().endsWith('.ts.net') ||
        (uri.hasPort && uri.port != 443) ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.userInfo.isNotEmpty) {
      throw const FormatException(
        'Use the HTTPS Tailscale Serve address ending in .ts.net.',
      );
    }
    return uri.replace(path: '', query: null, fragment: null);
  }

  static bool isValidApiKey(String value) => _apiKeyPattern.hasMatch(value);

  static Uri buildStreamUri(String baseUrl) =>
      parseBaseUrl(baseUrl).replace(path: '/api/stream');

  static Uri? tryBuildStreamUri(String baseUrl) {
    try {
      return buildStreamUri(baseUrl);
    } on FormatException {
      return null;
    }
  }

  static Uri _buildInfoUri(Uri baseUrl) => baseUrl.replace(path: '/api/info');

  Future<bool> verifyConnection({
    required String baseUrl,
    required String apiKey,
  }) async {
    final parsedBaseUrl = parseBaseUrl(baseUrl);
    if (!isValidApiKey(apiKey)) {
      throw const FormatException(
        'The CocinaP API key must be copied from the desktop app.',
      );
    }

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8)
      ..idleTimeout = const Duration(seconds: 8);
    try {
      final request = await client
          .getUrl(_buildInfoUri(parsedBaseUrl))
          .timeout(const Duration(seconds: 8));
      request.headers.set('X-API-Key', apiKey);
      final response = await request.close().timeout(
            const Duration(seconds: 8),
          );
      final body =
          await response.fold<BytesBuilder>(BytesBuilder(), (builder, chunk) {
        if (builder.length + chunk.length > _responseLimit) {
          throw const FormatException(
            'Desktop returned an oversized status response.',
          );
        }
        builder.add(chunk);
        return builder;
      }).timeout(const Duration(seconds: 8));

      if (response.statusCode == HttpStatus.unauthorized) {
        throw const HttpException(
          'API key incorrecta o acceso remoto no autorizado.',
        );
      }
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'La PC respondió con HTTP ${response.statusCode}.',
        );
      }

      final decoded = jsonDecode(utf8.decode(body.takeBytes()));
      if (decoded is! Map<String, dynamic> ||
          decoded['app'] != 'CocinaP' ||
          decoded['auth_required'] != true) {
        throw const FormatException(
          'El servidor no parece ser una instalación autenticada de CocinaP.',
        );
      }
      return decoded['camera_ok'] == true;
    } finally {
      client.close(force: true);
    }
  }
}
