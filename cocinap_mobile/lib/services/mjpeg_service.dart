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
      final boundary = _extractBoundary(_response!.headers["content-type"] ?? "");
      if (boundary == null) return;

      final bytesBuilder = BytesBuilder();
      final marker = "--$boundary".codeUnits;
      final headerEnd = "\r\n\r\n".codeUnits;
      int state = 0;
      int headerEndPos = 0;

      await for (final chunk in _response!.stream) {
        if (!_running) break;
        bytesBuilder.add(chunk);
        final data = bytesBuilder.takeBytes();

        int i = 0;
        while (i < data.length) {
          if (state == 0) {
            if (data[i] == marker[0]) {
              state = 1;
              headerEndPos = 1;
              i++;
            } else {
              i++;
            }
          } else if (state == 1) {
            if (headerEndPos < marker.length && data[i] == marker[headerEndPos]) {
              headerEndPos++;
              i++;
            } else {
              state = 0;
            }
            if (headerEndPos == marker.length) {
              state = 2;
              headerEndPos = 0;
            }
          } else if (state == 2) {
            if (headerEndPos < headerEnd.length && data[i] == headerEnd[headerEndPos]) {
              headerEndPos++;
              i++;
            } else {
              headerEndPos = 0;
              i++;
            }
            if (headerEndPos == headerEnd.length) {
              state = 3;
              headerEndPos = 0;
            }
          } else if (state == 3) {
            int start = i;
            int end = i;
            while (end < data.length) {
              if (end + 1 < data.length && data[end] == 0x0D && data[end + 1] == 0x0A) {
                if (end + 2 < data.length && data[end + 2] == 0x2D && data[end + 3] == 0x2D) {
                  break;
                }
              }
              end++;
            }
            if (end > start) {
              final jpeg = Uint8List.sublistView(data, start, end);
              _controller?.add(jpeg);
            }
            state = 0;
            i = end;
          }
        }
      }
    } catch (_) {}
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
