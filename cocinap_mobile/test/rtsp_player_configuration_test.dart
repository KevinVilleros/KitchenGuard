import 'package:cocinap_mobile/pages/standalone_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('RTSP playback allows the RTSP protocol', () {
    expect(
      rtspCameraPlayerConfiguration.protocolWhitelist,
      contains('rtsp'),
    );
    expect(rtspCameraPlayerConfiguration.muted, isTrue);
    expect(rtspCameraPlayerConfiguration.bufferSize, 4 * 1024 * 1024);
    expect(rtspLavfOptions, contains('rtsp_transport=tcp'));
    expect(
      rtspDetectionCaptureInterval,
      const Duration(seconds: 1),
    );
  });

  test('camera reconnect delays use capped exponential backoff', () {
    expect(cameraReconnectDelay(0), const Duration(seconds: 2));
    expect(cameraReconnectDelay(1), const Duration(seconds: 5));
    expect(cameraReconnectDelay(2), const Duration(seconds: 10));
    expect(cameraReconnectDelay(3), const Duration(seconds: 20));
    expect(cameraReconnectDelay(4), const Duration(seconds: 30));
    expect(cameraReconnectDelay(20), const Duration(seconds: 30));
  });
}
