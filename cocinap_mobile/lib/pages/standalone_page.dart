import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image/image.dart' as img;
import '../providers/standalone_provider.dart';
import '../providers/server_provider.dart';
import '../services/background_service.dart';
import '../services/person_detector.dart';
import '../services/mjpeg_service.dart';
import '../services/settings_service.dart';
import 'ip_camera_page.dart';
import 'dashboard_page.dart';

/// Página del modo independiente: monitorea la cocina en el móvil (con la
/// cámara del dispositivo o una cámara IP) usando un temporizador configurable.
/// Si no se detecta una persona durante el plazo, emite alertas.
class StandalonePage extends StatefulWidget {
  const StandalonePage({super.key});

  @override
  State<StandalonePage> createState() => _StandalonePageState();
}

class _StandalonePageState extends State<StandalonePage> {
  CameraController? _camera;
  final PersonDetector _detector = PersonDetector();
  final MjpegService _mjpeg = MjpegService();
  Timer? _alertTimer;
  StreamSubscription<Uint8List>? _ipStreamSub;
  bool _cameraError = false;
  bool _detectorLoading = false;
  Uint8List? _lastIpFrame;
  StandaloneCameraSource _lastSource = StandaloneCameraSource.phone;
  String _lastUrl = "";

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
      await _detector.load('assets/models/ssd_mobilenet_v2_coco.tflite');
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
      final controller = CameraController(
        back,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) return;
      setState(() => _cameraError = false);
      setState(() => _camera = controller);
      standalone.setCameraActive(true);
      _startPhoneStream();
    } catch (_) {
      if (mounted) setState(() => _cameraError = true);
    }
  }

  /// Consume un stream MJPEG de una cámara IP y lo envía al detector.
  void _startIpStream(String url) {
    _lastIpFrame = null;
    final standalone = context.read<StandaloneProvider>();
    _ipStreamSub = _mjpeg.start(url).listen((frame) async {
      if (mounted) setState(() => _lastIpFrame = frame);
      if (_detectorLoading || !_detector.loaded) return;
      final count = await _detector.detectFromJpeg(frame,
          confidence: standalone.confidence);
      standalone.onPersonDetected(count);
    });
  }

  /// Stream de frames de la cámara del móvil → detección de personas.
  void _startPhoneStream() {
    final standalone = context.read<StandaloneProvider>();
    _camera!.startImageStream((cameraImage) async {
      if (_detectorLoading || !_detector.loaded) return;

      try {
        final plane = cameraImage.planes.first;
        final width = cameraImage.width;
        final height = cameraImage.height;
        final yBytes = plane.bytes;

        final gray = img.Image.fromBytes(
          width: width,
          height: height,
          bytes: yBytes.buffer,
          numChannels: 1,
        );

        final count = await _detector.detectPerson(gray,
            confidence: standalone.confidence);
        standalone.onPersonDetected(count);
      } catch (_) {}
    });
  }

  void _stopVideo() {
    _ipStreamSub?.cancel();
    _ipStreamSub = null;
    _mjpeg.stop();
    _camera?.dispose();
    _camera = null;
    _lastIpFrame = null;
  }

  void _startAlertLoop() {
    _alertTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      final standalone = context.read<StandaloneProvider>();
      if (standalone.shouldAlert()) {
        final absence = standalone.absenceSeconds;
        standalone.triggerAlert(
          "Sin detectar persona en la cocina por ${absence}s",
        );
        BackgroundServiceManager.showAlarm(
          "Cocina desatendida: sin persona por ${absence}s. Revise la cocina.",
        );
      }
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
        title: const Text("Modo independiente"),
        actions: [
          IconButton(
            tooltip: "Cambiar dispositivo o cámara",
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
                    label: standalone.timerRunning ? "Tiempo restante" : "Temporizador",
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
                    label: "Persona en cocina",
                    value: standalone.personPresent ? "SÍ" : "NO",
                    color: color,
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
                    label: const Text("Iniciar monitoreo"),
                  ),
                if (standalone.timerRunning && !standalone.timerPaused)
                  ElevatedButton.icon(
                    onPressed: () => standalone.pauseTimer(),
                    icon: const Icon(Icons.pause),
                    label: const Text("Pausa"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700),
                  ),
                if (standalone.timerRunning && standalone.timerPaused)
                  ElevatedButton.icon(
                    onPressed: () => standalone.resumeTimer(),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text("Reanudar"),
                  ),
                if (standalone.timerRunning)
                  ElevatedButton.icon(
                    onPressed: () => standalone.stopTimer(),
                    icon: const Icon(Icons.stop),
                    label: const Text("Parar"),
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
                label: const Text("Cambiar dispositivo o cámara"),
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
    final settings = context.read<SettingsService>();
    standalone.setCameraSource(source);
    await settings.setStandaloneSourceIndex(
      source == StandaloneCameraSource.ipCamera ? 1 : 0,
    );
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final standalone = context.watch<StandaloneProvider>();
    final server = context.watch<ServerProvider>();
    final connected = server.status == ConnectionStatus.connected;
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
              const Text(
                "Dispositivos y cámaras",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                "Elige desde dónde monitorear tu cocina",
                style: TextStyle(fontSize: 13, color: Colors.white60),
              ),
              const SizedBox(height: 12),

              // Cámara del móvil
              _DeviceTile(
                icon: Icons.smartphone,
                title: "Cámara del móvil",
                subtitle: "Usa la cámara trasera de este teléfono",
                selected: isPhone,
                onTap: () => _select(context, StandaloneCameraSource.phone),
              ),

              // Cámara IP
              _DeviceTile(
                icon: Icons.videocam,
                title: "Cámara IP (hogar / seguridad)",
                subtitle: standalone.cameraUrl.isNotEmpty
                    ? standalone.cameraUrl
                    : "Aún no has configurado una URL",
                selected: !isPhone,
                onTap: () async {
                  Navigator.pop(context);
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const IpCameraPage()),
                  );
                },
                trailing: TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const IpCameraPage()),
                    );
                  },
                  child: const Text("Configurar"),
                ),
              ),

              // PC conectado (opcional)
              _DeviceTile(
                icon: Icons.computer,
                title: "PC con CocinaP",
                subtitle: connected
                    ? server.serverUrl.replaceAll("http://", "")
                    : "No conectado · Escanea el QR del PC",
                selected: false,
                enabled: connected,
                onTap: connected
                    ? () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const DashboardPage()),
                        );
                      }
                    : () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "Conecta el PC desde la pestaña Conectar",
                            ),
                          ),
                        );
                      },
              ),

              const SizedBox(height: 20),
              Text(
                "Cómo conectar la app a una cámara",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 8),

              const _HowToRow(
                number: 1,
                icon: Icons.smartphone,
                title: "Cámara del móvil (sin equipos)",
                body: "Coloca el teléfono apuntando a la estufa. Es la forma "
                    "más rápida: no necesitas nada más.",
              ),
              const _HowToRow(
                number: 2,
                icon: Icons.videocam,
                title: "Cámara IP por URL MJPEG",
                body: "Toca 'Cámara IP → Configurar' y pega la URL HTTP/MJPEG "
                    "de tu cámara (http://usuario:pass@IP/stream).",
              ),
              const _HowToRow(
                number: 3,
                icon: Icons.qr_code_scanner,
                title: "PC con CocinaP (opcional)",
                body: "En la pestaña 'Conectar' escanea el QR del PC para ver "
                    "su cámara y recibir también alarmas de fuego y humo.",
              ),
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
