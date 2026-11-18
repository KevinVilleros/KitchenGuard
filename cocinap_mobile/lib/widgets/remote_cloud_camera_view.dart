import 'dart:async' show unawaited;
import 'dart:convert';

import 'package:flutter/material.dart' hide ConnectionState;
import 'package:livekit_client/livekit_client.dart';

import '../services/remote_cloud_service.dart';
import '../services/remote_cloud_monitoring_publisher.dart'
    show remoteMonitoringControlTopic, remoteMonitoringTopic;

class RemoteCloudCameraView extends StatefulWidget {
  final RemoteCloudCredentials credentials;
  final ValueChanged<bool>? onConnectionChanged;
  final ValueChanged<Map<String, dynamic>>? onMonitoringState;
  final bool english;

  const RemoteCloudCameraView({
    required this.credentials,
    this.onConnectionChanged,
    this.onMonitoringState,
    this.english = false,
    super.key,
  });

  @override
  RemoteCloudCameraViewState createState() => RemoteCloudCameraViewState();
}

class RemoteCloudCameraViewState extends State<RemoteCloudCameraView> {
  final _service = RemoteCloudService();
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  VideoTrack? _videoTrack;
  String? _error;
  bool _connecting = true;
  bool _connected = false;

  Future<void> sendControl(String action, {int? minutes}) async {
    final room = _room;
    final participant = room?.localParticipant;
    if (room?.connectionState != ConnectionState.connected ||
        participant == null) {
      throw StateError(widget.english
          ? 'The connection to the PC is not active.'
          : 'La conexión con la PC no está activa.');
    }
    if (!const {'start', 'pause', 'resume', 'stop'}.contains(action)) {
      throw StateError('Unsupported remote control command.');
    }
    if (action == 'start' &&
        (minutes == null || minutes < 1 || minutes > 240)) {
      throw StateError(widget.english
          ? 'Monitoring duration must be between 1 and 240 minutes.'
          : 'La duración debe estar entre 1 y 240 minutos.');
    }

    await participant.publishData(
      utf8.encode(jsonEncode({
        'version': 1,
        'action': action,
        if (action == 'start') 'minutes': minutes,
      })),
      reliable: true,
      topic: remoteMonitoringControlTopic,
    );
  }

  @override
  void initState() {
    super.initState();
    unawaited(_connect());
  }

  @override
  void didUpdateWidget(covariant RemoteCloudCameraView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.credentials.deviceId != widget.credentials.deviceId ||
        oldWidget.credentials.viewerKey != widget.credentials.viewerKey ||
        oldWidget.credentials.gatewayUrl != widget.credentials.gatewayUrl) {
      unawaited(_disconnect().then((_) => _connect()));
    }
  }

  @override
  void dispose() {
    unawaited(_disconnect());
    super.dispose();
  }

  Future<void> _connect() async {
    if (!mounted) return;
    setState(() {
      _connecting = true;
      _connected = false;
      _videoTrack = null;
      _error = null;
    });
    widget.onConnectionChanged?.call(false);

    final room = Room(
      roomOptions: const RoomOptions(
        adaptiveStream: true,
        dynacast: true,
      ),
    );
    final listener = room.createListener();
    listener
      ..on<RoomConnectedEvent>((_) {
        if (!mounted) return;
        setState(() {
          _connecting = false;
          _connected = true;
        });
        widget.onConnectionChanged?.call(true);
      })
      ..on<RoomDisconnectedEvent>((_) {
        if (!mounted) return;
        setState(() {
          _connected = false;
          _connecting = false;
          _videoTrack = null;
        });
        widget.onConnectionChanged?.call(false);
      })
      ..on<TrackSubscribedEvent>((event) {
        if (event.track is VideoTrack && mounted) {
          setState(() => _videoTrack = event.track as VideoTrack);
        }
      })
      ..on<TrackUnsubscribedEvent>((event) {
        if (identical(_videoTrack, event.track) && mounted) {
          setState(() => _videoTrack = null);
        }
      })
      ..on<DataReceivedEvent>((event) {
        if (event.topic != remoteMonitoringTopic) return;
        try {
          final decoded = jsonDecode(utf8.decode(event.data));
          if (decoded is Map<String, dynamic> &&
              decoded['version'] == 1 &&
              mounted) {
            widget.onMonitoringState?.call(decoded);
          }
        } on FormatException {
          // Ignore malformed, untrusted room data.
        }
      });

    _room = room;
    _listener = listener;
    try {
      final token = await _service.requestViewerToken(widget.credentials);
      await room.connect(token.serverUrl.toString(), token.token);
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _connected = true;
      });
      widget.onConnectionChanged?.call(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _connected = false;
        _error = error.toString();
      });
      widget.onConnectionChanged?.call(false);
      await _disconnect();
    }
  }

  Future<void> _disconnect() async {
    final listener = _listener;
    _listener = null;
    final room = _room;
    _room = null;
    _videoTrack = null;
    await listener?.dispose();
    await room?.disconnect();
    await room?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final track = _videoTrack;
    if (track != null) {
      return VideoTrackRenderer(track, fit: VideoViewFit.contain);
    }
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: _connecting
            ? const CircularProgressIndicator()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _connected ? Icons.videocam_off : Icons.cloud_off,
                    color: Colors.white70,
                    size: 36,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _error ??
                        (_connected
                            ? (widget.english
                                ? 'Waiting for video from the PC…'
                                : 'Esperando video de la PC…')
                            : (widget.english
                                ? 'Could not connect to CocinaP Cloud.'
                                : 'No se pudo conectar con CocinaP Cloud.')),
                    style: const TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                  if (!_connected) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _connect,
                      icon: const Icon(Icons.refresh),
                      label: Text(widget.english ? 'Retry' : 'Reintentar'),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
