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

  Future<void> _timerStart() async {
    final server = context.read<ServerProvider>();
    final minCtrl = TextEditingController(text: "30");
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Iniciar plazo de monitoreo"),
        content: TextField(
          controller: minCtrl,
          decoration: const InputDecoration(labelText: "Minutos de monitoreo", border: OutlineInputBorder()),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          ElevatedButton(onPressed: () {
            final v = int.tryParse(minCtrl.text) ?? 30;
            Navigator.pop(ctx, v);
          }, child: const Text("Iniciar")),
        ],
      ),
    );
    if (result != null && result > 0) {
      await server.apiService.timerStart(result);
    }
  }

  Future<void> _timerStop() async {
    final server = context.read<ServerProvider>();
    await server.apiService.timerStop();
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

    final timerData = _status["timer"] as Map<String, dynamic>?;
    final timerRunning = timerData?["running"] == true;
    final timerRemaining = timerData?["remaining"] ?? 0;
    final timerPaused = timerData?["paused"] == true;
    final sistemaActivo = _status["active"] == true;

    return Scaffold(
      appBar: AppBar(title: const Text("Cámara en vivo")),
      body: Column(
        children: [
          // System active/inactive banner
          if (server.status == ConnectionStatus.connected)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: sistemaActivo ? Colors.green.shade900 : Colors.red.shade900,
              child: Row(
                children: [
                  Icon(
                    sistemaActivo ? Icons.verified_user : Icons.block,
                    color: sistemaActivo ? Colors.greenAccent : Colors.redAccent,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    sistemaActivo
                        ? "SISTEMA ACTIVO - monitoreando"
                        : "SISTEMA INACTIVO - inicie el plazo de monitoreo",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

          // Timer bar
          if (server.status == ConnectionStatus.connected)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: timerRunning
                  ? (timerPaused ? Colors.orange.shade900 : Colors.green.shade900)
                  : Colors.grey.shade900,
              child: Row(
                children: [
                  Icon(
                    timerRunning ? Icons.timer : Icons.timer_off,
                    color: timerRunning ? Colors.orange : Colors.grey,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    timerRunning
                        ? "Plazo: ${_formatTimer(timerRemaining)}${timerPaused ? ' (PAUSADO)' : ''}"
                        : "Plazo: OFF",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const Spacer(),
                  if (!timerRunning)
                    SizedBox(
                      height: 28,
                      child: ElevatedButton.icon(
                        onPressed: _timerStart,
                        icon: const Icon(Icons.play_arrow, size: 16),
                        label: const Text("Iniciar", style: TextStyle(fontSize: 11)),
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                      ),
                    ),
                  if (timerRunning && !timerPaused)
                    SizedBox(
                      height: 28,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await context.read<ServerProvider>().apiService.timerPause();
                        },
                        icon: const Icon(Icons.pause, size: 16),
                        label: const Text("Pausa", style: TextStyle(fontSize: 11)),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          backgroundColor: Colors.orange.shade700,
                        ),
                      ),
                    ),
                  if (timerRunning && timerPaused)
                    SizedBox(
                      height: 28,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await context.read<ServerProvider>().apiService.timerResume();
                        },
                        icon: const Icon(Icons.play_arrow, size: 16),
                        label: const Text("Reanudar", style: TextStyle(fontSize: 11)),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          backgroundColor: Colors.green.shade700,
                        ),
                      ),
                    ),
                  if (timerRunning)
                    const SizedBox(width: 4),
                  if (timerRunning)
                    SizedBox(
                      height: 28,
                      child: ElevatedButton.icon(
                        onPressed: _timerStop,
                        icon: const Icon(Icons.stop, size: 16),
                        label: const Text("Parar", style: TextStyle(fontSize: 11)),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          backgroundColor: Colors.red.shade700,
                        ),
                      ),
                    ),
                ],
              ),
            ),

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

  String _formatTimer(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  double _cardWidth(BuildContext context) {
    final w = MediaQuery.of(context).size.width - 32;
    return (w - 8) / 2;
  }
}
