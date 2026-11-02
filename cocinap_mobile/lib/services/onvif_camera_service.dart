import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:xml/xml.dart';

@visibleForTesting
const onvifDiscoveryTimeout = Duration(seconds: 6);

@visibleForTesting
const onvifProbeRepeatInterval = Duration(seconds: 2);

@visibleForTesting
const onvifProbeMaxAttempts = 3;

@visibleForTesting
List<Duration> onvifProbeSchedule() => List.generate(
      onvifProbeMaxAttempts,
      (attempt) => Duration(
        milliseconds: onvifProbeRepeatInterval.inMilliseconds * attempt,
      ),
    );

@visibleForTesting
String buildOnvifProbe(String discoveryId) => '''
<e:Envelope xmlns:e="http://www.w3.org/2003/05/soap-envelope" xmlns:w="http://schemas.xmlsoap.org/ws/2004/08/addressing" xmlns:d="http://schemas.xmlsoap.org/ws/2005/04/discovery" xmlns:dn="http://www.onvif.org/ver10/network/wsdl">
  <e:Header>
    <w:MessageID>$discoveryId</w:MessageID>
    <w:To>urn:schemas-xmlsoap-org:ws:2005:04:discovery</w:To>
    <w:Action>http://schemas.xmlsoap.org/ws/2005/04/discovery/Probe</w:Action>
  </e:Header>
  <e:Body><d:Probe><d:Types>dn:NetworkVideoTransmitter</d:Types></d:Probe></e:Body>
</e:Envelope>
''';

class OnvifCamera {
  final String name;
  final String address;
  final Uri deviceService;

  const OnvifCamera({
    required this.name,
    required this.address,
    required this.deviceService,
  });
}

class OnvifCameraService {
  static const _multicastAddress = '239.255.255.250';
  static const _multicastPort = 3702;
  static const _androidMulticastChannel =
      MethodChannel('com.cocinap.mobile/local_network');
  static const _maxDevices = 32;
  static const _maxSoapResponseBytes = 1024 * 1024;

