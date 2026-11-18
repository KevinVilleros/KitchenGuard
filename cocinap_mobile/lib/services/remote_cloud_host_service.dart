import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';

import '../providers/standalone_provider.dart';
import 'remote_camera_server.dart';
import 'remote_cloud_monitoring_publisher.dart';
import 'remote_cloud_service.dart';
import 'remote_cloud_stream_publisher.dart';

class RemoteCloudHostService with WidgetsBindingObserver {
  RemoteCloudHostService._();

  static final instance = RemoteCloudHostService._();

  final _service = RemoteCloudService();
  final _streamPublisher = RemoteCloudStreamPublisher();
  final _monitoringPublisher = RemoteCloudMonitoringPublisher();

  bool get isRunning =>
      _streamPublisher.isRunning && _monitoringPublisher.isConnected;

  Future<void> start({
    required RemoteCloudCredentials credentials,
    required StandaloneProvider provider,
    required String localApiKey,
  }) async {
    if (!Platform.isWindows) {
      throw UnsupportedError('CocinaP Cloud solo publica desde Windows.');
    }

    final ffmpegPath = await _resolveFfmpegPath();
    final ingress = await _service.getIngress(credentials);
    final cameraServerWasRunning = RemoteCameraServer.instance.isRunning;
    try {
      await RemoteCameraServer.instance.start(
        apiKey: localApiKey,
        getFrame: () => provider.latestCameraJpeg,
        getFrameTime: () => provider.latestCameraFrameAt,
      );
      await _streamPublisher.start(
        ingress: ingress,
        ffmpegPath: ffmpegPath,
        onFailure: () => debugPrint('Remote cloud video publishing stopped.'),
      );
      await _monitoringPublisher.start(
        credentials: credentials,
        provider: provider,
      );
      WidgetsBinding.instance.addObserver(this);
    } catch (_) {
      await _monitoringPublisher.stop();
      await _streamPublisher.stop();
      if (!cameraServerWasRunning) {
        await RemoteCameraServer.instance.stop();
      }
      rethrow;
    }
  }

  Future<void> stop() async {
    WidgetsBinding.instance.removeObserver(this);
    await _monitoringPublisher.stop();
    await _streamPublisher.stop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      unawaited(stop());
    }
  }

  Future<String> _resolveFfmpegPath() async {
    final appDirectory = File(Platform.resolvedExecutable).parent.path;
    final bundled = File('$appDirectory\\ffmpeg\\ffmpeg.exe');
    if (await bundled.exists()) return bundled.path;

    final besideApp = File('$appDirectory\\ffmpeg.exe');
    if (await besideApp.exists()) return besideApp.path;

    final result = await Process.run(
      'where.exe',
      ['ffmpeg.exe'],
      runInShell: false,
    );
    if (result.exitCode == 0) {
      final path = (result.stdout as String)
          .split(RegExp(r'\r?\n'))
          .map((line) => line.trim())
          .firstWhere(
            (line) => line.isNotEmpty && File(line).existsSync(),
            orElse: () => '',
          );
      if (path.isNotEmpty) return path;
    }
    throw const FileSystemException(
      'FFmpeg no está disponible. Debe incluirse ffmpeg.exe junto al ejecutable de CocinaP.',
    );
  }
}
