import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../providers/standalone_provider.dart';
import '../services/person_detector.dart';
import '../services/background_service.dart';
import '../content/content.dart';

/// Página del modo independiente: monitorea la cocina en el móvil (con la
/// cámara del dispositivo o una cámara IP) usando un temporizador configurable.
/// Si no se detecta una persona durante el plazo, emite alertas.
class StandalonePage extends StatefulWidget {
  const StandalonePage({super.key});

  @override
  State<StandalonePage> createState() => _StandalonePageState();
}

class _StandalonePageState extends State<StandalonePage> {
  String get lang => AppLocal.language;
  CameraController? _camera;
  final PersonDetector _detector = PersonDetector();
  Timer? _alertTimer;
  StreamSubscription<Uint8List>? _ipStreamSub;
  bool _cameraError = false;
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
    _loadDetector();
    _initVideo();
    _startAlertLoop();
    _lastSource = context.read<StandaloneProvider>().cameraSource;
    _lastUrl = context.read<StandaloneProvider>().cameraUrl;
    context.read<StandaloneProvider>().addListener(_onProviderChanged);
  }

  void _onProviderChanged() {
    final standalone = context.read<StandaloneProvider>();
    if (standalone.cameraSource != _lastSource ||
        standalone.cameraUrl != _lastUrl) {
      _lastSource = standalone.cameraSource;
      _lastUrl = standalone.cameraUrl;
      _initVideo();
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

  Future<void> _initVideo() async {
    final standalone = context.read<StandaloneProvider>();
    final source = standalone.cameraSource;
    _lastSource = source;
    _lastUrl = standalone.cameraUrl;

    _stopVideo();

    if (source == StandaloneCameraSource.ipCamera) {
      final url = standalone.cameraUrl;
      if (url.isEmpty) {
        setState(() => _cameraError = true);
        return;
      }
      standalone.setCameraActive(true);
      _startIpStream(url);
      return;
    }

    // Fuente: cámara del móvil.
    try {
      final cameras = await availableCameras();
      if (!mounted || cameras.isEmpty) {
        setState(() => _cameraError = true);
        return;
      }
      late CameraDescription back;
      try {
        back = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.back);
      } catch (_) {
        back = cameras.first;
      }
      final controller = await _createController(back);
      if (!mounted || controller == null) {
        if (mounted) setState(() => _cameraError = true);
        return;
      }
      _updateRotation(back, controller);
      setState(() {
        _cameraError = false;
        _camera = controller;
      });
      standalone.setCameraActive(true);
      _startPhoneStream();
    } catch (e) {
      debugPrint('Camera init error: $e');
      if (mounted) setState(() => _cameraError = true);
    }
  }

  /// Crea el [CameraController] probando varias combinaciones hasta encontrar
  /// una que el dispositivo soporte. La cámara del móvil es el punto más
  /// frágil: distintas resoluciones y formatos pueden fallar con
  /// "No supported surface combination".
  Future<CameraController?> _createController(CameraDescription camera) async {    const attempts = <(ResolutionPreset, ImageFormatGroup?)>[
      (ResolutionPreset.low, ImageFormatGroup.yuv420),
      (ResolutionPreset.low, null),
      (ResolutionPreset.medium, ImageFormatGroup.yuv420),
      (ResolutionPreset.medium, null),
      (ResolutionPreset.high, null),
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
  void _startIpStream(String url) {
    _lastIpFrame = null;
    setState(() => _cameraError = true);
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
      if (mounted) setState(() => _cameraError = true);
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
    } catch (_) {
      // Ignorar frames defectuosos.
    } finally {
      _detecting = false;
    }
  }

  void _stopVideo() {
    _ipStreamSub?.cancel();
    _ipStreamSub = null;
    _camera?.dispose();
    _camera = null;
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
      BackgroundServiceManager.updateStatus(lang == "en" ? "No person: $interval min" : "Sin persona: $interval min");
    });
  }

  @override
  void dispose() {
    _alertTimer?.cancel();
    _stopVideo();
    _detector.dispose();
    context.read<StandaloneProvider>().removeListener(_onProviderChanged);
    super.dispose();
  }

  Future<void> _startTimer(BuildContext context) async {
    final standalone = context.read<StandaloneProvider>();
    final minutesCtrl = TextEditingController(text: "${standalone.durationMinutes}");
    final minutes = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Iniciar monitoreo"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: minutesCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Minutos de monitoreo (1-240)",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "Se vigila la cocina. Si NO se detecta una persona, "
              "se enviara una alerta.",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () {
              final v = int.tryParse(minutesCtrl.text) ?? 30;
              Navigator.pop(ctx, v);
            },
            child: const Text("Iniciar"),
          ),
        ],
      ),
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
        title: Text(AppLocal.language == "en" ? "Standalone mode" : "Modo independiente"),
        actions: [
          IconButton(
            tooltip: AppLocal.language == "en" ? "Change device or camera" : "Cambiar dispositivo o cámara",
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
                  color: standalone.personPresent ? Colors.greenAccent : Colors.redAccent,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    standalone.statusText,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
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
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text(
                            "No se pudo acceder a la cámara.\nRevisa la conexión y los permisos.",
                            style: TextStyle(color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : standalone.cameraSource == StandaloneCameraSource.ipCamera
                        ? (_lastIpFrame == null
                            ? const Center(
                                child: CircularProgressIndicator(),
                              )
                            : Image.memory(
                                _lastIpFrame!,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.contain,
                                gaplessPlayback: true,
                              ))
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
                    label: standalone.timerRunning ? (lang == "en" ? "Time remaining" : "Tiempo restante") : (lang == "en" ? "Timer" : "Temporizador"),
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
                    label: lang == "en" ? "Person in kitchen" : "Persona en cocina",
                    value: standalone.personPresent ? (lang == "en" ? "YES" : "SÍ") : (lang == "en" ? "NO" : "NO"),
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    label: Text(lang == "en" ? "Start monitoring" : "Iniciar monitoreo"),
                  ),
                if (standalone.timerRunning && !standalone.timerPaused)
                  ElevatedButton.icon(
                    onPressed: () => standalone.pauseTimer(),
                    icon: const Icon(Icons.pause),
                    label: Text(lang == "en" ? "Pause" : "Pausa"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700),
                  ),
                if (standalone.timerRunning && standalone.timerPaused)
                  ElevatedButton.icon(
                    onPressed: () => standalone.resumeTimer(),
                    icon: const Icon(Icons.play_arrow),
                    label: Text(lang == "en" ? "Resume" : "Reanudar"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
                  ),
                if (standalone.timerRunning)
                  ElevatedButton.icon(
                    onPressed: () => standalone.stopTimer(),
                    icon: const Icon(Icons.stop),
                    label: Text(lang == "en" ? "Stop" : "Parar"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
                  ),
              ],
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
            label: Text(AppLocal.language == "en" ? "Change device or camera" : "Cambiar dispositivo o cámara"),
          ),
            ),
          ),

          // Aviso de modo
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(
              standalone.cameraSource == StandaloneCameraSource.ipCamera
                  ? "Usando cámara IP · ${standalone.cameraSourceLabel}"
                  : "Usando cámara del móvil",
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
    if (intervals.isEmpty) return "Sin intervalos de alerta configurados";
    final fired = standalone.firedIntervalCount;
    if (fired < intervals.length) {
      return "Próxima alerta a los ${intervals[fired]} min sin persona";
    }
    return "Todas las alertas emitidas (última: ${intervals.last} min)";
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
        ? "SIN SEÑAL"
        : (personPresent ? "EN VIVO" : "SIN PERSONA");
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
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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

  Future<void> _select(BuildContext context, StandaloneCameraSource source) async {
    final standalone = context.read<StandaloneProvider>();
    standalone.setCameraSource(source);
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
                lang == "en" ? "Choose where to monitor your kitchen" : "Elige desde dónde monitorear tu cocina",
                style: TextStyle(fontSize: 13, color: Colors.white60),
              ),
              const SizedBox(height: 12),

              // Cámara del móvil
              _DeviceTile(
                icon: Icons.smartphone,
                title: lang == "en" ? "Phone camera" : "Cámara del móvil",
                subtitle: lang == "en" ? "Use rear camera of this phone" : "Usa la cámara trasera de este teléfono",
                selected: isPhone,
                onTap: () => _select(context, StandaloneCameraSource.phone),
              ),

              // Cámara IP
              _DeviceTile(
                icon: Icons.videocam,
                title: lang == "en" ? "IP Camera (home / security)" : "Cámara IP (hogar / seguridad)",
                subtitle: standalone.cameraUrl.isNotEmpty
                    ? standalone.cameraUrl
                    : (lang == "en" ? "Not configured yet" : "Aún no has configurado una URL"),
                selected: !isPhone,
                onTap: () {},
                trailing: TextButton(
                  onPressed: () {},
                  child: Text(lang == "en" ? "Configure" : "Configurar"),
                ),
              ),

              // PC connection removed

              const SizedBox(height: 20),
              Text(
                lang == "en" ? "How to use" : "Cómo conectar la app a una cámara",
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
                title: lang == "en" ? "Phone camera (no extra equipment)" : "Cámara del móvil (sin equipos)",
                body: lang == "en" ? "Place the phone pointing to the stove. Fastest way, no extra equipment needed." : "Coloca el teléfono apuntando a la estufa. Es la forma más rápida: no necesitas nada más.",
              ),
              _HowToRow(
                number: 2,
                icon: Icons.videocam,
                title: lang == "en" ? "IP camera via MJPEG URL" : "Cámara IP por URL MJPEG",
                body: lang == "en" ? "Configure IP camera in Settings and paste HTTP/MJPEG URL." : "Toca 'Cámara IP → Configurar' y pega la URL HTTP/MJPEG de tu cámara.",
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
  final bool enabled;
  final VoidCallback onTap;
  final Widget? trailing;
  const _DeviceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.enabled = true,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final borderColor = selected
        ? scheme.primary
        : Colors.white.withValues(alpha: 0.1);
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Container(
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
      tp.paint(canvas, Offset(rect.left, (rect.top - 14).clamp(0, size.height)));
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
        : (loaded ? (lang == "en" ? "Model active" : "Modelo activo") : (lang == "en" ? "Model not loaded" : "Modelo no cargado"));
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
            (AppLocal.language == "en" ? "People: $people  (max ${(maxScore * 100).toStringAsFixed(0)}%)" : "Personas: $people  (máx ${(maxScore * 100).toStringAsFixed(0)}%)"),
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
          Text(
            (AppLocal.language == "en" ? "Objects: $total  Frames: $frames" : "Objetos: $total  Frames: $frames"),
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
