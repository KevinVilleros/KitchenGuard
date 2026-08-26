import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/server_provider.dart';
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
  }

  Future<void> _loadSettings() async {
    final auto = await context.read<SettingsService>().getAutoConnect();
    if (mounted) setState(() => _autoConnect = auto);
  }

  @override
  Widget build(BuildContext context) {
    final server = context.watch<ServerProvider>();

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
              context.read<SettingsService>().setAutoConnect(v);
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
          ListTile(
            title: const Text("Notificaciones push"),
            subtitle: const Text("FCM configurado en el servidor"),
          ),
        ],
      ),
    );
  }
}
