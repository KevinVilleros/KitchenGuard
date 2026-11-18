import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'remote_camera_server.dart';
import 'remote_cloud_service.dart';

class RemoteCloudStreamPublisher {
  Process? _process;
  StreamSubscription<List<int>>? _stderrSubscription;

  bool get isRunning => _process != null;

  Future<void> start({
    required CloudIngress ingress,
    required String ffmpegPath,
    required VoidCallback onFailure,
  }) async {
    if (isRunning) return;
    if (!Platform.isWindows) {
      throw UnsupportedError(
          'La publicación remota solo está disponible en Windows.');
    }
    if (!RemoteCameraServer.instance.isRunning) {
      throw StateError('El servidor local de cámara no está iniciado.');
    }
    final input = Uri(
      scheme: 'http',
      host: '127.0.0.1',
      port: RemoteCameraServer.instance.port,
      path: '/internal/publish-stream',
    );
    final output = Uri.parse(
      '${ingress.url.toString().replaceFirst(RegExp(r'/+$'), '')}/${ingress.streamKey}',
    );
    final process = await Process.start(
      ffmpegPath,
      [
        '-hide_banner',
        '-loglevel',
        'warning',
        '-f',
        'mpjpeg',
        '-reconnect',
        '1',
        '-reconnect_on_network_error',
        '1',
        '-reconnect_on_http_error',
        '4xx,5xx',
        '-reconnect_streamed',
        '1',
        '-reconnect_delay_max',
        '10',
        '-i',
        input.toString(),
        '-an',
        '-c:v',
        'libx264',
        '-preset',
        'ultrafast',
        '-tune',
        'zerolatency',
        '-pix_fmt',
        'yuv420p',
        '-g',
        '15',
        '-b:v',
        '800k',
        '-maxrate',
        '1200k',
        '-bufsize',
        '1600k',
        '-f',
        'flv',
        output.toString(),
      ],
      runInShell: false,
    );
    _process = process;
    _stderrSubscription = process.stderr.listen((_) {});
    unawaited(_watchProcess(process, onFailure));
  }

  Future<void> _watchProcess(Process process, VoidCallback onFailure) async {
    final exitCode = await process.exitCode;
    if (!identical(_process, process)) return;
    _process = null;
    await _stderrSubscription?.cancel();
    _stderrSubscription = null;
    if (exitCode != 0) {
      debugPrint('Cloud video publisher exited with code $exitCode.');
      onFailure();
    }
  }

  Future<void> stop() async {
    final process = _process;
    _process = null;
    await _stderrSubscription?.cancel();
    _stderrSubscription = null;
    if (process == null) return;
    process.kill();
    try {
      await process.exitCode.timeout(const Duration(seconds: 3));
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
      await process.exitCode;
    }
  }
}
