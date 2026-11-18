import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

class RemoteCameraServer {
  RemoteCameraServer._();

  static final instance = RemoteCameraServer._();
  static final _apiKeyPattern = RegExp(r'^[a-fA-F0-9]{64}$');

  HttpServer? _server;
  StreamSubscription<HttpRequest>? _requests;
  final Map<HttpResponse, Future<void>> _responseClosures = {};
  String? _apiKey;
  Uint8List? Function()? _getFrame;
  DateTime? Function()? _getFrameTime;
  final Set<HttpResponse> _streamResponses = {};

  bool get isRunning => _server != null;
  int? get port => _server?.port;

  Future<void> start({
    required String apiKey,
    required Uint8List? Function() getFrame,
    required DateTime? Function() getFrameTime,
    int port = 8080,
  }) async {
    if (isRunning) return;
    if (!_apiKeyPattern.hasMatch(apiKey)) {
      throw const FormatException(
          'Desktop API key must be 64 hexadecimal characters.');
    }

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    _apiKey = apiKey;
    _getFrame = getFrame;
    _getFrameTime = getFrameTime;
    _server = server;
    _requests = server.listen(
      (request) => unawaited(_dispatchRequest(server, request)),
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Remote camera server error: $error');
      },
    );
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    _apiKey = null;
    _getFrame = null;
    _getFrameTime = null;
    await _requests?.cancel();
    _requests = null;
    for (final response in _streamResponses.toList()) {
      await _closeResponse(response);
    }
    _streamResponses.clear();
    await server?.close(force: true);
  }

  Future<void> _dispatchRequest(HttpServer server, HttpRequest request) async {
    try {
      await _handleRequest(server, request);
    } catch (error, stackTrace) {
      debugPrint('Remote camera request failed: $error\n$stackTrace');
      await _closeResponse(request.response);
    }
  }

  Future<void> _handleRequest(HttpServer server, HttpRequest request) async {
    if (server != _server) return;
    if (request.method != 'GET') {
      await _sendJson(request.response, HttpStatus.methodNotAllowed, {
        'error': 'method_not_allowed',
      });
      return;
    }

    if (request.uri.path == '/api/info') {
      if (!_isAuthorized(request)) {
        await _sendJson(request.response, HttpStatus.unauthorized, {
          'error': 'unauthorized',
        });
        return;
      }
      await _sendJson(request.response, HttpStatus.ok, {
        'app': 'CocinaP',
        'auth_required': true,
        'camera_ok': _cameraIsAvailable(),
      });
      return;
    }

    if (request.uri.path == '/api/stream') {
      if (!_isAuthorized(request)) {
        await _sendJson(request.response, HttpStatus.unauthorized, {
          'error': 'unauthorized',
        });
        return;
      }
      await _streamFrames(server, request);
      return;
    }

    if (request.uri.path == '/internal/publish-stream') {
      if (request.connectionInfo?.remoteAddress.address != '127.0.0.1') {
        await _sendJson(request.response, HttpStatus.forbidden, {
          'error': 'local_access_only',
        });
        return;
      }
      await _streamFrames(server, request);
      return;
    }

    await _sendJson(request.response, HttpStatus.notFound, {
      'error': 'not_found',
    });
  }

  bool _isAuthorized(HttpRequest request) {
    final supplied = request.headers.value('X-API-Key');
    final expected = _apiKey;
    if (supplied == null ||
        expected == null ||
        supplied.length != expected.length) {
      return false;
    }

    var difference = 0;
    for (var index = 0; index < expected.length; index++) {
      difference |= supplied.codeUnitAt(index) ^ expected.codeUnitAt(index);
    }
    return difference == 0;
  }

  bool _cameraIsAvailable() {
    final frame = _getFrame?.call();
    final capturedAt = _getFrameTime?.call();
    return frame != null &&
        capturedAt != null &&
        DateTime.now().difference(capturedAt) <= const Duration(seconds: 5);
  }

  Future<void> _streamFrames(HttpServer server, HttpRequest request) async {
    if (!_cameraIsAvailable()) {
      await _sendJson(request.response, HttpStatus.serviceUnavailable, {
        'error': 'camera_unavailable',
      });
      return;
    }

    final response = request.response;
    _streamResponses.add(response);
    response.bufferOutput = false;
    response.headers
      ..set(
        HttpHeaders.contentTypeHeader,
        'multipart/x-mixed-replace; boundary=frame',
      )
      ..set(HttpHeaders.cacheControlHeader, 'no-store')
      ..set(HttpHeaders.connectionHeader, 'close')
      ..set('X-Content-Type-Options', 'nosniff');
    var lastFrame = _getFrame?.call();
    var lastFrameAt = _getFrameTime?.call();
    try {
      while (server == _server) {
        final frame = _getFrame?.call();
        final capturedAt = _getFrameTime?.call();
        if (frame == null ||
            capturedAt == null ||
            DateTime.now().difference(capturedAt) >
                const Duration(seconds: 5)) {
          break;
        }
        if (!identical(frame, lastFrame) || capturedAt != lastFrameAt) {
          response.add(_mjpegPart(frame));
          await response.flush();
          lastFrame = frame;
          lastFrameAt = capturedAt;
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    } on IOException {
      // The client closed its stream; release the response and finish quietly.
    } finally {
      _streamResponses.remove(response);
      await _closeResponse(response);
      _responseClosures.remove(response);
    }
  }

  Future<void> _closeResponse(HttpResponse response) {
    return _responseClosures.putIfAbsent(
      response,
      () => _closeResponseOnce(response),
    );
  }

  Future<void> _closeResponseOnce(HttpResponse response) async {
    try {
      await response.close();
    } on IOException catch (error) {
      debugPrint('Remote camera client disconnected: $error');
    }
  }

  List<int> _mjpegPart(Uint8List jpeg) => [
        ...ascii.encode('--frame\r\n'),
        ...ascii.encode('Content-Type: image/jpeg\r\n'),
        ...ascii.encode('Content-Length: ${jpeg.length}\r\n\r\n'),
        ...jpeg,
        ...ascii.encode('\r\n'),
      ];

  Future<void> _sendJson(
    HttpResponse response,
    int statusCode,
    Map<String, Object> body,
  ) async {
    response
      ..statusCode = statusCode
      ..headers.contentType = ContentType.json
      ..headers.set(HttpHeaders.cacheControlHeader, 'no-store')
      ..headers.set('X-Content-Type-Options', 'nosniff');
    response.write(jsonEncode(body));
    await response.close();
  }
}
