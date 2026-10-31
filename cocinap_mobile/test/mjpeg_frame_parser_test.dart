import 'dart:typed_data';

import 'package:cocinap_mobile/services/mjpeg_frame_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MjpegFrameParser', () {
    test('extracts frames split across chunks and ignores multipart headers',
        () {
      final parser = MjpegFrameParser();
      const frame1 = [0xff, 0xd8, 0x11, 0x22, 0xff, 0xd9];
      const frame2 = [0xff, 0xd8, 0x33, 0x44, 0xff, 0xd9];

      expect(
        parser.add([...utf8Bytes('boundary\r\n'), ...frame1.take(3)]),
        isEmpty,
      );
      final frames = parser.add([
        ...frame1.skip(3),
        ...utf8Bytes('\r\n--boundary\r\n'),
        ...frame2,
      ]);

      expect(frames, hasLength(2));
      expect(frames[0], Uint8List.fromList(frame1));
      expect(frames[1], Uint8List.fromList(frame2));
    });

    test('rejects an oversized incomplete frame', () {
      final parser = MjpegFrameParser(maxFrameBytes: 4);

      expect(
        () => parser.add([0xff, 0xd8, 1, 2, 3]),
        throwsFormatException,
      );
    });
  });
}

List<int> utf8Bytes(String value) => value.codeUnits;
