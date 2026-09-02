import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/server_provider.dart';
import '../providers/standalone_provider.dart';
import '../services/settings_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _autoConnect = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadStandalone();
  }

  Future<void> _loadSettings() async {
    final auto = await context.read<SettingsService>().getAutoConnect();
    if (mounted) setState(() => _autoConnect = auto);
  }

  Future<void> _loadStandalone() async {
    final standalone = context.read<StandaloneProvider>();
    final settings = context.read<SettingsService>();
    standalone.setDurationMinutes(await settings.getStandaloneDuration());
    standalone.setNoPersonAlertSeconds(await settings.getStandaloneNoPersonSeconds());
    standalone.setDangerMinutes(await settings.getStandaloneDangerMinutes());
    standalone.setConfidence(await settings.getStandaloneConfidence());
  }

  @override
  Widget build(BuildContext context) {
    final server = context.watch<ServerProvider>();
    final standalone = context.watch<StandaloneProvider>();
    final settings = context.read<SettingsService>();

    return Scaffold(
      appBar: AppBar(title: const Text("Ajustes")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text("Auto-conectar al iniciar"),
            subtitle: const Text("Buscar servidor automáticamente"),
            value: _autoConnect,
            onChanged: (v) {
              setState(() => _autoConnect = v);
              settings.setAutoConnect(v);
            },
          ),
          const Divider(),
          ListTile(
            title: const Text("Servidor actual"),
            subtitle: Text(server.serverUrl.isNotEmpty
                ? server.serverUrl
                : "No conectado"),
          ),
          if (server.ips.isNotEmpty) ...[
            const Text("IPs detectadas:", style: TextStyle(fontSize: 12, color: Colors.grey)),
            ...server.ips.map((ip) => Text(ip, style: const TextStyle(fontSize: 12))),
          ],
          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text(
              "Monitoreo independiente (cámara del móvil)",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),

          // Duración del temporizador
          ListTile(
            title: const Text("Duración del monitoreo (min)"),
            trailing: SizedBox(
              width: 90,
              child: TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(isDense: true),
                onSubmitted: (v) {
                  final min = (int.tryParse(v) ?? 30).clamp(1, 240).toInt();
                  standalone.setDurationMinutes(min);
                  settings.setStandaloneDuration(min);
                },
              ),
            ),
          ),

          // Tiempo sin persona antes de alertar
          ListTile(
            title: const Text("Alertar si sin persona (seg)"),
            subtitle: const Text("Tiempo sin detectar persona para disparar alerta"),
            trailing: SizedBox(
              width: 90,
              child: TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(isDense: true),
                onSubmitted: (v) {
                  final s = (int.tryParse(v) ?? 30).clamp(10, 120).toInt();
                  standalone.setNoPersonAlertSeconds(s);
                  settings.setStandaloneNoPersonSeconds(s);
                },
              ),
            ),
          ),

          // Tiempo peligroso estimado
          ListTile(
            title: const Text("Tiempo peligroso sin atender (min)"),
            subtitle: const Text("Se considera riesgo alto después de este tiempo"),
            trailing: SizedBox(
              width: 90,
              child: TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(isDense: true),
                onSubmitted: (v) {
                  final m = (int.tryParse(v) ?? 5).clamp(1, 60).toInt();
                  standalone.setDangerMinutes(m);
                  settings.setStandaloneDangerMinutes(m);
                },
              ),
            ),
          ),

          // Confianza de detección
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Confianza detección persona: ${standalone.confidence.toStringAsFixed(2)}",
                  style: const TextStyle(fontSize: 14),
                ),
                Slider(
                  value: standalone.confidence,
                  min: 0.2,
                  max: 0.9,
                  divisions: 7,
                  label: standalone.confidence.toStringAsFixed(2),
                  onChanged: (v) {
                    standalone.setConfidence(v);
                    settings.setStandaloneConfidence(v);
                  },
                ),
              ],
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text("Notificaciones push"),
            subtitle: const Text("FCM configurado en el servidor"),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text(
              "Método de detección de persona",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          const ListTile(
            leading: Icon(Icons.smartphone),
            title: Text("En el móvil (TFLite)"),
            subtitle: Text("El modelo se ejecuta en el dispositivo, sin necesidad de PC"),
          ),
        ],
      ),
    );
  }
}
