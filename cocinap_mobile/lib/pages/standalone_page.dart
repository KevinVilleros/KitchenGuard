import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../providers/standalone_provider.dart';
import '../services/person_detector.dart';
import '../services/background_service.dart';
import '../services/mjpeg_frame_parser.dart';
import '../services/settings_service.dart';
import '../widgets/camera_url_dialog.dart';
import '../content/content.dart';

@visibleForTesting
const rtspDetectionCaptureInterval = Duration(seconds: 1);

@visibleForTesting
Duration cameraReconnectDelay(int attempt) {
  const delays = [
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 10),
    Duration(seconds: 20),
    Duration(seconds: 30),
  ];
  return delays[attempt.clamp(0, delays.length - 1).toInt()];
}

@visibleForTesting
const rtspLavfOptions =
    'protocol_whitelist=[rtsp,udp,rtp,tcp,tls,data,file,http,https,crypto],rtsp_transport=tcp';

@visibleForTesting
const rtspCameraPlayerConfiguration = PlayerConfiguration(
  muted: true,
  bufferSize: 4 * 1024 * 1024,
  protocolWhitelist: [
    'rtsp',
    'udp',
    'rtp',
    'tcp',
    'tls',
    'data',
    'file',
    'http',
    'https',
    'crypto',
  ],
);

/// Página del modo independiente: monitorea la cocina en el móvil (con la
/// cámara del dispositivo o una cámara IP) usando un temporizador configurable.
/// Si no se detecta una persona durante el plazo, emite alertas.
class StandalonePage extends StatefulWidget {
  const StandalonePage({super.key});

  @override
  State<StandalonePage> createState() => _StandalonePageState();
}

