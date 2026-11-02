import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:cocinap_mobile/services/onvif_camera_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

void main() {
  test('ONVIF discovery sends a valid probe with retry intervals', () {
    const discoveryId = 'urn:uuid:camera-probe-test';
    final probe = XmlDocument.parse(buildOnvifProbe(discoveryId));

    expect(
      probe.descendants
          .whereType<XmlElement>()
          .firstWhere((element) => element.localName == 'MessageID')
          .innerText,
      discoveryId,
    );
    expect(
      probe.descendants
          .whereType<XmlElement>()
          .firstWhere((element) => element.localName == 'Types')
          .innerText,
      'dn:NetworkVideoTransmitter',
    );
    expect(
      onvifProbeSchedule(),
      const [
        Duration.zero,
        Duration(seconds: 2),
        Duration(seconds: 4),
      ],
    );
    expect(onvifDiscoveryTimeout, const Duration(seconds: 6));
  });

  group('ONVIF HTTP authentication', () {
    for (final scheme in ['Basic', 'Digest']) {
      test('retries SOAP requests with HTTP $scheme authentication', () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final receivedAuthorizedRequests = <String>[];
        final serverDone = server.listen((request) async {
          final body = await utf8.decoder.bind(request).join();
          final authorization = request.headers.value(
            HttpHeaders.authorizationHeader,
          );
          if (authorization == null) {
            request.response.statusCode = HttpStatus.unauthorized;
            request.response.headers.set(
              HttpHeaders.wwwAuthenticateHeader,
              scheme == 'Basic'
                  ? 'Basic realm="onvif-test"'
                  : 'Digest realm="onvif-test", nonce="test-nonce", qop="auth", algorithm=MD5',
            );
            await request.response.close();
            return;
          }

          expect(authorization, startsWith('$scheme '));
          if (scheme == 'Digest') {
            final fields = <String, String>{};
            for (final match in RegExp(r'(\w+)="([^"]*)"|(\w+)=([^,\s]+)')
                .allMatches(authorization)) {
              fields[match[1] ?? match[3]!] = match[2] ?? match[4]!;
            }
            final ha1 = md5
                .convert(utf8.encode('test-user:onvif-test:test-password'))
                .toString();
            final ha2 =
                md5.convert(utf8.encode('POST:${fields['uri']}')).toString();
            final expectedResponse = md5
                .convert(utf8.encode(
                    '$ha1:test-nonce:${fields['nc']}:${fields['cnonce']}:auth:$ha2'))
                .toString();
            expect(fields['response'], expectedResponse);
          }
          receivedAuthorizedRequests.add(body);
          request.response.headers.set(
            HttpHeaders.contentTypeHeader,
            'application/soap+xml; charset=utf-8',
          );
          if (body.contains('GetCapabilities')) {
            request.response.write('''
<s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope" xmlns:tds="http://www.onvif.org/ver10/device/wsdl" xmlns:tt="http://www.onvif.org/ver10/schema">
  <s:Body><tds:GetCapabilitiesResponse><tds:Capabilities><tt:Media><tt:XAddr>http://127.0.0.1:${server.port}/media</tt:XAddr></tt:Media></tds:Capabilities></tds:GetCapabilitiesResponse></s:Body>
</s:Envelope>
''');
          } else if (body.contains('GetProfiles')) {
            request.response.write('''
<s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope" xmlns:trt="http://www.onvif.org/ver10/media/wsdl">
  <s:Body><trt:GetProfilesResponse><trt:Profiles token="profile-1"/></trt:GetProfilesResponse></s:Body>
</s:Envelope>
''');
          } else {
            request.response.write('''
<s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope" xmlns:tt="http://www.onvif.org/ver10/schema">
  <s:Body><tt:GetStreamUriResponse><tt:MediaUri><tt:Uri>rtsp://127.0.0.1:554/stream</tt:Uri></tt:MediaUri></tt:GetStreamUriResponse></s:Body>
</s:Envelope>
''');
          }
          await request.response.close();
        });

        addTearDown(() async {
          await server.close(force: true);
          await serverDone.cancel();
        });

        final camera = OnvifCamera(
          name: 'Test camera',
          address: '127.0.0.1',
          deviceService: Uri(
            scheme: 'http',
            host: '127.0.0.1',
            port: server.port,
            path: '/device',
          ),
        );
        final streamUri = await OnvifCameraService().getStreamUri(
          camera,
          username: 'test-user',
          password: 'test-password',
        );

        expect(streamUri.host, '127.0.0.1');
        expect(streamUri.path, '/stream');
        expect(receivedAuthorizedRequests, hasLength(3));
      });
    }
  });

  group('ONVIF discovery response parsing', () {
    test('extracts local device endpoint and friendly name', () {
      const response = '''
<e:Envelope xmlns:e="http://www.w3.org/2003/05/soap-envelope"
  xmlns:d="http://schemas.xmlsoap.org/ws/2005/04/discovery">
  <e:Body><d:ProbeMatches><d:ProbeMatch>
    <d:Scopes>onvif://www.onvif.org/name/Kitchen%20Camera</d:Scopes>
    <d:XAddrs>http://192.168.1.56:80/onvif/device_service</d:XAddrs>
  </d:ProbeMatch></d:ProbeMatches></e:Body>
</e:Envelope>
''';

      final camera =
          OnvifCameraService.parseProbeResponse(response, '192.168.1.56');

      expect(camera, isNotNull);
      expect(camera!.name, 'Kitchen Camera');
      expect(camera.address, '192.168.1.56');
      expect(camera.deviceService.path, '/onvif/device_service');
    });

    test('rejects an endpoint that does not match the responding device', () {
      const response = '''
<e:Envelope xmlns:e="http://www.w3.org/2003/05/soap-envelope"
  xmlns:d="http://schemas.xmlsoap.org/ws/2005/04/discovery">
  <e:Body><d:ProbeMatches><d:ProbeMatch>
    <d:XAddrs>http://example.com/onvif/device_service</d:XAddrs>
  </d:ProbeMatch></d:ProbeMatches></e:Body>
</e:Envelope>
''';

      expect(
        OnvifCameraService.parseProbeResponse(response, '192.168.1.56'),
        isNull,
      );
    });

    test('rejects a discovery endpoint containing embedded credentials', () {
      const response = '''
<e:Envelope xmlns:e="http://www.w3.org/2003/05/soap-envelope"
  xmlns:d="http://schemas.xmlsoap.org/ws/2005/04/discovery">
  <e:Body><d:ProbeMatches><d:ProbeMatch>
    <d:XAddrs>http://user:password@192.168.1.56/onvif/device_service</d:XAddrs>
  </d:ProbeMatch></d:ProbeMatches></e:Body>
</e:Envelope>
''';

      expect(
        OnvifCameraService.parseProbeResponse(response, '192.168.1.56'),
        isNull,
      );
    });

    test('uses the sender-matching local endpoint when several are returned',
        () {
      const response = '''
<e:Envelope xmlns:e="http://www.w3.org/2003/05/soap-envelope"
  xmlns:d="http://schemas.xmlsoap.org/ws/2005/04/discovery">
  <e:Body><d:ProbeMatches><d:ProbeMatch>
    <d:XAddrs>http://camera.example/onvif/device_service http://192.168.1.56:8080/onvif/device_service</d:XAddrs>
  </d:ProbeMatch></d:ProbeMatches></e:Body>
</e:Envelope>
''';

      final camera =
          OnvifCameraService.parseProbeResponse(response, '192.168.1.56');

      expect(camera, isNotNull);
      expect(camera!.deviceService.host, '192.168.1.56');
      expect(camera.deviceService.port, 8080);
    });

    test('returns a safe fallback name when the response has no name scope',
        () {
      const response = '''
<e:Envelope xmlns:e="http://www.w3.org/2003/05/soap-envelope"
  xmlns:d="http://schemas.xmlsoap.org/ws/2005/04/discovery">
  <e:Body><d:ProbeMatches><d:ProbeMatch>
    <d:XAddrs>http://192.168.1.56/onvif/device_service</d:XAddrs>
  </d:ProbeMatch></d:ProbeMatches></e:Body>
</e:Envelope>
''';

      final camera =
          OnvifCameraService.parseProbeResponse(response, '192.168.1.56');

      expect(camera, isNotNull);
      expect(camera!.name, 'Camera at 192.168.1.56');
    });
  });
}
