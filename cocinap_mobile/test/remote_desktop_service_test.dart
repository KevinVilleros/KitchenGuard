import 'package:cocinap_mobile/services/remote_desktop_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts a Tailscale Serve HTTPS address', () {
    expect(
      RemoteDesktopService.parseBaseUrl(
        'https://kitchen-pc.example-tailnet.ts.net/',
      ),
      Uri.parse('https://kitchen-pc.example-tailnet.ts.net'),
    );
  });

  test('rejects insecure, public, and credential-bearing addresses', () {
    for (final address in [
      'http://kitchen-pc.example-tailnet.ts.net',
      'https://camera.example.com',
      'https://user:password@kitchen-pc.example-tailnet.ts.net',
      'https://kitchen-pc.example-tailnet.ts.net/path',
      'https://kitchen-pc.example-tailnet.ts.net/?api_key=secret',
      'https://kitchen-pc.example-tailnet.ts.net:8443',
    ]) {
      expect(
        () => RemoteDesktopService.parseBaseUrl(address),
        throwsFormatException,
        reason: address,
      );
    }
  });

  test('builds a stream endpoint without putting credentials in the URL', () {
    expect(
      RemoteDesktopService.buildStreamUri(
        'https://kitchen-pc.example-tailnet.ts.net',
      ),
      Uri.parse(
        'https://kitchen-pc.example-tailnet.ts.net/api/stream',
      ),
    );
  });

  test('validates the desktop-generated API key shape', () {
    final validKey = List.filled(64, 'a').join();
    expect(RemoteDesktopService.isValidApiKey(validKey), isTrue);
    expect(RemoteDesktopService.isValidApiKey(validKey.substring(1)), isFalse);
    expect(RemoteDesktopService.isValidApiKey(List.filled(64, 'z').join()),
        isFalse);
  });
}
