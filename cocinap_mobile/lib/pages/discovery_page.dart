import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/server_provider.dart';

class DiscoveryPage extends StatefulWidget {
  const DiscoveryPage({super.key});

  @override
  State<DiscoveryPage> createState() => _DiscoveryPageState();
}

class _DiscoveryPageState extends State<DiscoveryPage> {
  final TextEditingController _urlCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final server = context.read<ServerProvider>();
    if (server.serverUrl.isNotEmpty) {
      _urlCtrl.text = server.serverUrl;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      server.autoConnect();
    });
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("CocinaP")),
      body: Consumer<ServerProvider>(
        builder: (context, server, _) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.kitchen, size: 80, color: Colors.orange),
                const SizedBox(height: 24),
                const Text(
                  "Conectar al servidor CocinaP",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  _statusText(server),
                  style: TextStyle(
                    fontSize: 14,
                    color: _statusColor(server.status),
                  ),
                  textAlign: TextAlign.center,
                ),
                if (server.errorMessage.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    server.errorMessage,
                    style: const TextStyle(fontSize: 12, color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),
                TextField(
                  controller: _urlCtrl,
                  decoration: InputDecoration(
                    labelText: "URL del servidor",
                    hintText: "http://192.168.1.100:8080",
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.link),
                      onPressed: () {
                        final url = _urlCtrl.text.trim();
                        if (url.isNotEmpty) {
                          server.setServerUrl(url);
                          server.connect();
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: server.status == ConnectionStatus.connecting
                        ? null
                        : () => server.discover(),
                    icon: const Icon(Icons.search),
                    label: const Text("Buscar en la red"),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _statusText(ServerProvider server) {
    switch (server.status) {
      case ConnectionStatus.disconnected:
        return "Ingresa la URL o busca automáticamente";
      case ConnectionStatus.connecting:
        return "Conectando...";
      case ConnectionStatus.connected:
        return "Conectado a ${server.serverUrl} (v${server.version})";
      case ConnectionStatus.error:
        return "Error de conexión";
    }
  }

  Color _statusColor(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connected:
        return Colors.green;
      case ConnectionStatus.error:
        return Colors.red;
      case ConnectionStatus.connecting:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
