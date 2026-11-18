import 'dart:async' show Timer, unawaited;
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

import '../providers/standalone_provider.dart';
import 'remote_cloud_service.dart';

const remoteMonitoringTopic = 'cocinap-monitoring-v1';
const remoteMonitoringControlTopic = 'cocinap-control-v1';

class RemoteCloudMonitoringPublisher {
  final _service = RemoteCloudService();
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  StandaloneProvider? _provider;
  Timer? _snapshotTimer;
  bool _sending = false;

  bool get isConnected => _room?.connectionState == ConnectionState.connected;

  Future<void> start({
    required RemoteCloudCredentials credentials,
    required StandaloneProvider provider,
  }) async {
    if (_room != null) return;
    final token = await _service.requestHostToken(credentials);
    final room = Room(
      roomOptions: const RoomOptions(
        adaptiveStream: false,
        dynacast: false,
      ),
    );
    _room = room;
    _provider = provider;
    final listener = room.createListener();
    _listener = listener;
    listener.on<DataReceivedEvent>(_onDataReceived);
    provider.addListener(_scheduleSnapshot);
    try {
      await room.connect(token.serverUrl.toString(), token.token);
      _snapshotTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _scheduleSnapshot(),
      );
      await _sendSnapshot();
    } catch (error) {
      await stop();
      rethrow;
    }
  }

  Future<void> stop() async {
    _snapshotTimer?.cancel();
    _snapshotTimer = null;
    final listener = _listener;
    _listener = null;
    await listener?.dispose();
    _provider?.removeListener(_scheduleSnapshot);
    _provider = null;
    final room = _room;
    _room = null;
    await room?.disconnect();
    await room?.dispose();
  }

  void _onDataReceived(DataReceivedEvent event) {
    if (event.topic != remoteMonitoringControlTopic) return;
    try {
      final decoded = jsonDecode(utf8.decode(event.data));
      if (decoded is! Map<String, dynamic> || decoded['version'] != 1) return;
      final action = decoded['action'];
      final provider = _provider;
      if (provider == null) return;

      switch (action) {
        case 'start':
          final minutes = decoded['minutes'];
          if (minutes is int && minutes >= 1 && minutes <= 240) {
            provider.startTimer(minutes: minutes);
          }
          return;
        case 'pause':
          provider.pauseTimer();
          return;
        case 'resume':
          provider.resumeTimer();
          return;
        case 'stop':
          provider.stopTimer();
          return;
      }
    } on FormatException {
      // Ignore malformed, untrusted room data.
    }
  }

  void _scheduleSnapshot() {
    unawaited(_sendSnapshot());
  }

  Future<void> _sendSnapshot() async {
    if (_sending) return;
    final room = _room;
    final provider = _provider;
    final participant = room?.localParticipant;
    if (room == null ||
        provider == null ||
        participant == null ||
        room.connectionState != ConnectionState.connected) {
      return;
    }

    _sending = true;
    try {
      final lastPersonSeen = provider.lastPersonSeen;
      final lastAlertAt = provider.lastAlertAt;
      final latestAlert = provider.latestAlert;
      final payload = jsonEncode({
        'version': 1,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
        'cameraActive': provider.cameraActive,
        'personPresent': provider.personPresent,
        'timerRunning': provider.timerRunning,
        'timerPaused': provider.timerPaused,
        'durationMinutes': provider.durationMinutes,
        'remainingSeconds': provider.remainingSeconds,
        'lastPersonSeenMillis': lastPersonSeen?.millisecondsSinceEpoch,
        'firedIntervals': provider.firedIntervals.toList()..sort(),
        'lastAlertMillis': lastAlertAt?.millisecondsSinceEpoch,
        'lastAlertInterval': latestAlert?.atMinute,
        'lastAlertMessage': latestAlert?.message,
      });
      await participant.publishData(
        utf8.encode(payload),
        reliable: true,
        topic: remoteMonitoringTopic,
      );
    } catch (error) {
      debugPrint('Could not publish remote monitoring state: $error');
    } finally {
      _sending = false;
    }
  }
}
