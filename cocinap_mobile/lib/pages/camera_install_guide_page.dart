import 'package:flutter/material.dart';
import '../content/content.dart';
import '../services/settings_service.dart';

/// Pantalla de primer uso: enseña a la persona cómo colocar físicamente su
/// cámara de seguridad para lograr un buen monitoreo de la cocina. Se muestra
/// solo la primera vez que se abre la app.
class CameraInstallGuidePage extends StatefulWidget {
  const CameraInstallGuidePage({super.key});

  @override
  State<CameraInstallGuidePage> createState() => _CameraInstallGuidePageState();
}

class _CameraInstallGuidePageState extends State<CameraInstallGuidePage> {
  static const _icons = [
    Icons.place,
    Icons.height,
    Icons.center_focus_strong,
    Icons.lightbulb,
    Icons.cleaning_services,
    Icons.smartphone,
  ];

  Future<void> _finish() async {
    final settings = SettingsService();
    await settings.setHasSeenInstallGuide(true);
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/main');
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppLocal.language;
    final steps = CameraInstallGuide.texts(lang);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const SizedBox(height: 8),
                  Icon(
                    Icons.videocam,
                    size: 56,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    CameraInstallGuide.title(lang),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    CameraInstallGuide.intro(lang),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  for (var i = 0; i < steps.length; i += 2) ...[
                    _StepTile(
                      number: (i ~/ 2) + 1,
                      icon: _icons[(i ~/ 2) % _icons.length],
                      title: steps[i],
                      body: i + 1 < steps.length ? steps[i + 1] : null,
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _finish,
                  icon: const Icon(Icons.check),
                  label: Text(
                    lang == "en"
                        ? "I understand, let's get started"
                        : "Entendido, comenzar",
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  final int number;
  final IconData icon;
  final String title;
  final String? body;
  const _StepTile({
    required this.number,
    required this.icon,
    required this.title,
    this.body,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: scheme.primary,
              child: Text(
                "$number",
                style: TextStyle(
                  color: scheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 18, color: scheme.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (body != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      body!,
                      style: const TextStyle(fontSize: 13, height: 1.4),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}