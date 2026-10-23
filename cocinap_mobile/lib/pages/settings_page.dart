import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/standalone_provider.dart';
import '../providers/tour_controller.dart';
import '../services/settings_service.dart';
import '../services/background_service.dart';
import '../content/content.dart';
import 'help_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  void initState() {
    super.initState();
    _loadStandalone();
  }

  Future<void> _loadStandalone() async {
    final standalone = context.read<StandaloneProvider>();
    final settings = context.read<SettingsService>();
    standalone.setDurationMinutes(await settings.getStandaloneDuration());
    standalone.setNoPersonAlertSeconds(await settings.getStandaloneNoPersonSeconds());
    standalone.setDangerMinutes(await settings.getStandaloneDangerMinutes());
    standalone.setConfidence(await settings.getStandaloneConfidence());

    final src = await settings.getStandaloneSource();
    standalone.setCameraSource(src == 'ip'
        ? StandaloneCameraSource.ipCamera
        : StandaloneCameraSource.phone);
    standalone.setCameraUrl(await settings.getStandaloneCameraUrl());

    standalone.setAlertIntervals(await settings.getAlertIntervals());
    standalone.setIntervalAlertsEnabled(await settings.getIntervalAlertsEnabled());
    final repeat = await settings.getAlertRepeatMode();
    standalone.setRepeatMode(repeat == 'oncePerInterval'
        ? AlertRepeatMode.oncePerInterval
        : AlertRepeatMode.repeatLast);
  }

  /// Edita la lista de intervalos de alerta (minutos sin persona).
  Future<void> _editIntervals(BuildContext context) async {
    final lang = AppLocal.language;
    String l(String es, String en) => lang == "en" ? en : es;
    final standalone = context.read<StandaloneProvider>();
    final settings = context.read<SettingsService>();
    final controller = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final intervals = standalone.sortedIntervals;
          return AlertDialog(
            title: Text(l("Intervalos de alerta", "Alert intervals")),
            content: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l("Avisa cuando la cocina lleva estos minutos sin persona. Ejemplo: 10, 15 y 20 min.",
                      "Alert when kitchen has been without person for these minutes. Example: 10, 15, 20 min."),
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: l("Minutos (ej. 25)", "Minutes (e.g. 25)"),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        icon: const Icon(Icons.add),
                        onPressed: () {
                          final m = int.tryParse(controller.text);
                          if (m == null || m < 1 || m > 240) return;
                          final next = [...intervals, m];
                          standalone.setAlertIntervals(next);
                          controller.clear();
                          setLocal(() {});
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (intervals.isEmpty)
                    Text(l("Sin intervalos", "No intervals"),
                        style: const TextStyle(color: Colors.grey, fontSize: 13))
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: intervals
                          .map(
                            (m) => InputChip(
                              label: Text("$m min"),
                              onDeleted: () {
                                final next =
                                    intervals.where((x) => x != m).toList();
                                standalone.setAlertIntervals(next);
                                setLocal(() {});
                              },
                            ),
                          )
                          .toList(),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l("Cerrar", "Close")),
              ),
            ],
          );
        },
      ),
    );

    await settings.setAlertIntervals(standalone.alertIntervals);
  }

  Future<void> _pickLanguage(BuildContext context) async {
    final current = AppLocal.language;
    final settings = context.read<SettingsService>();
    final sel = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text("Idioma / Language"),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, "es"),
            child: const Text("Español"),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, "en"),
            child: const Text("English"),
          ),
        ],
      ),
    );
    if (sel != null && sel != current) {
      AppLocal.setLanguage(sel);
      await settings.setLanguage(sel);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppLocal.language;
    final standalone = context.watch<StandaloneProvider>();
    final settings = context.read<SettingsService>();

    String l(String es, String en) => lang == "en" ? en : es;

    return Scaffold(
      appBar: AppBar(title: Text(l("Ajustes", "Settings"))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text(
              "Monitoreo",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),

          // Fuente de cámara
          ListTile(
            leading: const Icon(Icons.videocam),
            title: Text(l("Fuente de cámara", "Camera source")),
            subtitle: Text(standalone.cameraSourceLabel),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          const Divider(),

          // Duración del temporizador
          ListTile(
            title: Text(l("Duración del monitoreo (min)", "Monitoring duration (min)")),
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
            title: Text(l("Alertar si sin persona (seg)", "Alert if no person (sec)")),
            subtitle: Text(l("Tiempo sin detectar persona para disparar alerta", "Time without detecting person to trigger alert")),
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

          // Intervalos de alerta (cocina desatendida)
          SwitchListTile(
            title: Text(l("Alertas por intervalos", "Interval alerts")),
            subtitle: Text(l("Avisa a los 10, 15, 20 min... sin persona en la cocina", "Alert at 10, 15, 20 min... without person in kitchen")),
            value: standalone.intervalAlertsEnabled,
            onChanged: (v) {
              standalone.setIntervalAlertsEnabled(v);
              settings.setIntervalAlertsEnabled(v);
            },
          ),
          ListTile(
            leading: const Icon(Icons.schedule),
            title: Text(l("Intervalos configurados", "Configured intervals")),
            subtitle: Text(standalone.sortedIntervals.isEmpty
                ? l("Sin intervalos", "No intervals")
                : standalone.sortedIntervals
                    .map((m) => "$m min")
                    .join(", ")),
            trailing: const Icon(Icons.edit),
            onTap: () => _editIntervals(context),
          ),
          ListTile(
            leading: const Icon(Icons.repeat),
            title: Text(l("Repetición de la última alerta", "Repeat last alert")),
            subtitle: Text(standalone.repeatMode == AlertRepeatMode.repeatLast
                ? l("Repetir el último intervalo", "Repeat last interval")
                : l("Una sola vez por intervalo", "Once per interval")),
            trailing: Switch(
              value: standalone.repeatMode == AlertRepeatMode.repeatLast,
              onChanged: (v) {
                final mode = v
                    ? AlertRepeatMode.repeatLast
                    : AlertRepeatMode.oncePerInterval;
                standalone.setRepeatMode(mode);
                settings.setAlertRepeatMode(
                    v ? 'repeatLast' : 'oncePerInterval');
              },
            ),
          ),

          // Tiempo peligroso estimado
          ListTile(
            title: Text(l("Tiempo peligroso sin atender (min)", "Danger time unattended (min)")),
            subtitle: Text(l("Se considera riesgo alto después de este tiempo", "High risk after this time")),
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
                  l("Confianza detección persona: ", "Person detection confidence: ") + standalone.confidence.toStringAsFixed(2),
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
            leading: const Icon(Icons.notifications_active),
            title: Text(l("Notificaciones", "Notifications")),
            subtitle: Text(l("Avisos locales con sonido y vibración", "Local alerts with sound and vibration")),
            trailing: FilledButton.tonalIcon(
              onPressed: BackgroundServiceManager.sendTestAlarm,
              icon: const Icon(Icons.notifications_active_outlined, size: 18),
              label: Text(l("Probar", "Test")),
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text(
              "Detección",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.smartphone),
            title: Text(l("En el móvil (ML Kit)", "On-device (ML Kit)")),
            subtitle: Text(l("El modelo se ejecuta en el dispositivo, sin enviar imágenes", "Runs on device, no images sent")),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.translate),
            title: const Text("Idioma / Language"),
            subtitle: Text(AppLocal.language == "en" ? "English" : "Español"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickLanguage(context),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.school_outlined),
            title: Text(l("Tour de la interfaz", "Interface tour")),
            subtitle: Text(l("Repasa las pestañas y opciones principales", "Review tabs and main options")),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.read<TourController>().start(),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: Text(l("Manual de uso, guía y términos", "Manual, guide & terms")),
            subtitle: Text(l("Manual, guía de cámaras y términos", "Manual, camera guide & terms")),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HelpPage()),
            ),
          ),
        ],
      ),
    );
  }
}
