import 'dart:async';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class MjpegService {
  http.StreamedResponse? _response;
  StreamController<Uint8List>? _controller;
  bool _running = false;

  Stream<Uint8List> start(String url) {
    _controller = StreamController<Uint8List>.broadcast();
    _running = true;
    _connect(url);
    return _controller!.stream;
  }

  Future<void> _connect(String url) async {
    try {
      final request = http.Request("GET", Uri.parse(url));
      _response = await request.send();
      final contentType = _response!.headers["content-type"] ?? "";
      final boundary = _extractBoundary(contentType);
      if (boundary == null) return;

      final startMarker = "--$boundary".codeUnits;
      final headerEnd = "\r\n\r\n".codeUnits;
      var buffer = Uint8List(0);

      await for (final chunk in _response!.stream) {
        if (!_running) break;

        final newBuffer = Uint8List(buffer.length + chunk.length);
        newBuffer.setRange(0, buffer.length, buffer);
        newBuffer.setRange(buffer.length, newBuffer.length, chunk);
        buffer = newBuffer;

        while (true) {
          final bStart = _indexOf(buffer, startMarker, 0);
          if (bStart == -1) break;

          final hEnd = _indexOf(buffer, headerEnd, bStart + startMarker.length);
          if (hEnd == -1) break;

          final jpegStart = hEnd + headerEnd.length;

          final bEnd = _indexOf(buffer, startMarker, jpegStart);
          if (bEnd == -1) break;

          final jpegEnd = bEnd - 2;
          if (jpegEnd > jpegStart) {
            _controller?.add(buffer.sublist(jpegStart, jpegEnd));
          }

          buffer = buffer.sublist(bEnd);
        }
      }
    } catch (_) {}
  }

  int _indexOf(Uint8List data, List<int> pattern, int start) {
    if (start + pattern.length > data.length) return -1;
    outer:
    for (int i = start; i <= data.length - pattern.length; i++) {
      for (int j = 0; j < pattern.length; j++) {
        if (data[i + j] != pattern[j]) continue outer;
      }
      return i;
    }
    return -1;
  }

  String? _extractBoundary(String contentType) {
    final parts = contentType.split("boundary=");
    if (parts.length > 1) {
      return parts[1].trim();
    }
    return null;
  }

  void stop() {
    _running = false;
    _response?.stream.listen(null).cancel();
    _controller?.close();
  }
}
