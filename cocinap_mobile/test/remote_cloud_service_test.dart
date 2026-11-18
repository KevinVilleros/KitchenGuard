import 'package:cocinap_mobile/services/remote_cloud_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cloud credentials use the CocinaP gateway by default', () {
    expect(
      RemoteCloudCredentials.defaultGatewayUrl,
      'https://cocinap-livekit-gateway.kevinvilleros77.workers.dev',
    );
  });

  test('desktop credentials create a separate private phone invite', () {
    final credentials = RemoteCloudCredentials.create(
      gatewayUrl: 'https://cocinap.example.workers.dev/',
    );

    final phoneCredentials =
        RemoteCloudCredentials.fromInvite(credentials.toInvite());

    expect(credentials.deviceId, hasLength(32));
    expect(credentials.ownerKey, hasLength(64));
    expect(credentials.viewerKey, hasLength(64));
    expect(phoneCredentials.gatewayUrl, credentials.gatewayUrl);
    expect(phoneCredentials.deviceId, credentials.deviceId);
    expect(phoneCredentials.viewerKey, credentials.viewerKey);
    expect(phoneCredentials.ownerKey, isEmpty);
  });

  test('cloud credentials reject unsafe gateway URLs', () {
    for (final url in [
      'http://cocinap.example.workers.dev',
      'https://user:password@cocinap.example.workers.dev',
      'https://cocinap.example.workers.dev/path',
      'https://cocinap.example.workers.dev/?key=secret',
    ]) {
      expect(
        () => RemoteCloudCredentials.create(gatewayUrl: url),
        throwsFormatException,
        reason: url,
      );
    }
  });

  test('phone pairing rejects malformed or unsafe QR data', () {
    for (final value in [
      'not-json',
      '{"version":2,"gatewayUrl":"https://example.com","deviceId":"${'a' * 32}","viewerKey":"${'b' * 64}"}',
      '{"version":1,"gatewayUrl":"http://example.com","deviceId":"${'a' * 32}","viewerKey":"${'b' * 64}"}',
      '{"version":1,"gatewayUrl":"https://example.com","deviceId":"short","viewerKey":"${'b' * 64}"}',
    ]) {
      expect(
        () => RemoteCloudCredentials.fromInvite(value),
        throwsFormatException,
        reason: value,
      );
    }
  });
}
