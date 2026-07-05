import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/server_provider.dart';
import '../widgets/mjpeg_viewer.dart';
import '../widgets/status_card.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Map<String, dynamic> _status = {};
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _fetchStatus());
  }

  Future<void> _fetchStatus() async {
    final server = context.read<ServerProvider>();
    if (server.status != ConnectionStatus.connected) return;
    try {
      final status = await server.apiService.getStatus();
      if (mounted) setState(() => _status = status);
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final server = context.watch<ServerProvider>();
    final streamUrl = server.status == ConnectionStatus.connected
        ? "${server.serverUrl}/api/stream"
        : "";

    final fire = _status["fire_regions"] ?? 0;
    final smoke = _status["smoke_regions"] ?? 0;
    final persons = _status["persons"] ?? 0;
    final pots = _status["pots"] ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text("Cámara en vivo")),
      body: Column(
        children: [
          Expanded(
            child: streamUrl.isNotEmpty
                ? MjpegViewer(url: streamUrl)
                : Container(
                    color: Colors.black,
                    child: const Center(
                      child: Text(
                        "Sin conexión",
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: _cardWidth(context),
                  child: StatusCard(
                    title: "Fuego",
                    value: "$fire",
                    icon: Icons.local_fire_department,
                    color: fire > 0 ? Colors.red : Colors.grey,
                  ),
                ),
                SizedBox(
                  width: _cardWidth(context),
                  child: StatusCard(
                    title: "Humo",
                    value: "$smoke",
                    icon: Icons.smoke_free,
                    color: smoke > 0 ? Colors.orange : Colors.grey,
                  ),
                ),
                SizedBox(
                  width: _cardWidth(context),
                  child: StatusCard(
                    title: "Personas",
                    value: "$persons",
                    icon: Icons.person,
                    color: persons > 0 ? Colors.green : Colors.grey,
                  ),
                ),
                SizedBox(
                  width: _cardWidth(context),
                  child: StatusCard(
                    title: "Vasijas",
                    value: "$pots",
                    icon: Icons.kitchen,
                    color: pots > 0 ? Colors.amber : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _cardWidth(BuildContext context) {
    final w = MediaQuery.of(context).size.width - 32;
    return (w - 8) / 2;
  }
}
