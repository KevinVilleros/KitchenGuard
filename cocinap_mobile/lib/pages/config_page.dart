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

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: entries.length + 1,
            itemBuilder: (context, index) {
              if (index == entries.length) {
                return Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: ElevatedButton(
                    onPressed: () => _save(config),
                    child: const Text("Guardar cambios"),
                  ),
                );
              }

              final entry = entries[index];
              final key = entry.key;
              final value = entry.value;

              if (value is num) {
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
              }

              return ListTile(
                dense: true,
                title: Text(key, style: const TextStyle(fontSize: 13)),
                subtitle: Text("$value", style: const TextStyle(fontSize: 12)),
              );
            },
          );
        },
      ),
    );
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
