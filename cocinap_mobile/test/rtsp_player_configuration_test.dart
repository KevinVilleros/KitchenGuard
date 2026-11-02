import 'package:cocinap_mobile/pages/standalone_page.dart';
import 'package:cocinap_mobile/services/person_detector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:image/image.dart' as img;

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

  test('IP camera JPEGs use BGRA bytes for iOS ML Kit input', () {
    final detector = PersonDetector();
    final image = img.Image(width: 1, height: 1)..setPixelRgb(0, 0, 10, 20, 30);

    final input = detector.inputFromRgbImage(
      image,
      platform: TargetPlatform.iOS,
    );

    expect(input.metadata!.format, InputImageFormat.bgra8888);
    expect(input.metadata!.bytesPerRow, 4);
    expect(input.bytes, [30, 20, 10, 255]);
  });

  test('IP camera JPEGs use NV21 bytes for Android ML Kit input', () {
    final detector = PersonDetector();
    final image = img.Image(width: 2, height: 2)
      ..setPixelRgb(0, 0, 10, 20, 30)
      ..setPixelRgb(1, 0, 10, 20, 30)
      ..setPixelRgb(0, 1, 10, 20, 30)
      ..setPixelRgb(1, 1, 10, 20, 30);

    final input = detector.inputFromRgbImage(
      image,
      platform: TargetPlatform.android,
    );

    expect(input.metadata!.format, InputImageFormat.nv21);
    expect(input.bytes, hasLength(6));
  });
}