  Future<List<OnvifCamera>> discover({
    Duration timeout = onvifDiscoveryTimeout,
  }) async {
    if (Platform.isIOS) {
      throw UnsupportedError(
        'ONVIF multicast discovery requires an Apple-approved entitlement.',
      );
    }
    if (timeout <= Duration.zero) {
      throw ArgumentError.value(timeout, 'timeout', 'Must be positive.');
    }

    var multicastLockAcquired = false;
    StreamSubscription<RawSocketEvent>? subscription;
    final probeTimers = <Timer>[];
    Object? probeFailure;
    RawDatagramSocket? socket;
    try {
      if (Platform.isAndroid) {
        await _androidMulticastChannel
            .invokeMethod<void>('acquireMulticastLock');
        multicastLockAcquired = true;
      }
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0)
          .timeout(const Duration(seconds: 5));
      final cameras = <String, OnvifCamera>{};
      final done = Completer<void>();
      final id = List<int>.generate(16, (_) => Random.secure().nextInt(256))
          .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
          .join();
      final discoveryId =
          'urn:uuid:${id.substring(0, 8)}-${id.substring(8, 12)}-${id.substring(12, 16)}-${id.substring(16, 20)}-${id.substring(20)}';
      final probe = buildOnvifProbe(discoveryId);
      subscription = socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final datagram = socket?.receive();
        if (datagram == null) return;
        try {
          final camera = parseProbeResponse(
            utf8.decode(datagram.data, allowMalformed: true),
            datagram.address.address,
          );
          if (camera != null) {
            cameras.putIfAbsent(camera.address, () => camera);
            if (cameras.length >= _maxDevices && !done.isCompleted) {
              done.complete();
            }
          }
        } on FormatException {
          // Ignore unrelated or malformed multicast responses.
        } on XmlException {
          // Ignore unrelated or malformed multicast responses.
        }
      });

      var attempts = 0;
      void sendProbe() {
        if (done.isCompleted || attempts >= onvifProbeMaxAttempts) return;
        try {
          socket!.send(
            utf8.encode(probe),
            InternetAddress(_multicastAddress),
            _multicastPort,
          );
          attempts++;
        } catch (error) {
          probeFailure = error;
          if (!done.isCompleted) done.complete();
        }
      }

      for (final delay in onvifProbeSchedule()) {
        probeTimers.add(Timer(delay, sendProbe));
      }
      await Future.any<void>([
        done.future,
        Future<void>.delayed(timeout),
      ]);
      if (probeFailure != null && cameras.isEmpty) throw probeFailure!;
      return cameras.values.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } finally {
      for (final timer in probeTimers) {
        timer.cancel();
      }
      await subscription?.cancel();
      socket?.close();
      if (multicastLockAcquired) {
        await _androidMulticastChannel
            .invokeMethod<void>('releaseMulticastLock');
      }
    }
  }

  @visibleForTesting
  static OnvifCamera? parseProbeResponse(String response, String senderIp) {
    final document = XmlDocument.parse(response);
    final endpointText = _elements(document, 'XAddrs')
        .map((element) => element.innerText.trim())
        .where((value) => value.isNotEmpty)
        .expand((value) => value.split(RegExp(r'\s+')))
        .firstWhere(
      (value) {
        final uri = Uri.tryParse(value);
        return uri != null &&
            uri.scheme == 'http' &&
            uri.host == senderIp &&
            uri.userInfo.isEmpty &&
            uri.host.isNotEmpty;
      },
      orElse: () => '',
    );
    if (endpointText.isEmpty) return null;

    final deviceService = Uri.parse(endpointText);
    final scopes = _elements(document, 'Scopes')
        .map((element) => element.innerText.trim())
        .join(' ');
    final nameScope = scopes
        .split(RegExp(r'\s+'))
        .where((scope) => scope.contains('/name/'))
        .firstOrNull;
    final name = nameScope == null
        ? 'Camera at $senderIp'
        : Uri.decodeComponent(
            nameScope.substring(nameScope.indexOf('/name/') + 6));

    return OnvifCamera(
      name: name,
      address: senderIp,
      deviceService: deviceService,
    );
  }

  Future<Uri> getStreamUri(
    OnvifCamera camera, {
    required String username,
    required String password,
  }) async {
    final capabilities = await _soapRequest(
      camera.deviceService,
      'http://www.onvif.org/ver10/device/wsdl/GetCapabilities',
      '<tds:GetCapabilities><tds:Category>All</tds:Category></tds:GetCapabilities>',
      username,
      password,
    );
    final mediaEndpointText = _elements(capabilities, 'Media')
        .expand((media) => media.descendants.whereType<XmlElement>())
        .where((element) => element.localName == 'XAddr')
        .map((element) => element.innerText.trim())
        .firstWhere(
      (value) {
        final uri = Uri.tryParse(value);
        return uri != null &&
            uri.scheme == 'http' &&
            uri.host == camera.address &&
            uri.userInfo.isEmpty;
      },
      orElse: () => '',
    );
    if (mediaEndpointText.isEmpty) {
      throw const FormatException(
          'Camera did not provide a local media service.');
    }

    final mediaEndpoint = Uri.parse(mediaEndpointText);
    final profiles = await _soapRequest(
      mediaEndpoint,
      'http://www.onvif.org/ver10/media/wsdl/GetProfiles',
      '<trt:GetProfiles/>',
      username,
      password,
    );
    final profile = _elements(profiles, 'Profiles').firstOrNull;
    final profileToken = profile?.getAttribute('token');
    if (profileToken == null || profileToken.isEmpty) {
      throw const FormatException('Camera did not return a video profile.');
    }

    final streamResponse = await _soapRequest(
      mediaEndpoint,
      'http://www.onvif.org/ver10/media/wsdl/GetStreamUri',
      '<trt:GetStreamUri><trt:StreamSetup><tt:Stream>RTP-Unicast</tt:Stream><tt:Transport><tt:Protocol>RTSP</tt:Protocol></tt:Transport></trt:StreamSetup><trt:ProfileToken>${_xmlEscape(profileToken)}</trt:ProfileToken></trt:GetStreamUri>',
      username,
      password,
    );
    final streamText = _elements(streamResponse, 'Uri')
        .map((element) => element.innerText.trim())
        .firstOrNull;
    final streamUri = streamText == null ? null : Uri.tryParse(streamText);
    if (streamUri == null ||
        streamUri.scheme.toLowerCase() != 'rtsp' ||
        streamUri.host != camera.address) {
      throw const FormatException(
          'Camera returned an invalid local RTSP stream.');
    }

    if (username.isEmpty && password.isEmpty) return streamUri;
    return streamUri.replace(userInfo: '$username:$password');
  }

  Future<XmlDocument> _soapRequest(
    Uri endpoint,
    String action,
    String body,
    String username,
    String password,
  ) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final nonce = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    final passwordDigest = base64Encode(
      sha1.convert(
          [...nonce, ...utf8.encode(now), ...utf8.encode(password)]).bytes,
    );
    final envelope = '''
<s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope" xmlns:tds="http://www.onvif.org/ver10/device/wsdl" xmlns:trt="http://www.onvif.org/ver10/media/wsdl" xmlns:tt="http://www.onvif.org/ver10/schema" xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd" xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd">
  <s:Header><wsse:Security s:mustUnderstand="true"><wsse:UsernameToken>
    <wsse:Username>${_xmlEscape(username)}</wsse:Username>
    <wsse:Password Type="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#PasswordDigest">$passwordDigest</wsse:Password>
    <wsse:Nonce EncodingType="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-soap-message-security-1.0#Base64Binary">${base64Encode(nonce)}</wsse:Nonce>
    <wsu:Created>$now</wsu:Created>
  </wsse:UsernameToken></wsse:Security></s:Header>
  <s:Body>$body</s:Body>
</s:Envelope>
''';
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      Future<HttpClientResponse> sendRequest(String? authorization) async {
        final request = await client.postUrl(endpoint).timeout(
              const Duration(seconds: 5),
            );
        request.followRedirects = false;
        request.headers.set(
          HttpHeaders.contentTypeHeader,
          'application/soap+xml; charset=utf-8; action="$action"',
        );
        request.headers.set('SOAPAction', action);
        if (authorization != null) {
          request.headers.set(
            HttpHeaders.authorizationHeader,
            authorization,
          );
        }
        request.write(envelope);
        return request.close().timeout(const Duration(seconds: 8));
      }

      var response = await sendRequest(null);
      if (response.statusCode == HttpStatus.unauthorized &&
          (username.isNotEmpty || password.isNotEmpty)) {
        final challenges =
            response.headers[HttpHeaders.wwwAuthenticateHeader] ?? const [];
        await response.drain<void>().timeout(const Duration(seconds: 8));
        final authorization = _buildHttpAuthorization(
          endpoint,
          username,
          password,
          challenges,
        );
        if (authorization != null) {
          response = await sendRequest(authorization);
        }
      }

      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 8))) {
        if (bytes.length + chunk.length > _maxSoapResponseBytes) {
          throw const FormatException('Camera response is too large.');
        }
        bytes.addAll(chunk);
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Camera rejected the ONVIF request (HTTP ${response.statusCode}).',
          uri: endpoint,
        );
      }
      final document = XmlDocument.parse(utf8.decode(bytes));
      final fault = _elements(document, 'Fault').firstOrNull;
      if (fault != null) {
        throw const HttpException(
            'Camera did not authorize the ONVIF request.');
      }
      return document;
    } finally {
      client.close(force: true);
    }
  }

  static String? _buildHttpAuthorization(
    Uri endpoint,
    String username,
    String password,
    Iterable<String> challenges,
  ) {
    for (final challenge in challenges) {
      if (RegExp(r'^\s*Basic\b', caseSensitive: false).hasMatch(challenge)) {
        return 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
      }
      if (!RegExp(r'^\s*Digest\b', caseSensitive: false).hasMatch(challenge)) {
        continue;
      }

      final parameters = <String, String>{};
      final value = challenge.replaceFirst(
        RegExp(r'^\s*Digest\s+', caseSensitive: false),
        '',
      );
      final parameterPattern =
          RegExp(r'(\w+)\s*=\s*(?:"((?:\\.|[^"])*)"|([^,\s]+))');
      for (final match in parameterPattern.allMatches(value)) {
        parameters[match[1]!.toLowerCase()] = (match[2] ?? match[3]!)
            .replaceAll(r'\"', '"')
            .replaceAll(r'\\', '\\');
      }

      final realm = parameters['realm'];
      final nonce = parameters['nonce'];
      final algorithm = (parameters['algorithm'] ?? 'MD5').toUpperCase();
      final qopOptions =
          (parameters['qop'] ?? '').split(',').map((item) => item.trim());
      final qop = qopOptions.contains('auth') ? 'auth' : null;
      if (realm == null ||
          nonce == null ||
          !{'MD5', 'MD5-SESS'}.contains(algorithm) ||
          (parameters.containsKey('qop') && qop == null)) {
        continue;
      }

      final cnonce = List<int>.generate(16, (_) => Random.secure().nextInt(256))
          .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
          .join();
      const nonceCount = '00000001';
      final uri = endpoint.hasQuery
          ? '${endpoint.path}?${endpoint.query}'
          : endpoint.path;
      final initialHa1 =
          md5.convert(utf8.encode('$username:$realm:$password')).toString();
      final ha1 = algorithm == 'MD5-SESS'
          ? md5.convert(utf8.encode('$initialHa1:$nonce:$cnonce')).toString()
          : initialHa1;
      final ha2 = md5.convert(utf8.encode('POST:$uri')).toString();
      final digest = qop == null
          ? md5.convert(utf8.encode('$ha1:$nonce:$ha2')).toString()
          : md5
              .convert(utf8.encode('$ha1:$nonce:$nonceCount:$cnonce:$qop:$ha2'))
              .toString();
      final fields = <String>[
        'username="${_quoteHttpAuth(username)}"',
        'realm="${_quoteHttpAuth(realm)}"',
        'nonce="${_quoteHttpAuth(nonce)}"',
        'uri="${_quoteHttpAuth(uri)}"',
        'response="$digest"',
        if (parameters.containsKey('algorithm')) 'algorithm=$algorithm',
        if (qop != null) 'qop=$qop',
        if (qop != null) 'nc=$nonceCount',
        if (qop != null) 'cnonce="${_quoteHttpAuth(cnonce)}"',
        if (parameters['opaque'] case final opaque?)
          'opaque="${_quoteHttpAuth(opaque)}"',
      ];
      return 'Digest ${fields.join(', ')}';
    }
    return null;
  }

  static String _quoteHttpAuth(String value) =>
      value.replaceAll('\\', '\\\\').replaceAll('"', '\\"');

  static Iterable<XmlElement> _elements(XmlNode node, String localName) =>
      node.descendants.whereType<XmlElement>().where(
            (element) => element.localName == localName,
          );

  static String _xmlEscape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}
