import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../providers/server_provider.dart';
import '../services/settings_service.dart';

class DiscoveryPage extends StatefulWidget {
  const DiscoveryPage({super.key});

  @override
  State<DiscoveryPage> createState() => _DiscoveryPageState();
}

class _DiscoveryPageState extends State<DiscoveryPage> {
  final TextEditingController _urlCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  MobileScannerController? _scannerController;

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
    _scannerController?.dispose();
    super.dispose();
  }

  void _connect(String url) {
    context.read<ServerProvider>().connectTo(url);
  }

  void _scanQr() {
    final controller = MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
    _scannerController = controller;
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => _QrScannerPage(controller: controller)))
        .then((value) {
      if (value is String && value.isNotEmpty) {
        _connect(value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("CocinaP"),
        actions: [
          Consumer<ServerProvider>(
            builder: (context, server, _) => server.status == ConnectionStatus.connected
                ? IconButton(
                    tooltip: "Desconectar",
                    icon: const Icon(Icons.link_off),
                    onPressed: () => server.disconnect(),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
      body: Consumer<ServerProvider>(
        builder: (context, server, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StatusCard(server: server),
                const SizedBox(height: 20),

                // --- QR scan: primary action ---
                FilledButton.icon(
                  onPressed: server.status == ConnectionStatus.connecting ? null : _scanQr,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  icon: const Icon(Icons.qr_code_scanner, size: 28),
                  label: const Text("Escanear QR del PC"),
                ),
                const SizedBox(height: 6),
                Text(
                  "En el programa de la PC toca 'Mostrar codigo QR' y escanealo",
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // --- Auto search status ---
                if (server.status != ConnectionStatus.connected) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (server.autoSearching)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Icon(Icons.wifi_find, size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 8),
                      Text(
                        server.autoSearching
                            ? "Buscando CocinaP en la red... (automatico)"
                            : "Busqueda automatica detenida",
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                      const SizedBox(width: 8),
                      if (server.autoSearching)
                        TextButton(
                          onPressed: () => server.stopAutoSearch(),
                          child: const Text("Detener", style: TextStyle(fontSize: 12)),
                        )
                      else
                        TextButton(
                          onPressed: () => server.startAutoSearch(),
                          child: const Text("Buscar", style: TextStyle(fontSize: 12)),
                        ),
                    ],
                  ),
                  if (server.foundServers.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...server.foundServers.map((s) => _ServerCard(
                          title: s.hostname,
                          url: s.url,
                          selected: s.url == server.serverUrl,
                          onTap: () => _connect(s.url),
                        )),
                  ],
                  const SizedBox(height: 8),
                ],

                // --- Recent servers ---
                if (server.recentServers.isNotEmpty) ...[
                  Text(
                    "Servidores recientes",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade400),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: server.recentServers.map((url) {
                      return InputChip(
                        avatar: const Icon(Icons.computer, size: 16),
                        label: Text(url.replaceAll("http://", "")),
                        onPressed: () => _connect(url),
                        onDeleted: () async {
                          final provider = context.read<ServerProvider>();
                          await context.read<SettingsService>().removeRecentServer(url);
                          if (mounted) {
                            provider.refreshRecents();
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                ],

                // --- Manual entry (fallback) ---
                ExpansionTile(
                  leading: const Icon(Icons.link),
                  title: const Text("Conexion manual", style: TextStyle(fontSize: 14)),
                  subtitle: const Text("Escribe la direccion del PC", style: TextStyle(fontSize: 12)),
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  children: [
                    Form(
                      key: _formKey,
                      child: Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _urlCtrl,
                              decoration: const InputDecoration(
                                hintText: "http://192.168.1.100:8080",
                                labelText: "URL del servidor",
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              keyboardType: TextInputType.url,
                              onFieldSubmitted: (_) => _connect(_urlCtrl.text.trim()),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: server.status == ConnectionStatus.connecting
                                ? null
                                : () => _connect(_urlCtrl.text.trim()),
                            child: const Text("Conectar"),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final ServerProvider server;
  const _StatusCard({required this.server});

  @override
  Widget build(BuildContext context) {
    final connected = server.status == ConnectionStatus.connected;
    final color = connected
        ? Colors.green
        : server.status == ConnectionStatus.error
            ? Colors.red
            : server.status == ConnectionStatus.connecting
                ? Colors.orange
                : Colors.grey;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(connected ? Icons.check_circle : Icons.info_outline, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  connected ? "Conectado" : "Sin conexion",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          if (connected) ...[
            const SizedBox(height: 6),
            Text(
              server.serverUrl.replaceAll("http://", ""),
              style: const TextStyle(fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              "v${server.version}",
              style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
            ),
          ] else if (server.errorMessage.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              server.errorMessage,
              style: const TextStyle(fontSize: 12, color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _ServerCard extends StatelessWidget {
  final String title;
  final String url;
  final bool selected;
  final VoidCallback onTap;

  const _ServerCard({
    required this.title,
    required this.url,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: selected ? Colors.green.withValues(alpha: 0.08) : null,
      child: ListTile(
        leading: const Icon(Icons.computer, color: Colors.orange),
        title: Text(title),
        subtitle: Text(url.replaceAll("http://", "")),
        trailing: selected ? const Icon(Icons.check_circle, color: Colors.green) : null,
        onTap: onTap,
      ),
    );
  }
}

class _QrScannerPage extends StatefulWidget {
  final MobileScannerController controller;
  const _QrScannerPage({required this.controller});

  @override
  State<_QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<_QrScannerPage> {
  bool _done = false;
  bool _flash = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Escanear QR del PC")),
      body: Stack(
        children: [
          MobileScanner(
            controller: widget.controller,
            onDetect: (capture) {
              if (_done) return;
              for (final b in capture.barcodes) {
                final raw = b.rawValue;
                if (raw != null &&
                    (raw.startsWith("http://") || raw.startsWith("https://"))) {
                  _done = true;
                  widget.controller.stop();
                  Navigator.of(context).pop(raw);
                  return;
                }
              }
            },
          ),
          const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.qr_code, size: 120, color: Colors.white70),
                SizedBox(height: 12),
                Text(
                  "Apunta al codigo QR del PC",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Center(
              child: IconButton.filled(
                tooltip: _flash ? "Apagar linterna" : "Encender linterna",
                icon: Icon(_flash ? Icons.flash_off : Icons.flash_on),
                onPressed: () async {
                  await widget.controller.toggleTorch();
                  setState(() => _flash = !_flash);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}