class _StandalonePageState extends State<StandalonePage>
    with WidgetsBindingObserver {
  String get lang => AppLocal.language;
  CameraController? _camera;
  CameraDescription? _cameraDescription;
  final PersonDetector _detector = PersonDetector();
  Timer? _alertTimer;
  StreamSubscription<List<int>>? _ipStreamSub;
  StreamSubscription<String>? _rtspErrorSub;
  StreamSubscription<VideoParams>? _rtspVideoParamsSub;
  StreamSubscription<Duration>? _rtspPositionSub;
  StreamSubscription<bool>? _rtspBufferingSub;
  HttpClient? _ipHttpClient;
  Player? _rtspPlayer;
  VideoController? _rtspController;
  Timer? _rtspFrameTimer;
  Timer? _cameraHealthTimer;
  Timer? _cameraRetryTimer;
  Timer? _rtspConnectTimeout;
  bool _rtspScreenshotInFlight = false;
  bool _rtspVideoReady = false;
  bool _rtspPositionAdvanced = false;
  bool _cameraRestarting = false;
  int _cameraGeneration = 0;
  int _cameraRetryAttempt = 0;
  Duration? _rtspLastPosition;
  DateTime? _rtspLastProgressAt;
  DateTime? _rtspBufferingStartedAt;
  DateTime? _ipStreamStartedAt;
  DateTime? _ipLastFrameAt;
  String? _cameraRetryMessage;
  bool _wasBackgrounded = false;
  bool _lastTimerRunning = false;
  bool _lastTimerPaused = false;
  bool _cameraError = false;
  String? _cameraErrorMessage;
  bool _detectorLoading = false;
  Uint8List? _lastIpFrame;
  StandaloneCameraSource _lastSource = StandaloneCameraSource.phone;
  String _lastUrl = "";

  // Último resultado de detección para el overlay gráfico de depuración.
  DetectionResult _lastResult = DetectionResult.empty;
  int _framesProcessed = 0;
  int _streamCounter = 0;

  // --- Control de rendimiento de la detección ---
  // Evita solapar inferencias: solo se procesa un frame cuando el anterior
  // terminó, y como máximo cada `_minDetectInterval`.
  bool _detecting = false;
  DateTime? _lastDetectAt;
  static const Duration _minDetectInterval = Duration(milliseconds: 400);

  // Rotación del sensor de cámara, usada para orientar el frame ante ML Kit.
  int _rotationDegrees = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDetector();
    _initVideo();
    _startAlertLoop();
    final standalone = context.read<StandaloneProvider>();
    _lastSource = standalone.cameraSource;
    _lastUrl = standalone.cameraUrl;
    _lastTimerRunning = standalone.timerRunning;
    _lastTimerPaused = standalone.timerPaused;
    standalone.restoreSession();
    context.read<StandaloneProvider>().addListener(_onProviderChanged);
    _syncMonitoring(standalone);
  }

  void _onProviderChanged() {
    final standalone = context.read<StandaloneProvider>();
    if (standalone.cameraSource != _lastSource ||
        standalone.cameraUrl != _lastUrl) {
      _lastSource = standalone.cameraSource;
      _lastUrl = standalone.cameraUrl;
      _initVideo();
    }
    if (standalone.timerRunning != _lastTimerRunning ||
        standalone.timerPaused != _lastTimerPaused) {
      _lastTimerRunning = standalone.timerRunning;
      _lastTimerPaused = standalone.timerPaused;
      _syncMonitoring(standalone);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_setScreenAwake(
        context.read<StandaloneProvider>().timerRunning &&
            !context.read<StandaloneProvider>().timerPaused,
      ));
      if (_wasBackgrounded) {
        _wasBackgrounded = false;
        if (context.read<StandaloneProvider>().cameraSource ==
            StandaloneCameraSource.ipCamera) {
          _initVideo();
        }
      }
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _wasBackgrounded = true;
      unawaited(_setScreenAwake(false));
    }
  }

  void _syncMonitoring(StandaloneProvider standalone) {
    final active = standalone.timerRunning && !standalone.timerPaused;
    unawaited(_setScreenAwake(
      active &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
    ));
    if (defaultTargetPlatform == TargetPlatform.android) {
      if (active) {
        unawaited(_startBackgroundMonitoring(standalone.remainingSeconds));
      } else {
        unawaited(_stopBackgroundMonitoring());
      }
    }
  }

  Future<void> _setScreenAwake(bool enabled) async {
    try {
      await WakelockPlus.toggle(enable: enabled);
    } catch (error) {
      debugPrint('Could not update screen wake lock: ${error.runtimeType}');
    }
  }

  Future<void> _startBackgroundMonitoring(int remainingSeconds) async {
    try {
      await BackgroundServiceManager.startMonitoring(remainingSeconds);
    } catch (error) {
      debugPrint(
          'Could not start Android monitoring service: ${error.runtimeType}');
    }
  }

  Future<void> _stopBackgroundMonitoring() async {
    try {
      await BackgroundServiceManager.stopMonitoring();
    } catch (error) {
      debugPrint(
          'Could not stop Android monitoring service: ${error.runtimeType}');
    }
  }

  Future<void> _loadDetector() async {
    setState(() => _detectorLoading = true);
    try {
      await _detector.load('');
    } catch (e) {
      debugPrint('PersonDetector load error: $e');
    }
    if (mounted) setState(() => _detectorLoading = false);
  }

  Future<void> _initVideo({bool resetRetry = true}) async {
    if (!mounted) return;
    final standalone = context.read<StandaloneProvider>();
    final source = standalone.cameraSource;
    _cameraErrorMessage = null;
    _cameraRetryMessage = null;
    _cameraRetryTimer?.cancel();
    _cameraRetryTimer = null;
    if (resetRetry) _cameraRetryAttempt = 0;
    _lastSource = source;
    _lastUrl = standalone.cameraUrl;

    _stopVideo();
    final generation = _cameraGeneration;
    standalone.setCameraActive(false);

    if (source == StandaloneCameraSource.ipCamera) {
      final url = standalone.cameraUrl;
      if (url.isEmpty) {
        setState(() {
          _cameraError = true;
          _cameraErrorMessage = null;
        });
        return;
      }
      setState(() {
        _cameraError = false;
        _cameraErrorMessage = null;
      });
      if (url.toLowerCase().startsWith('rtsp://')) {
        await _startRtspStream(url);
      } else {
        unawaited(_startIpStream(url));
      }
      return;
    }

    // Fuente: cámara del móvil.
    try {
      final cameras = await availableCameras();
      if (!mounted || cameras.isEmpty) {
        setState(() {
          _cameraError = true;
          _cameraErrorMessage = null;
        });
        return;
      }
      late CameraDescription back;
      try {
        back = cameras
            .firstWhere((c) => c.lensDirection == CameraLensDirection.back);
      } catch (_) {
        back = cameras.first;
      }
      final controller = await _createController(back);
      if (!mounted || generation != _cameraGeneration || controller == null) {
        await controller?.dispose();
        if (mounted) {
          setState(() {
            _cameraError = true;
            _cameraErrorMessage = null;
          });
        }
        return;
      }
      _cameraDescription = back;
      _updateRotation(back, controller);
      setState(() {
        _cameraError = false;
        _cameraErrorMessage = null;
        _camera = controller;
      });
      standalone.setCameraActive(true);
      _startPhoneStream();
    } catch (e) {
      debugPrint('Camera init error: $e');
      if (mounted) {
        setState(() {
          _cameraError = true;
          _cameraErrorMessage = null;
        });
      }
    }
  }

  /// Crea el [CameraController] probando varias combinaciones hasta encontrar
  /// una que el dispositivo soporte. La cámara del móvil es el punto más
  /// frágil: distintas resoluciones y formatos pueden fallar con
  /// "No supported surface combination".
  Future<CameraController?> _createController(CameraDescription camera) async {
    final attempts = <(ResolutionPreset, ImageFormatGroup?)>[
      if (defaultTargetPlatform == TargetPlatform.iOS) ...[
        (ResolutionPreset.low, ImageFormatGroup.bgra8888),
        (ResolutionPreset.medium, ImageFormatGroup.bgra8888),
        (ResolutionPreset.low, null),
      ] else ...[
        (ResolutionPreset.low, ImageFormatGroup.yuv420),
        (ResolutionPreset.low, null),
        (ResolutionPreset.medium, ImageFormatGroup.yuv420),
        (ResolutionPreset.medium, null),
        (ResolutionPreset.high, null),
      ],
    ];
    for (final (preset, fmt) in attempts) {
      try {
        final controller = CameraController(
          camera,
          preset,
          enableAudio: false,
          imageFormatGroup: fmt ?? ImageFormatGroup.yuv420,
        );
        await controller.initialize();
        debugPrint('Camera OK preset=$preset format=$fmt');
        return controller;
      } catch (e) {
        debugPrint('Camera try failed preset=$preset format=$fmt: $e');
      }
    }
    return null;
  }

  /// Calcula la rotación a aplicar al frame según el sensor de la cámara y la
  /// orientación actual del dispositivo.
  void _updateRotation(CameraDescription camera, CameraController controller) {
    final sensor = camera.sensorOrientation;
    final device = controller.value.deviceOrientation;
    int rotation;
    if (camera.lensDirection == CameraLensDirection.front) {
      rotation = (sensor + _deviceRotation(device)) % 360;
    } else {
      rotation = (sensor - _deviceRotation(device) + 360) % 360;
    }
    _rotationDegrees = rotation;
    debugPrint('Camera rotation=$rotation sensor=$sensor device=$device');
  }

  int _deviceRotation(DeviceOrientation orientation) {
    switch (orientation) {
      case DeviceOrientation.portraitUp:
        return 0;
      case DeviceOrientation.landscapeLeft:
        return 90;
      case DeviceOrientation.portraitDown:
        return 180;
      case DeviceOrientation.landscapeRight:
        return 270;
    }
  }

  /// Consume un stream MJPEG de una cámara IP y lo envía al detector.
  Future<void> _startIpStream(String url) async {
    final generation = _cameraGeneration;
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8)
      ..idleTimeout = const Duration(seconds: 15);
    _ipHttpClient = client;
    _ipStreamStartedAt = DateTime.now();
    _ipLastFrameAt = null;
    _cameraHealthTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _checkIpStreamHealth(generation),
    );
    _lastIpFrame = null;
    final parser = MjpegFrameParser();

    try {
      final uri = Uri.parse(url);
      if (!{'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
          uri.host.isEmpty) {
        throw const FormatException('Invalid camera stream URL');
      }
      final requestUri = Uri(
        scheme: uri.scheme,
        host: uri.host,
        port: uri.hasPort ? uri.port : null,
        path: uri.path.isEmpty ? '/' : uri.path,
        query: uri.hasQuery ? uri.query : null,
      );
      final request = await client.getUrl(requestUri);
      request.headers.set(
        HttpHeaders.acceptHeader,
        'multipart/x-mixed-replace, image/jpeg',
      );
      if (uri.userInfo.isNotEmpty) {
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Basic ${base64Encode(utf8.encode(Uri.decodeComponent(uri.userInfo)))}',
        );
      }
      final response = await request.close().timeout(
            const Duration(seconds: 10),
          );
      if (generation != _cameraGeneration) return;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Camera returned HTTP ${response.statusCode}',
          uri: requestUri,
        );
      }

      _ipStreamSub = response.listen(
        (chunk) {
          if (generation != _cameraGeneration) return;
          try {
            for (final frame in parser.add(chunk)) {
              if (!mounted || generation != _cameraGeneration) return;
              _ipLastFrameAt = DateTime.now();
              setState(() {
                _lastIpFrame = frame;
                _cameraError = false;
                _cameraErrorMessage = null;
              });
              _markCameraHealthy();
              final standalone = context.read<StandaloneProvider>();
              _runDetection(
                () => _detector.detectFromJpeg(
                  frame,
                  confidence: standalone.confidence,
                ),
              );
            }
          } catch (error) {
            _handleIpStreamFailure(generation, error);
          }
        },
        onError: (Object error) => _handleIpStreamFailure(generation, error),
        onDone: () => _handleIpStreamFailure(
          generation,
          const HttpException('Camera stream ended'),
        ),
        cancelOnError: true,
      );
    } catch (error) {
      _handleIpStreamFailure(generation, error);
    }
  }

  Future<void> _startRtspStream(String url) async {
    final generation = _cameraGeneration;
    final player = Player(configuration: rtspCameraPlayerConfiguration);
    final controller = VideoController(player);
    _rtspPlayer = player;
    _rtspController = controller;
    _rtspVideoReady = false;
    _rtspErrorSub = player.stream.error.listen((_) {
      _handleRtspFailure(generation);
    });
    _rtspPositionSub = player.stream.position.listen((position) {
      final previous = _rtspLastPosition;
      if (previous != null && position > previous) {
        _rtspPositionAdvanced = true;
        _rtspLastProgressAt = DateTime.now();
      }
      _rtspLastPosition = position;
    });
    _rtspBufferingSub = player.stream.buffering.listen((buffering) {
      if (buffering) {
        _rtspBufferingStartedAt ??= DateTime.now();
      } else {
        _rtspBufferingStartedAt = null;
      }
    });
    _rtspVideoParamsSub = player.stream.videoParams.listen((params) {
      if (generation == _cameraGeneration &&
          (params.w ?? 0) > 0 &&
          (params.h ?? 0) > 0) {
        _rtspVideoReady = true;
      }
    });
    _rtspConnectTimeout = Timer(const Duration(seconds: 15), () {
      if (generation == _cameraGeneration &&
          !context.read<StandaloneProvider>().cameraActive) {
        _handleRtspFailure(generation);
      }
    });
    _rtspFrameTimer = Timer.periodic(
      rtspDetectionCaptureInterval,
      (_) => _captureRtspFrame(player, generation),
    );
    _cameraHealthTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _checkRtspHealth(generation),
    );
    if (mounted) setState(() {});

    try {
      final platform = player.platform;
      if (platform is NativePlayer) {
        await platform.setProperty('demuxer-lavf-o', rtspLavfOptions);
        await platform.setProperty('aid', 'no');
      }
      await player.open(Media(url));
    } on Exception catch (error) {
      debugPrint('RTSP startup failed: ${error.runtimeType}');
      _handleRtspFailure(generation);
    }
  }

  Future<void> _captureRtspFrame(Player player, int generation) async {
    if (_rtspScreenshotInFlight ||
        generation != _cameraGeneration ||
        !_rtspVideoReady ||
        !mounted) {
      return;
    }
    _rtspScreenshotInFlight = true;
    try {
      final frame = await player.screenshot(format: 'image/jpeg');
      if (frame == null || generation != _cameraGeneration || !mounted) {
        return;
      }
      final standalone = context.read<StandaloneProvider>();
      if (!standalone.cameraActive) {
        _markCameraHealthy();
        _rtspConnectTimeout?.cancel();
      }
      _runDetection(
        () => _detector.detectFromJpeg(
          frame,
          confidence: standalone.confidence,
        ),
      );
    } on Exception {
      if (generation == _cameraGeneration && mounted) {
        _handleRtspFailure(generation);
      }
    } finally {
      _rtspScreenshotInFlight = false;
    }
  }

  void _markCameraHealthy() {
    _cameraRetryAttempt = 0;
    _cameraRetryMessage = null;
    _cameraRetryTimer?.cancel();
    _cameraRetryTimer = null;
    context.read<StandaloneProvider>().setCameraActive(true);
  }

  void _checkIpStreamHealth(int generation) {
    if (generation != _cameraGeneration || !mounted) return;
    final lastFrameAt = _ipLastFrameAt ?? _ipStreamStartedAt;
    if (lastFrameAt != null &&
        DateTime.now().difference(lastFrameAt) > const Duration(seconds: 20)) {
      _handleIpStreamFailure(
        generation,
        const HttpException('Camera stream stopped sending frames'),
      );
    }
  }

  void _checkRtspHealth(int generation) {
    if (generation != _cameraGeneration ||
        !mounted ||
        !context.read<StandaloneProvider>().cameraActive) {
      return;
    }
    final now = DateTime.now();
    final bufferingSince = _rtspBufferingStartedAt;
    if (bufferingSince != null &&
        now.difference(bufferingSince) > const Duration(seconds: 20)) {
      _handleRtspFailure(generation);
      return;
    }
    final lastProgressAt = _rtspLastProgressAt;
    if (_rtspPositionAdvanced &&
        lastProgressAt != null &&
        now.difference(lastProgressAt) > const Duration(seconds: 25)) {
      _handleRtspFailure(generation);
    }
  }

  void _handleRtspFailure(int generation) {
    if (generation != _cameraGeneration || !mounted) return;
    _cameraHealthTimer?.cancel();
    _cameraHealthTimer = null;
    _rtspFrameTimer?.cancel();
    _rtspFrameTimer = null;
    _rtspConnectTimeout?.cancel();
    _rtspConnectTimeout = null;
    _rtspErrorSub?.cancel();
    _rtspErrorSub = null;
    _rtspVideoParamsSub?.cancel();
    _rtspVideoParamsSub = null;
    _rtspPositionSub?.cancel();
    _rtspPositionSub = null;
    _rtspBufferingSub?.cancel();
    _rtspBufferingSub = null;
    final player = _rtspPlayer;
    _rtspPlayer = null;
    _rtspController = null;
    if (player != null) unawaited(player.dispose());
    context.read<StandaloneProvider>().setCameraActive(false);
    setState(() {
      _cameraError = true;
      _cameraErrorMessage = lang == 'en'
          ? 'Could not open the RTSP stream. Check the full stream path and the camera’s RTSP username and password. ONVIF and RTSP may use different credentials.'
          : 'No se pudo abrir el stream RTSP. Verifica la ruta completa y el usuario y contraseña RTSP de la cámara. ONVIF y RTSP pueden usar credenciales diferentes.';
    });
    _scheduleCameraReconnect(generation);
  }

  void _handleIpStreamFailure(int generation, Object error) {
    if (generation != _cameraGeneration || !mounted) return;
    debugPrint('IP camera stream error: $error');
    _cameraHealthTimer?.cancel();
    _cameraHealthTimer = null;
    unawaited(_ipStreamSub?.cancel());
    _ipHttpClient?.close(force: true);
    _ipHttpClient = null;
    _ipStreamSub = null;
    _ipStreamStartedAt = null;
    _ipLastFrameAt = null;
    context.read<StandaloneProvider>().setCameraActive(false);
    setState(() {
      _cameraError = true;
      _cameraErrorMessage = lang == 'en'
          ? 'Could not read the camera stream. Check its URL and that the phone and camera are on the same network.'
          : 'No se pudo leer el stream de la cámara. Verifica la URL y que el teléfono y la cámara estén en la misma red.';
    });
    _scheduleCameraReconnect(generation);
  }

  void _scheduleCameraReconnect(int generation) {
    if (generation != _cameraGeneration ||
        !mounted ||
        context.read<StandaloneProvider>().cameraSource !=
            StandaloneCameraSource.ipCamera ||
        _cameraRetryTimer != null) {
      return;
    }
    final delay = cameraReconnectDelay(_cameraRetryAttempt);
    _cameraRetryAttempt++;
    setState(() {
      _cameraRetryMessage = lang == 'en'
          ? 'Retrying automatically in ${delay.inSeconds} seconds. Tap the refresh button to retry now.'
          : 'Reintentando automáticamente en ${delay.inSeconds} s. Toca actualizar para reintentar ahora.';
    });
    _cameraRetryTimer = Timer(delay, () {
      _cameraRetryTimer = null;
      if (!mounted ||
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        return;
      }
      unawaited(_initVideo(resetRetry: false));
    });
  }

  Future<void> _reconnectCamera() async {
    if (_cameraRestarting || !mounted) return;
    setState(() {
      _cameraRestarting = true;
      _cameraError = false;
      _cameraErrorMessage = null;
      _cameraRetryMessage = null;
    });
    _cameraRetryTimer?.cancel();
    _cameraRetryTimer = null;
    _cameraRetryAttempt = 0;
    try {
      await _initVideo();
    } finally {
      if (mounted) setState(() => _cameraRestarting = false);
    }
  }

  /// Stream de frames de la cámara del móvil → detección de personas.
  ///
  /// Se pide formato JPEG (Android suele respetarlo), pero si el dispositivo
  /// entrega YUV420 se convierte a RGB. Así la detección funciona en ambos
  /// casos.
  void _startPhoneStream() {
    _camera!.startImageStream((cameraImage) {
      if (_detectorLoading || !_detector.loaded) return;
      final standalone = context.read<StandaloneProvider>();
      if (_cameraDescription != null) {
        _updateRotation(_cameraDescription!, _camera!);
      }

      _streamCounter++;
      if (_streamCounter % 20 == 1) {
        debugPrint('PhoneStream group=${cameraImage.format.group} '
            'w=${cameraImage.width} h=${cameraImage.height} '
            'planes=${cameraImage.planes.length}');
      }

      // ML Kit recibe el frame crudo de la cámara (YUV420/NV21) y detecta
      // personas reales por etiqueta, sin conversiones manuales.
      _runDetection(() => _detector.detectFromCameraImage(
            cameraImage,
            rotationDegrees: _rotationDegrees,
            confidence: standalone.confidence,
          ));
    }).catchError((Object e) {
      debugPrint('PhoneStream error: $e');
      if (mounted) {
        setState(() {
          _cameraError = true;
          _cameraErrorMessage = null;
        });
      }
    });
  }

  /// Ejecuta una detección respetando el throttle y evitando solapamientos.
  Future<void> _runDetection(
    Future<DetectionResult> Function() task,
  ) async {
    if (_detecting || _detectorLoading || !_detector.loaded) return;
    final now = DateTime.now();
    final last = _lastDetectAt;
    if (last != null && now.difference(last) < _minDetectInterval) return;

    _detecting = true;
    _lastDetectAt = now;
    try {
      final result = await task();
      if (!mounted) return;
      setState(() {
        _lastResult = result;
        _framesProcessed++;
      });
      context
          .read<StandaloneProvider>()
          .onPersonDetected(result.count, score: result.maxScore);
    } catch (e) {
      debugPrint('Person detection frame error: $e');
    } finally {
      _detecting = false;
    }
  }

  void _stopVideo() {
    _cameraGeneration++;
    _cameraHealthTimer?.cancel();
    _cameraHealthTimer = null;
    _rtspFrameTimer?.cancel();
    _rtspFrameTimer = null;
    _rtspConnectTimeout?.cancel();
    _rtspConnectTimeout = null;
    _rtspErrorSub?.cancel();
    _rtspErrorSub = null;
    _rtspVideoParamsSub?.cancel();
    _rtspVideoParamsSub = null;
    _rtspPositionSub?.cancel();
    _rtspPositionSub = null;
    _rtspBufferingSub?.cancel();
    _rtspBufferingSub = null;
    final rtspPlayer = _rtspPlayer;
    _rtspPlayer = null;
    _rtspController = null;
    if (rtspPlayer != null) unawaited(rtspPlayer.dispose());
    _rtspScreenshotInFlight = false;
    _rtspVideoReady = false;
    _rtspPositionAdvanced = false;
    _rtspLastPosition = null;
    _rtspLastProgressAt = null;
    _rtspBufferingStartedAt = null;
    _ipStreamSub?.cancel();
    _ipStreamSub = null;
    _ipHttpClient?.close(force: true);
    _ipHttpClient = null;
    _ipStreamStartedAt = null;
    _ipLastFrameAt = null;
    _camera?.dispose();
    _camera = null;
    _cameraDescription = null;
    _lastIpFrame = null;
    _detecting = false;
    _lastDetectAt = null;
    _framesProcessed = 0;
  }

  /// Loop que evalúa cada segundo si corresponde emitir una alerta por
  /// intervalo (10, 15, 20... min sin persona) y lanza la notificación.
  void _startAlertLoop() {
    _alertTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final standalone = context.read<StandaloneProvider>();
      final interval = standalone.nextDueInterval();
      if (interval == null) return;

      final lang = AppLocal.language;
      final n = standalone.firedIntervalCount + 1;
      final message = lang == "en"
          ? "Kitchen unattended ($interval min without person). Alert #$n."
          : "Cocina desatendida ($interval min sin persona). Alerta #$n.";
      standalone.markIntervalFired(interval, message);
      BackgroundServiceManager.showAlarm(message);
      BackgroundServiceManager.updateStatus(lang == "en"
          ? "No person: $interval min"
          : "Sin persona: $interval min");
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _alertTimer?.cancel();
    _cameraRetryTimer?.cancel();
    _stopVideo();
    _detector.dispose();
    context.read<StandaloneProvider>().removeListener(_onProviderChanged);
    context.read<StandaloneProvider>().setCameraActive(false);
    unawaited(_setScreenAwake(false));
    super.dispose();
  }

  Future<void> _startTimer(BuildContext context) async {
    final standalone = context.read<StandaloneProvider>();
    final minutesCtrl =
        TextEditingController(text: "${standalone.durationMinutes}");
    final minutes = await showDialog<int>(
      context: context,
      builder: (ctx) {
        final lang = AppLocal.language;
        String l(String es, String en) => lang == "en" ? en : es;
        return AlertDialog(
          title: Text(l("Iniciar monitoreo", "Start monitoring")),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: minutesCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l("Minutos de monitoreo (1-240)",
                      "Monitoring minutes (1-240)"),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l("Se vigila la cocina. Si NO se detecta una persona, se enviará una alerta.",
                    "The kitchen is monitored. If NO person is detected, an alert will be sent."),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l("Cancelar", "Cancel"))),
            ElevatedButton(
              onPressed: () {
                final v = int.tryParse(minutesCtrl.text) ?? 30;
                Navigator.pop(ctx, v);
              },
              child: Text(l("Iniciar", "Start")),
            ),
          ],
        );
      },
    );
    if (minutes != null && minutes > 0) {
      standalone.startTimer(minutes: minutes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final standalone = context.watch<StandaloneProvider>();

    final color = standalone.personPresent
        ? Colors.green
        : (standalone.timerRunning ? Colors.orange : Colors.grey);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocal.language == "en"
            ? "Standalone mode"
            : "Modo independiente"),
        actions: [
          if (standalone.cameraSource == StandaloneCameraSource.ipCamera)
            IconButton(
              tooltip: lang == 'en' ? 'Reconnect camera' : 'Reconectar cámara',
              onPressed: _cameraRestarting ? null : _reconnectCamera,
              icon: _cameraRestarting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
            ),
          IconButton(
            tooltip: AppLocal.language == "en"
                ? "Change device or camera"
                : "Cambiar dispositivo o cámara",
            icon: const Icon(Icons.devices),
            onPressed: () => _showDevicesSheet(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner de estado
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: standalone.timerRunning
                ? (standalone.personPresent
                    ? Colors.green.shade900
                    : Colors.red.shade900)
                : Colors.grey.shade900,
            child: Row(
              children: [
                Icon(
                  standalone.personPresent ? Icons.person : Icons.person_off,
                  color: standalone.personPresent
                      ? Colors.greenAccent
                      : Colors.redAccent,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    standalone.statusText,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

          // Vista de cámara (móvil o cámara IP)
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                _cameraError
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                [
                                  _cameraErrorMessage ??
                                      (lang == "en"
                                          ? "Could not access the camera.\nCheck the connection and permissions."
                                          : "No se pudo acceder a la cámara.\nRevisa la conexión y los permisos."),
                                  if (_cameraRetryMessage != null)
                                    _cameraRetryMessage!,
                                ].join('\n\n'),
                                style: const TextStyle(color: Colors.white),
                                textAlign: TextAlign.center,
                              ),
                              if (standalone.cameraSource ==
                                  StandaloneCameraSource.ipCamera) ...[
                                const SizedBox(height: 16),
                                FilledButton.icon(
                                  onPressed: _cameraRestarting
                                      ? null
                                      : _reconnectCamera,
                                  icon: const Icon(Icons.refresh),
                                  label: Text(lang == 'en'
                                      ? 'Reconnect camera now'
                                      : 'Reconectar cámara ahora'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                    : standalone.cameraSource == StandaloneCameraSource.ipCamera
                        ? (standalone.cameraUrl
                                .toLowerCase()
                                .startsWith('rtsp://')
                            ? (_rtspController == null
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : Video(controller: _rtspController!))
                            : (_lastIpFrame == null
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : Image.memory(
                                    _lastIpFrame!,
                                    width: double.infinity,
                                    height: double.infinity,
                                    fit: BoxFit.contain,
                                    gaplessPlayback: true,
                                  )))
                        : (_camera == null
                            ? const Center(child: CircularProgressIndicator())
                            : CameraPreview(_camera!)),
                if (!_cameraError)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: _LiveBadge(
                      active: standalone.cameraActive,
                      personPresent: standalone.personPresent,
                    ),
                  ),
                // Overlay gráfico de detección (cajas + conteo) para verificar
                // que el modelo está reconociendo objetos en vivo.
                if (!_cameraError && _detector.loaded)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _DetectionOverlayPainter(
                          result: _lastResult,
                          frameWidth: standalone.cameraSource ==
                                  StandaloneCameraSource.phone
                              ? (_camera?.value.previewSize?.height ?? 0)
                              : 0,
                          frameHeight: standalone.cameraSource ==
                                  StandaloneCameraSource.phone
                              ? (_camera?.value.previewSize?.width ?? 0)
                              : 0,
                        ),
                      ),
                    ),
                  ),
                // Panel de diagnóstico de detección.
                Positioned(
                  top: 10,
                  right: 10,
                  child: _DetectionDebugPanel(
                    loading: _detectorLoading,
                    loaded: _detector.loaded,
                    people: _lastResult.count,
                    maxScore: _lastResult.maxScore,
                    total: _lastResult.boxes.length,
                    frames: _framesProcessed,
                    info: _detector.loaded ? _detector.debugInfo : "",
                  ),
                ),
              ],
            ),
          ),

          // Estadísticas
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatTile(
                    icon: Icons.timer,
                    label: standalone.timerRunning
                        ? (lang == "en" ? "Time remaining" : "Tiempo restante")
                        : (lang == "en" ? "Timer" : "Temporizador"),
                    value: standalone.timerRunning
                        ? standalone.remainingLabel
                        : "${standalone.durationMinutes} min",
                    color: Colors.orange,
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: Colors.white12,
                  ),
                  _StatTile(
                    icon: Icons.person,
                    label: lang == "en"
                        ? "Person in kitchen"
                        : "Persona en cocina",
                    value: standalone.personPresent
                        ? (lang == "en" ? "YES" : "SÍ")
                        : (lang == "en" ? "NO" : "NO"),
                    color: color,
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: Colors.white12,
                  ),
                  _StatTile(
                    icon: Icons.notification_important,
                    label: lang == "en" ? "No person" : "Sin persona",
                    value: standalone.timerRunning && !standalone.personPresent
                        ? "${standalone.absenceMinutes.toStringAsFixed(1)} min"
                        : "--",
                    color: standalone.timerRunning && !standalone.personPresent
                        ? Colors.redAccent
                        : Colors.grey,
                  ),
                ],
              ),
            ),
          ),

          // Próxima alerta por intervalos
          if (standalone.intervalAlertsEnabled &&
              standalone.sortedIntervals.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                _nextAlertLabel(standalone),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                textAlign: TextAlign.center,
              ),
            ),

          // Historial de alertas por intervalos
          if (standalone.alerts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade900),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.warning_amber,
                            color: Colors.redAccent, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          lang == "en" ? "Recent alerts" : "Alertas recientes",
                          style: TextStyle(
                            color: Colors.red.shade200,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: standalone.clearAlerts,
                          child: Text(
                            lang == "en" ? "Clear" : "Limpiar",
                            style: TextStyle(
                                color: Colors.grey.shade400, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ...standalone.alerts.take(3).map(
                          (a) => Text(
                            "• ${a.message}",
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                          ),
                        ),
                  ],
                ),
              ),
            ),

          // Controles
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!standalone.timerRunning)
                  ElevatedButton.icon(
                    onPressed: () => _startTimer(context),
                    icon: const Icon(Icons.play_arrow),
                    label: Text(lang == "en"
                        ? "Start monitoring"
                        : "Iniciar monitoreo"),
                  ),
                if (standalone.timerRunning && !standalone.timerPaused)
                  ElevatedButton.icon(
                    onPressed: () => standalone.pauseTimer(),
                    icon: const Icon(Icons.pause),
                    label: Text(lang == "en" ? "Pause" : "Pausa"),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade700),
                  ),
                if (standalone.timerRunning && standalone.timerPaused)
                  ElevatedButton.icon(
                    onPressed: () => standalone.resumeTimer(),
                    icon: const Icon(Icons.play_arrow),
                    label: Text(lang == "en" ? "Resume" : "Reanudar"),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700),
                  ),
                if (standalone.timerRunning)
                  ElevatedButton.icon(
                    onPressed: () => standalone.stopTimer(),
                    icon: const Icon(Icons.stop),
                    label: Text(lang == "en" ? "Stop" : "Parar"),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700),
                  ),
              ],
            ),
          ),

          if (standalone.timerRunning)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                defaultTargetPlatform == TargetPlatform.iOS
                    ? (lang == 'en'
                        ? 'Keep CocinaP open to keep the live camera running on iPhone. iOS suspends camera networking in the background; the stream reconnects when you return.'
                        : 'Mantén CocinaP abierta para conservar el video en iPhone. iOS suspende la conexión de cámara en segundo plano; el stream se reconecta al volver.')
                    : (lang == 'en'
                        ? 'Monitoring keeps the screen awake and uses an Android foreground notification. Reopen CocinaP if Android pauses the stream; it will reconnect automatically.'
                        : 'El monitoreo mantiene la pantalla encendida y usa una notificación persistente en Android. Si Android pausa el video, vuelve a CocinaP para reconectarlo automáticamente.'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: Colors.white60),
              ),
            ),

          // Acceso a cambiar de dispositivo/cámara
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showDevicesSheet(context),
                icon: const Icon(Icons.devices, size: 18),
                label: Text(AppLocal.language == "en"
                    ? "Change device or camera"
                    : "Cambiar dispositivo o cámara"),
              ),
            ),
          ),

          // Aviso de modo
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(
              standalone.cameraSource == StandaloneCameraSource.ipCamera
                  ? (AppLocal.language == "en"
                      ? "Using IP camera · ${standalone.cameraSourceLabel}"
                      : "Usando cámara IP · ${standalone.cameraSourceLabel}")
                  : (AppLocal.language == "en"
                      ? "Using phone camera"
                      : "Usando cámara del móvil"),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  /// Texto que indica la próxima alerta programada o las ya emitidas.
  String _nextAlertLabel(StandaloneProvider standalone) {
    final intervals = standalone.sortedIntervals;
    final lang = AppLocal.language;
    if (intervals.isEmpty) {
      return lang == "en"
          ? "No alert intervals configured"
          : "Sin intervalos de alerta configurados";
    }
    final fired = standalone.firedIntervalCount;
    if (fired < intervals.length) {
      return lang == "en"
          ? "Next alert after ${intervals[fired]} min without a person"
          : "Próxima alerta a los ${intervals[fired]} min sin persona";
    }
    return lang == "en"
        ? "All alerts emitted (last: ${intervals.last} min)"
        : "Todas las alertas emitidas (última: ${intervals.last} min)";
  }

  /// Muestra la hoja inferior con los dispositivos/cámaras disponibles,
  /// permite cambiar de fuente y explica las formas de conectar la app.
  void _showDevicesSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => const _DevicesSheet(),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  final bool active;
  final bool personPresent;
  const _LiveBadge({required this.active, required this.personPresent});

  @override
  Widget build(BuildContext context) {
    final color = !active
        ? Colors.grey
        : (personPresent ? Colors.greenAccent : Colors.orangeAccent);
    final label = !active
        ? (AppLocal.language == "en" ? "NO SIGNAL" : "SIN SEÑAL")
        : (personPresent
            ? (AppLocal.language == "en" ? "LIVE" : "EN VIVO")
            : (AppLocal.language == "en" ? "NO PERSON" : "SIN PERSONA"));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

/// Hoja inferior que lista los dispositivos/cámaras disponibles, permite
/// cambiar de fuente de video y muestra un tutorial breve de las formas de
/// conectar la app a una cámara.
class _DevicesSheet extends StatelessWidget {
  const _DevicesSheet();

  Future<void> _select(
      BuildContext context, StandaloneCameraSource source) async {
    final standalone = context.read<StandaloneProvider>();
    final settings = context.read<SettingsService>();
    if (source == StandaloneCameraSource.ipCamera) {
      await _configureIpCamera(context);
      return;
    }
    standalone.setCameraSource(source);
    await settings.setStandaloneSourceIndex(0);
    if (context.mounted) Navigator.pop(context);
  }

  Future<void> _configureIpCamera(BuildContext context) async {
    final standalone = context.read<StandaloneProvider>();
    final settings = context.read<SettingsService>();
    final url = await showCameraUrlDialog(
      context,
      currentUrl: standalone.cameraUrl,
      language: AppLocal.language,
    );
    if (url == null || !context.mounted) return;
    standalone.setCameraSource(StandaloneCameraSource.ipCamera);
    standalone.setCameraUrl(url);
    await settings.setStandaloneCameraUrl(url);
    await settings.setStandaloneSourceIndex(1);
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppLocal.language;
    final standalone = context.watch<StandaloneProvider>();
    final scheme = Theme.of(context).colorScheme;
    final isPhone = standalone.cameraSource == StandaloneCameraSource.phone;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lang == "en" ? "Devices and cameras" : "Dispositivos y cámaras",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                lang == "en"
                    ? "Choose where to monitor your kitchen"
                    : "Elige desde dónde monitorear tu cocina",
                style: TextStyle(fontSize: 13, color: Colors.white60),
              ),
              const SizedBox(height: 12),

              // Cámara del móvil
              _DeviceTile(
                icon: Icons.smartphone,
                title: lang == "en" ? "Phone camera" : "Cámara del móvil",
                subtitle: lang == "en"
                    ? "Use rear camera of this phone"
                    : "Usa la cámara trasera de este teléfono",
                selected: isPhone,
                onTap: () => _select(context, StandaloneCameraSource.phone),
              ),

              // Cámara IP
              _DeviceTile(
                icon: Icons.videocam,
                title: lang == "en"
                    ? "IP Camera (home / security)"
                    : "Cámara IP (hogar / seguridad)",
                subtitle: standalone.cameraUrl.isNotEmpty
                    ? cameraUrlDisplayLabel(standalone.cameraUrl)
                    : (lang == "en"
                        ? "Not configured yet"
                        : "Aún no has configurado una URL"),
                selected: !isPhone,
                onTap: () => _select(context, StandaloneCameraSource.ipCamera),
                trailing: TextButton(
                  onPressed: () => _configureIpCamera(context),
                  child: Text(lang == "en" ? "Configure" : "Configurar"),
                ),
              ),

              // PC connection removed

              const SizedBox(height: 20),
              Text(
                lang == "en"
                    ? "How to use"
                    : "Cómo conectar la app a una cámara",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 8),

              _HowToRow(
                number: 1,
                icon: Icons.smartphone,
                title: lang == "en"
                    ? "Phone camera (no extra equipment)"
                    : "Cámara del móvil (sin equipos)",
                body: lang == "en"
                    ? "Place the phone pointing to the stove. Fastest way, no extra equipment needed."
                    : "Coloca el teléfono apuntando a la estufa. Es la forma más rápida: no necesitas nada más.",
              ),
              _HowToRow(
                number: 2,
                icon: Icons.videocam,
                title: lang == "en"
                    ? "IP camera via MJPEG URL"
                    : "Cámara IP por URL MJPEG",
                body: lang == "en"
                    ? "Configure IP camera in Settings and paste HTTP/MJPEG URL."
                    : "Toca 'Cámara IP → Configurar' y pega la URL HTTP/MJPEG de tu cámara.",
              ),
              // PC connection section removed
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.school, size: 18, color: scheme.primary),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        "Puedes cambiar de fuente cuando quieras; el cambio se "
                        "aplica al instante en el monitoreo.",
                        style: TextStyle(fontSize: 12.5, color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;
  const _DeviceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final borderColor =
        selected ? scheme.primary : Colors.white.withValues(alpha: 0.1);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: selected
            ? scheme.primary.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: selected ? 1.5 : 1),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: scheme.primary, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12.5),
        ),
        trailing: trailing ??
            (selected
                ? Icon(Icons.check_circle, color: scheme.primary)
                : const Icon(Icons.chevron_right)),
      ),
    );
  }
}

