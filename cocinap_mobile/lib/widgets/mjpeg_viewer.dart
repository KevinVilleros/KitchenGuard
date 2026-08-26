import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/mjpeg_service.dart';

class MjpegViewer extends StatefulWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;

  const MjpegViewer({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  @override
  State<MjpegViewer> createState() => _MjpegViewerState();
}

class _MjpegViewerState extends State<MjpegViewer> {
  final MjpegService _service = MjpegService();
  Uint8List? _lastFrame;

  @override
  void initState() {
    super.initState();
    _startStream();
  }

  void _startStream() {
    _service.start(widget.url).listen((frame) {
      if (mounted) {
        setState(() => _lastFrame = frame);
      }
    });
  }

  @override
  void didUpdateWidget(MjpegViewer old) {
    if (old.url != widget.url) {
      _service.stop();
      _startStream();
    }
    super.didUpdateWidget(old);
  }

  @override
  void dispose() {
    _service.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_lastFrame == null) {
      return Container(
        width: widget.width,
        height: widget.height,
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Image.memory(
      _lastFrame!,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      gaplessPlayback: true,
    );
  }
}
