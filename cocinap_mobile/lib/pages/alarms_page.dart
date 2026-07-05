import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/alarms_provider.dart';
import '../providers/server_provider.dart';

class AlarmsPage extends StatefulWidget {
  const AlarmsPage({super.key});

  @override
  State<AlarmsPage> createState() => _AlarmsPageState();
}

class _AlarmsPageState extends State<AlarmsPage> {
  @override
  void initState() {
    super.initState();
    final server = context.read<ServerProvider>();
    if (server.status == ConnectionStatus.connected) {
      context.read<AlarmsProvider>().connect();
    }
  }

  @override
  void dispose() {
    context.read<AlarmsProvider>().disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Alarmas")),
      body: Consumer2<AlarmsProvider, ServerProvider>(
        builder: (context, alarms, server, _) {
          if (server.status != ConnectionStatus.connected) {
            return const Center(
              child: Text("Conéctate a un servidor para ver alarmas"),
            );
          }

          if (!alarms.connected) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("Conectando al stream de eventos..."),
                ],
              ),
            );
          }

          if (alarms.alarms.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 64, color: Colors.green),
                  SizedBox(height: 16),
                  Text("Sin alarmas activas", style: TextStyle(fontSize: 16)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: alarms.alarms.length,
            itemBuilder: (context, index) {
              final alarm = alarms.alarms[index];
              return _buildAlarmCard(alarm);
            },
          );
        },
      ),
    );
  }

  Widget _buildAlarmCard(Map<String, dynamic> alarm) {
    final type = alarm["type"] as String? ?? "unknown";
    final time = alarm["time"] as String? ?? "";
    final data = alarm["data"] as Map<String, dynamic>? ?? {};

    IconData icon;
    Color color;
    switch (type) {
      case "fire":
        icon = Icons.local_fire_department;
        color = Colors.red;
        break;
      case "smoke":
        icon = Icons.smoke_free;
        color = Colors.orange;
        break;
      case "unattended":
        icon = Icons.person_off;
        color = Colors.yellow;
        break;
      default:
        icon = Icons.warning;
        color = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: color.withValues(alpha: 0.1),
      child: ListTile(
        leading: Icon(icon, color: color, size: 32),
        title: Text(type.toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        subtitle: Text(time.isNotEmpty ? time : "Ahora"),
        trailing: data.isNotEmpty
            ? Text("${data.length} items")
            : null,
      ),
    );
  }
}
