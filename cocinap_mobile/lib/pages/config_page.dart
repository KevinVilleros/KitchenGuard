import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/config_provider.dart';
import '../providers/server_provider.dart';

class ConfigPage extends StatefulWidget {
  const ConfigPage({super.key});

  @override
  State<ConfigPage> createState() => _ConfigPageState();
}

class _ConfigPageState extends State<ConfigPage> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, dynamic> _originalValues = {};

  @override
  void initState() {
    super.initState();
    final server = context.read<ServerProvider>();
    if (server.status == ConnectionStatus.connected) {
      context.read<ConfigProvider>().loadConfig();
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Configuración")),
      body: Consumer2<ConfigProvider, ServerProvider>(
        builder: (context, config, server, _) {
          if (server.status != ConnectionStatus.connected) {
            return const Center(child: Text("Sin conexión al servidor"));
          }

          if (config.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          final entries = config.config.entries.toList();
          _syncControllers(config.config);

          // Extract alarm config
          final alarmUnattended = config.config["ALARM_UNATTENDED_ENABLED"] ?? true;
          final alarmSmoke = config.config["ALARM_SMOKE_ENABLED"] ?? true;
          final alarmFire = config.config["ALARM_FIRE_ENABLED"] ?? true;
          final timerDuration = config.config["KITCHEN_TIMER_DURATION"] ?? 30;
          final timerAlert = config.config["KITCHEN_TIMER_ALERT_SECONDS"] ?? 60;

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // Alarm configuration section
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.notifications_active, color: Colors.orange, size: 20),
                        SizedBox(width: 8),
                        Text("Alarmas", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(),
                    CheckboxListTile(
                      title: const Text("Principal: Cocina desatendida", style: TextStyle(fontSize: 14)),
                      subtitle: const Text("Alarma cuando no hay nadie en la cocina", style: TextStyle(fontSize: 11)),
                      value: alarmUnattended == true,
                      onChanged: (v) => _saveAlarmConfig("ALARM_UNATTENDED_ENABLED", v ?? true),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    CheckboxListTile(
                      title: const Text("Alarma de humo", style: TextStyle(fontSize: 14)),
                      value: alarmSmoke == true,
                      onChanged: (v) => _saveAlarmConfig("ALARM_SMOKE_ENABLED", v ?? true),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    CheckboxListTile(
                      title: const Text("Alarma de fuego", style: TextStyle(fontSize: 14)),
                      value: alarmFire == true,
                      onChanged: (v) => _saveAlarmConfig("ALARM_FIRE_ENABLED", v ?? true),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Timer config
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.timer, color: Colors.green, size: 20),
                        SizedBox(width: 8),
                        Text("Plazo de monitoreo", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(),
                    TextField(
                      controller: _controllers["KITCHEN_TIMER_DURATION"] ?? TextEditingController(text: "$timerDuration"),
                      decoration: const InputDecoration(
                        labelText: "Duración por defecto (minutos)",
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _controllers["KITCHEN_TIMER_ALERT_SECONDS"] ?? TextEditingController(text: "$timerAlert"),
                      decoration: const InputDecoration(
                        labelText: "Alerta sin persona (segundos)",
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Other numeric configs
              ...List.generate(entries.length, (index) {
                final entry = entries[index];
                final key = entry.key;

                // Skip alarm/timer keys shown above
                if (key == "ALARM_UNATTENDED_ENABLED" || key == "ALARM_SMOKE_ENABLED" ||
                    key == "ALARM_FIRE_ENABLED" || key == "KITCHEN_TIMER_DURATION" ||
                    key == "KITCHEN_TIMER_ALERT_SECONDS") {
                  return const SizedBox.shrink();
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                    controller: _controllers[key],
                    decoration: InputDecoration(
                      labelText: key,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                );
              }),

              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _save(config),
                child: const Text("Guardar cambios"),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _saveAlarmConfig(String key, dynamic value) async {
    final server = context.read<ServerProvider>();
    // Update locally first
    setState(() {});
    // Send to server
    await server.apiService.updateConfig({key: value});
    // Reload config
    if (mounted) {
      context.read<ConfigProvider>().loadConfig();
    }
  }

  void _syncControllers(Map<String, dynamic> config) {
    for (final entry in config.entries) {
      if (entry.value is num) {
        final key = entry.key;
        final valStr = entry.value.toString();
        _originalValues.putIfAbsent(key, () => entry.value);
        if (!_controllers.containsKey(key)) {
          _controllers[key] = TextEditingController(text: valStr);
        }
      }
    }
  }

  Future<void> _save(ConfigProvider config) async {
    final updates = <String, dynamic>{};
    for (final entry in _controllers.entries) {
      final key = entry.key;
      final val = entry.value.text.trim();
      final orig = _originalValues[key];
      if (orig is int) {
        updates[key] = int.tryParse(val) ?? orig;
      } else {
        updates[key] = double.tryParse(val) ?? orig;
      }
    }

    final ok = await config.updateConfig(updates);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? "Configuración guardada" : "Error al guardar")),
      );
    }
  }
}
