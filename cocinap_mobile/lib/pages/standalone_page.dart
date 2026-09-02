import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image/image.dart' as img;
import '../providers/standalone_provider.dart';
import '../providers/server_provider.dart';
import '../services/background_service.dart';
import '../services/person_detector.dart';

/// Página del modo independiente: monitorea la cocina con la cámara del móvil,
/// usando un temporizador configurable. Si no se detecta una persona durante
/// el plazo, emite alertas.
class StandalonePage extends StatefulWidget {
  const StandalonePage({super.key});

  @override
  State<StandalonePage> createState() => _StandalonePageState();
}

class _StandalonePageState extends State<StandalonePage> {
  CameraController? _camera;
  final PersonDetector _detector = PersonDetector();
  Timer? _alertTimer;
  bool _cameraError = false;
  bool _detectorLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDetector();
    _initCamera();
    _startAlertLoop();
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

  Future<void> _initCamera() async {
    final standalone = context.read<StandaloneProvider>();
    try {
      final cameras = await availableCameras();
      if (!mounted || cameras.isEmpty) {
        setState(() => _cameraError = true);
        return;
      }
      // Preferir cámara trasera (apunta a la cocina).
      final CameraDescription back;
      try {
        back = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.back);
      } catch (_) {
        back = cameras.first;
      }
      final controller = CameraController(back, ResolutionPreset.medium);
      await controller.initialize();
      if (!mounted) return;
      setState(() => _camera = controller);
      standalone.setCameraActive(true);
      _startImageStream();
    } catch (_) {
      if (mounted) setState(() => _cameraError = true);
    }
  }

  /// Stream de frames de la cámara → detección de personas.
  void _startImageStream() {
    _camera!.startImageStream((cameraImage) async {
      if (_detectorLoading || !_detector.loaded) return;

      // Usar el plano Y (luminancia) como imagen en escala de grises.
      // Es visualmente suficiente para detección de personas con SSD.
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
            confidence: context.read<StandaloneProvider>().confidence);
        context.read<StandaloneProvider>().onPersonDetected(count);
      } catch (_) {}
    });
  }

  void _startAlertLoop() {
    _alertTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      final standalone = context.read<StandaloneProvider>();
      if (standalone.shouldAlert()) {
        standalone.triggerAlert(
          "Cocina desatendida durante ${standalone.noPersonAlertSeconds}s",
        );
        BackgroundServiceManager.showAlarm("Cocina desatendida - revise la cocina");
      }
    });
  }

  @override
  void dispose() {
    _alertTimer?.cancel();
    _camera?.dispose();
    _detector.dispose();
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
    final server = context.watch<ServerProvider>();
    final isConnected = server.status == ConnectionStatus.connected;

    final color = standalone.personPresent
        ? Colors.green
        : (standalone.timerRunning ? Colors.orange : Colors.grey);

    return Scaffold(
      appBar: AppBar(title: const Text("Modo independiente")),
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

          // Vista de cámara
          Expanded(
            child: _cameraError
                ? const Center(
                    child: Text(
                      "No se pudo acceder a la cámara.\nVerifica los permisos.",
                      style: TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  )
                : _camera == null
                    ? const Center(child: CircularProgressIndicator())
                    : CameraPreview(_camera!),
          ),

          // Estadísticas
          Padding(
            padding: const EdgeInsets.all(12),
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
                _StatTile(
                  icon: Icons.person,
                  label: "Persona en cocina",
                  value: standalone.personPresent ? "SÍ" : "NO",
                  color: color,
                ),
              ],
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

          // Aviso de modo
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(
              isConnected
                  ? "También estás conectado al PC · Elige modo en Ajustes"
                  : "Funcionando solo con la cámara del móvil",
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
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
