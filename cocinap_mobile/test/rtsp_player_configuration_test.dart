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
    expect(
      rtspDetectionCaptureInterval,
      const Duration(seconds: 1),
    );
  });
}
