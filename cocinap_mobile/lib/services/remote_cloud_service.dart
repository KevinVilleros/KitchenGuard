import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

class RemoteCloudCredentials {
  static const defaultGatewayUrl =
      'https://cocinap-livekit-gateway.kevinvilleros77.workers.dev';

  final String gatewayUrl;
  final String deviceId;
  final String ownerKey;
  final String viewerKey;

  const RemoteCloudCredentials({
    required this.gatewayUrl,
    required this.deviceId,
    required this.ownerKey,
    required this.viewerKey,
  });

  factory RemoteCloudCredentials.create({required String gatewayUrl}) {
    final normalizedUrl = normalizeGatewayUrl(gatewayUrl);
    final random = Random.secure();
    String randomHex(int length) => List<int>.generate(
          length,
          (_) => random.nextInt(256),
        ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();

    return RemoteCloudCredentials(
      gatewayUrl: normalizedUrl,
      deviceId: randomHex(16),
      ownerKey: randomHex(32),
      viewerKey: randomHex(32),
    );
  }

  factory RemoteCloudCredentials.fromInvite(String value) {
    final decoded = jsonDecode(value);
    if (decoded is! Map<String, dynamic> ||
        decoded['version'] != 1 ||
        decoded['deviceId'] is! String ||
        decoded['viewerKey'] is! String ||
        decoded['gatewayUrl'] is! String) {
      throw const FormatException('El QR de CocinaP no es válido.');
    }

    final gatewayUrl = normalizeGatewayUrl(decoded['gatewayUrl'] as String);
    final deviceId = decoded['deviceId'] as String;
    final viewerKey = decoded['viewerKey'] as String;
    if (!_deviceIdPattern.hasMatch(deviceId) ||
        !_secretPattern.hasMatch(viewerKey)) {
      throw const FormatException('El QR de CocinaP no es válido.');
    }

    return RemoteCloudCredentials(
      gatewayUrl: gatewayUrl,
      deviceId: deviceId.toLowerCase(),
      ownerKey: '',
      viewerKey: viewerKey.toLowerCase(),
    );
  }

  static final _deviceIdPattern =
      RegExp(r'^[a-f0-9]{32}$', caseSensitive: false);
  static final _secretPattern = RegExp(r'^[a-f0-9]{64}$', caseSensitive: false);

  static String normalizeGatewayUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        uri.scheme.toLowerCase() != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort && uri.port != 443 ||
        uri.path.isNotEmpty && uri.path != '/' ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException(
        'La dirección del servicio debe ser una URL HTTPS válida.',
      );
    }
    return uri.replace(path: '', query: null, fragment: null).toString();
  }

  String toInvite() => jsonEncode({
        'version': 1,
        'gatewayUrl': gatewayUrl,
        'deviceId': deviceId,
        'viewerKey': viewerKey,
      });

  Map<String, String> toJson() => {
        'gatewayUrl': gatewayUrl,
        'deviceId': deviceId,
        'ownerKey': ownerKey,
        'viewerKey': viewerKey,
      };

  factory RemoteCloudCredentials.fromJson(Map<String, dynamic> json) {
    final gatewayUrl = normalizeGatewayUrl(json['gatewayUrl'] as String);
    final deviceId = json['deviceId'] as String;
    final ownerKey = json['ownerKey'] as String? ?? '';
    final viewerKey = json['viewerKey'] as String;
    if (!_deviceIdPattern.hasMatch(deviceId) ||
        ownerKey.isNotEmpty && !_secretPattern.hasMatch(ownerKey) ||
        !_secretPattern.hasMatch(viewerKey)) {
      throw const FormatException(
          'La configuración de CocinaP Cloud no es válida.');
    }
    return RemoteCloudCredentials(
      gatewayUrl: gatewayUrl,
      deviceId: deviceId.toLowerCase(),
      ownerKey: ownerKey.toLowerCase(),
      viewerKey: viewerKey.toLowerCase(),
    );
  }
}

class CloudIngress {
  final Uri url;
  final String streamKey;

  const CloudIngress({required this.url, required this.streamKey});
}

class CloudViewerToken {
  final Uri serverUrl;
  final String token;

  const CloudViewerToken({required this.serverUrl, required this.token});
}

class RemoteCloudService {
  static final _deviceKeyPattern = RegExp(r'^[a-fA-F0-9]{64}$');

  static bool isValidDeviceKey(String value) =>
      _deviceKeyPattern.hasMatch(value);

  static Uri _endpoint(String gatewayUrl, String path) =>
      Uri.parse(RemoteCloudCredentials.normalizeGatewayUrl(gatewayUrl))
          .replace(path: path);

