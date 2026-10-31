import 'dart:typed_data';

class MjpegFrameParser {
  MjpegFrameParser({this.maxFrameBytes = 5 * 1024 * 1024});

  final int maxFrameBytes;
  final List<int> _buffer = [];

  List<Uint8List> add(List<int> chunk) {
    _buffer.addAll(chunk);
    final frames = <Uint8List>[];

    while (true) {
      var start = -1;
      for (var i = 0; i + 1 < _buffer.length; i++) {
        if (_buffer[i] == 0xff && _buffer[i + 1] == 0xd8) {
          start = i;
          break;
        }
      }

      if (start < 0) {
        final keepMarkerPrefix = _buffer.isNotEmpty && _buffer.last == 0xff;
        final last = keepMarkerPrefix ? _buffer.last : 0;
        _buffer.clear();
        if (keepMarkerPrefix) _buffer.add(last);
        break;
      }
      if (start > 0) _buffer.removeRange(0, start);

      var end = -1;
      for (var i = 2; i + 1 < _buffer.length; i++) {
        if (_buffer[i] == 0xff && _buffer[i + 1] == 0xd9) {
          end = i + 1;
          break;
        }
      }

      if (end < 0) {
        if (_buffer.length > maxFrameBytes) {
          _buffer.clear();
          throw const FormatException('MJPEG frame exceeds maximum size');
        }
        break;
      }

      frames.add(Uint8List.fromList(_buffer.sublist(0, end + 1)));
      _buffer.removeRange(0, end + 1);
    }

    return frames;
  }
}