class _HowToRow extends StatelessWidget {
  final int number;
  final IconData icon;
  final String title;
  final String body;
  const _HowToRow({
    required this.number,
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: scheme.primary,
            child: Text(
              "$number",
              style: TextStyle(
                color: scheme.onPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 15, color: scheme.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: const TextStyle(fontSize: 12.5, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dibuja las cajas detectadas por el modelo sobre la vista de la cámara.
///
/// Las coordenadas de [DetectedBox] son normalizadas [0,1] sobre el frame
/// completo, por lo que se escalan directamente al tamaño del lienzo.
class _DetectionOverlayPainter extends CustomPainter {
  final DetectionResult result;
  final double frameWidth;
  final double frameHeight;

  const _DetectionOverlayPainter({
    required this.result,
    required this.frameWidth,
    required this.frameHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final box in result.boxes) {
      final isPerson = box.classId == 1;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isPerson ? 3 : 1.5
        ..color = isPerson
            ? Colors.greenAccent
            : Colors.cyanAccent.withValues(alpha: 0.6);

      final rect = Rect.fromLTRB(
        box.left * size.width,
        box.top * size.height,
        box.right * size.width,
        box.bottom * size.height,
      );
      canvas.drawRect(rect, paint);

      final label = "${box.label} ${(box.score * 100).toStringAsFixed(0)}%";
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: Colors.black,
            fontSize: 11,
            fontWeight: isPerson ? FontWeight.bold : FontWeight.normal,
            backgroundColor: isPerson ? Colors.greenAccent : Colors.cyanAccent,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
          canvas, Offset(rect.left, (rect.top - 14).clamp(0, size.height)));
    }
  }

  @override
  bool shouldRepaint(covariant _DetectionOverlayPainter oldDelegate) =>
      oldDelegate.result != result;
}

/// Panel de diagnóstico que muestra en pantalla el estado del detector.
class _DetectionDebugPanel extends StatelessWidget {
  final bool loading;
  final bool loaded;
  final int people;
  final double maxScore;
  final int total;
  final int frames;
  final String info;

  const _DetectionDebugPanel({
    required this.loading,
    required this.loaded,
    required this.people,
    required this.maxScore,
    required this.total,
    required this.frames,
    required this.info,
  });

  @override
  Widget build(BuildContext context) {
    final lang = AppLocal.language;
    final status = loading
        ? (lang == "en" ? "Loading model..." : "Cargando modelo...")
        : (loaded
            ? (lang == "en" ? "Model active" : "Modelo activo")
            : (lang == "en" ? "Model not loaded" : "Modelo no cargado"));
    final color = people > 0
        ? Colors.greenAccent
        : (loaded ? Colors.orangeAccent : Colors.redAccent);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            status,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          Text(
            (AppLocal.language == "en"
                ? "People: $people  (max ${(maxScore * 100).toStringAsFixed(0)}%)"
                : "Personas: $people  (máx ${(maxScore * 100).toStringAsFixed(0)}%)"),
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
          Text(
            (AppLocal.language == "en"
                ? "Objects: $total  Frames: $frames"
                : "Objetos: $total  Frames: $frames"),
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
          if (info.isNotEmpty)
            Text(
              info,
              style: const TextStyle(color: Colors.white54, fontSize: 9),
            ),
        ],
      ),
    );
  }
}
