import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/standalone_provider.dart';
import '../services/settings_service.dart';

/// Configuración de la fuente de cámara para el modo independiente:
/// elegir entre la cámara del móvil o una cámara IP de hogar/seguridad,
/// e ingresar su URL HTTP/MJPEG.
class IpCameraPage extends StatefulWidget {
  const IpCameraPage({super.key});

  @override
  State<IpCameraPage> createState() => _IpCameraPageState();
}

class _IpCameraPageState extends State<IpCameraPage> {
  late TextEditingController _urlCtrl;
  late bool _useIp;

  @override
  void initState() {
    super.initState();
    final standalone = context.read<StandaloneProvider>();
    _useIp = standalone.cameraSource == StandaloneCameraSource.ipCamera;
    _urlCtrl = TextEditingController(text: standalone.cameraUrl);
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final standalone = context.read<StandaloneProvider>();
    final settings = context.read<SettingsService>();
    final url = _urlCtrl.text.trim();
    final useIp = _useIp;

    if (useIp && url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ingresa la URL de la cámara IP")),
      );
      return;
    }

    standalone.setCameraSource(useIp ? StandaloneCameraSource.ipCamera : StandaloneCameraSource.phone);
    standalone.setCameraUrl(url);
    await settings.setStandaloneSourceIndex(useIp ? 1 : 0);
    await settings.setStandaloneCameraUrl(url);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Fuente de cámara actualizada")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Fuente de cámara")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            "Elige cómo monitorear la cocina en modo independiente:",
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          RadioListTile<bool>(
            title: const Text("Cámara del móvil"),
            subtitle: const Text("Usa la cámara del dispositivo"),
            value: false,
            groupValue: _useIp,
            onChanged: (v) => setState(() => _useIp = v == false),
          ),
          RadioListTile<bool>(
            title: const Text("Cámara IP (hogar / seguridad)"),
            subtitle: const Text("Conéctate a una cámara de red"),
            value: true,
            groupValue: _useIp,
            onChanged: (v) => setState(() => _useIp = v == true),
          ),
          if (_useIp) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _urlCtrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: "URL HTTP/MJPEG",
                hintText: "http://usuario:pass@192.168.1.100/stream",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Ejemplo: http://192.168.1.100/video.cgi?resolution=640x360\n"
              "Consulta la guía completa en Ayuda → Guía de cámaras.",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text("Guardar"),
          ),
        ],
      ),
    );
  }
}