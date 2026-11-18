import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cocinap_mobile/services/remote_camera_server.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const apiKey =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
  final server = RemoteCameraServer.instance;
  final client = HttpClient();

  tearDownAll(() {
    client.close(force: true);
  });

  tearDown(() async {
    await server.stop();
  });

  test('desktop API requires the key in the request header', () async {
    await server.start(
      apiKey: apiKey,
      getFrame: () => Uint8List.fromList([1, 2, 3]),
      getFrameTime: DateTime.now,
      port: 0,
    );

    final request = await client.getUrl(
      Uri.parse('http://127.0.0.1:${server.port}/api/info?api_key=$apiKey'),
    );
    final response = await request.close();

    expect(response.statusCode, HttpStatus.unauthorized);
  });

  test('desktop info reports an authenticated live camera', () async {
    await server.start(
      apiKey: apiKey,
      getFrame: () => Uint8List.fromList([1, 2, 3]),
      getFrameTime: DateTime.now,
      port: 0,
    );

    final request = await client.getUrl(
      Uri.parse('http://127.0.0.1:${server.port}/api/info'),
    );
    request.headers.set('X-API-Key', apiKey);
    final response = await request.close();
    final body = jsonDecode(await response.transform(utf8.decoder).join());

    expect(response.statusCode, HttpStatus.ok);
    expect(body, {
      'app': 'CocinaP',
      'auth_required': true,
      'camera_ok': true,
    });
  });

  test('desktop stream reports unavailable camera with HTTP 503', () async {
    await server.start(
      apiKey: apiKey,
      getFrame: () => null,
      getFrameTime: () => null,
      port: 0,
    );

    final request = await client.getUrl(
      Uri.parse('http://127.0.0.1:${server.port}/api/stream'),
    );
    request.headers.set('X-API-Key', apiKey);
    final response = await request.close();

    expect(response.statusCode, HttpStatus.serviceUnavailable);
  });

  test('desktop stream sends authenticated MJPEG frames', () async {
    final jpeg = Uint8List.fromList([0xff, 0xd8, 0xff, 0xd9]);
    await server.start(
      apiKey: apiKey,
      getFrame: () => Uint8List.fromList(jpeg),
      getFrameTime: DateTime.now,
      port: 0,
    );

    final request = await client.getUrl(
      Uri.parse('http://127.0.0.1:${server.port}/api/stream'),
    );
    request.headers.set('X-API-Key', apiKey);
    final response = await request.close();
    final expectedPart = [
      ...ascii.encode(
        '--frame\r\nContent-Type: image/jpeg\r\n'
        'Content-Length: ${jpeg.length}\r\n\r\n',
      ),
      ...jpeg,
      ...ascii.encode('\r\n'),
    ];
    final chunks = BytesBuilder();
    final firstFrame = Completer<List<int>>();
    final subscription = response.listen((chunk) {
      chunks.add(chunk);
      if (chunks.length >= expectedPart.length && !firstFrame.isCompleted) {
        firstFrame.complete(chunks.takeBytes());
      }
    });

    expect(response.statusCode, HttpStatus.ok);
    expect(
      response.headers.value(HttpHeaders.contentTypeHeader),
      'multipart/x-mixed-replace; boundary=frame',
    );
    final frame = await firstFrame.future.timeout(const Duration(seconds: 2));
    expect(frame.take(expectedPart.length).toList(), expectedPart);
    await subscription.cancel();
  });

  test('local cloud publisher stream needs no remote API key', () async {
    final jpeg = Uint8List.fromList([0xff, 0xd8, 0xff, 0xd9]);
    await server.start(
      apiKey: apiKey,
      getFrame: () => jpeg,
      getFrameTime: DateTime.now,
      port: 0,
    );

    final request = await client.getUrl(
      Uri.parse(
        'http://127.0.0.1:${server.port}/internal/publish-stream',
      ),
    );
    final response = await request.close();
    expect(response.statusCode, HttpStatus.ok);
    expect(
      response.headers.value(HttpHeaders.contentTypeHeader),
      'multipart/x-mixed-replace; boundary=frame',
    );
    await response.listen((_) {}).cancel();
  });

  test('desktop host rejects malformed API keys', () {
    expect(
      () => server.start(
        apiKey: 'not-a-key',
        getFrame: () => null,
        getFrameTime: () => null,
        port: 0,
      ),
      throwsFormatException,
    );
  });
}