  Future<void> registerDevice(RemoteCloudCredentials credentials) async {
    if (credentials.ownerKey.isEmpty) {
      throw const FormatException('Falta la clave de administración del PC.');
    }
    await _post(
      _endpoint(credentials.gatewayUrl, '/v1/devices/register'),
      {
        'deviceId': credentials.deviceId,
        'ownerKey': credentials.ownerKey,
        'viewerKey': credentials.viewerKey,
      },
      expectedStatus: HttpStatus.created,
    );
  }

  Future<CloudIngress> getIngress(
    RemoteCloudCredentials credentials,
  ) async {
    if (credentials.ownerKey.isEmpty) {
      throw const FormatException('Falta la clave de administración del PC.');
    }
    final result = await _post(
      _endpoint(credentials.gatewayUrl, '/v1/devices/ingress'),
      {
        'deviceId': credentials.deviceId,
        'ownerKey': credentials.ownerKey,
      },
    );
    final url = Uri.tryParse(result['url'] as String? ?? '');
    final streamKey = result['streamKey'];
    if (url == null ||
        url.scheme != 'rtmps' ||
        url.host.isEmpty ||
        url.userInfo.isNotEmpty ||
        streamKey is! String ||
        streamKey.isEmpty ||
        streamKey.contains('/') ||
        streamKey.contains('?') ||
        streamKey.contains('#')) {
      throw const FormatException(
          'El gateway devolvió una entrada RTMP inválida.');
    }
    return CloudIngress(url: url, streamKey: streamKey);
  }

  Future<CloudViewerToken> requestViewerToken(
    RemoteCloudCredentials credentials,
  ) async {
    final result = await _post(
      _endpoint(credentials.gatewayUrl, '/v1/devices/token'),
      {
        'deviceId': credentials.deviceId,
        'viewerKey': credentials.viewerKey,
      },
    );
    final serverUrl = Uri.tryParse(result['serverUrl'] as String? ?? '');
    final token = result['token'];
    if (serverUrl == null ||
        serverUrl.scheme != 'wss' ||
        serverUrl.host.isEmpty ||
        serverUrl.userInfo.isNotEmpty ||
        token is! String ||
        token.isEmpty) {
      throw const FormatException('El gateway devolvió un token inválido.');
    }
    return CloudViewerToken(serverUrl: serverUrl, token: token);
  }

  Future<CloudViewerToken> requestHostToken(
    RemoteCloudCredentials credentials,
  ) async {
    if (credentials.ownerKey.isEmpty) {
      throw const FormatException('Falta la clave de administración del PC.');
    }
    final result = await _post(
      _endpoint(credentials.gatewayUrl, '/v1/devices/host-token'),
      {
        'deviceId': credentials.deviceId,
        'ownerKey': credentials.ownerKey,
      },
    );
    final serverUrl = Uri.tryParse(result['serverUrl'] as String? ?? '');
    final token = result['token'];
    if (serverUrl == null ||
        serverUrl.scheme != 'wss' ||
        serverUrl.host.isEmpty ||
        serverUrl.userInfo.isNotEmpty ||
        token is! String ||
        token.isEmpty) {
      throw const FormatException('El gateway devolvió un token inválido.');
    }
    return CloudViewerToken(serverUrl: serverUrl, token: token);
  }

  Future<Map<String, dynamic>> _post(Uri uri, Map<String, String> payload,
      {int expectedStatus = HttpStatus.ok}) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..idleTimeout = const Duration(seconds: 10);
    try {
      final request = await client.postUrl(uri).timeout(
            const Duration(seconds: 10),
          );
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
      request.write(jsonEncode(payload));
      final response = await request.close().timeout(
            const Duration(seconds: 10),
          );
      final bytes =
          await response.fold<BytesBuilder>(BytesBuilder(), (builder, chunk) {
        if (builder.length + chunk.length > 16 * 1024) {
          throw const FormatException(
              'Respuesta del gateway demasiado grande.');
        }
        builder.add(chunk);
        return builder;
      }).timeout(const Duration(seconds: 10));
      if (response.statusCode != expectedStatus) {
        throw HttpException(
          'El gateway respondió con HTTP ${response.statusCode}.',
          uri: uri,
        );
      }
      final body = jsonDecode(utf8.decode(bytes.takeBytes()));
      if (body is! Map<String, dynamic>) {
        throw const FormatException(
            'El gateway devolvió una respuesta inválida.');
      }
      return body;
    } finally {
      client.close(force: true);
    }
  }
}
