import 'package:flutter/material.dart';
import '../content/content.dart';
import '../services/settings_service.dart';

/// Pantalla de bienvenida (primer uso). Muestra información general de la app,
/// el manual para conectar la cámara (del móvil o IP), la guía de colocación y
/// la información de privacidad. Se muestra solo la primera vez.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int _page = 0;
  int _total = 1;

  Future<void> _finish() async {
    final settings = SettingsService();
    await settings.setHasSeenOnboarding(true);
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/main');
    }
  }

  void _next() {
    if (_page >= _total - 1) {
      _finish();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppLocal.language;
    final pages = _buildPages(lang);
    _total = pages.length;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1E1410), Color(0xFF120D0B)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _finish,
                  child: Text(
                    lang == "en" ? "Skip" : "Saltar",
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _controller,
                  onPageChanged: (i) => setState(() => _page = i),
                  children: pages,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(pages.length, (i) {
                        final active = i == _page;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 8,
                          width: active ? 22 : 8,
                          decoration: BoxDecoration(
                            color: active
                                ? Theme.of(context).colorScheme.primary
                                : Colors.white24,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _next,
                        icon: Icon(_page >= pages.length - 1
                            ? Icons.check
                            : Icons.arrow_forward),
                        label: Text(
                          _page >= pages.length - 1
                              ? (lang == "en"
                                  ? "I understand, let's get started"
                                  : "Entendido, comenzar")
                              : (lang == "en" ? "Next" : "Siguiente"),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildPages(String lang) {
    return [
      _WelcomePage(lang: lang),
      _StepsPage(
        icon: Icons.smartphone,
        title: lang == "en"
            ? "How to start monitoring"
            : "Cómo comenzar el monitoreo",
        steps: lang == "en"
            ? const [
                "Place your phone",
                "Point the rear camera toward the stove without blocking it.",
                "Start monitoring",
                "Choose how long to monitor and configure absence alerts.",
                "Stay nearby",
                "The app helps you detect unattended time, but it does not replace supervision.",
              ]
            : const [
                "Coloca el teléfono",
                "Apunta la cámara trasera hacia la estufa sin obstruirla.",
                "Inicia el monitoreo",
                "Elige cuánto tiempo vigilar y configura las alertas por ausencia.",
                "Mantente cerca",
                "La app ayuda a detectar una ausencia, pero no sustituye la supervisión.",
              ],
      ),
      _StepsPage(
        icon: Icons.notifications_active,
        title: lang == "en"
            ? "Receive alerts on time"
            : "Recibe las alertas a tiempo",
        steps: lang == "en"
            ? const [
                "Allow notifications",
                "The app requests permission to show alarms and sounds.",
                "Configure intervals",
                "Choose when CocinaP should remind you if no person is detected.",
              ]
            : const [
                "Permite las notificaciones",
                "La app solicita permiso para mostrar alarmas y sonidos.",
                "Configura los intervalos",
                "Elige cuándo CocinaP debe avisarte si no detecta una persona.",
              ],
      ),
      _InterfacePage(lang: lang),
      _PrivacyPage(lang: lang),
    ];
  }
}

/// Página que presenta la interfaz (pestañas) de forma gráfica.
class _InterfacePage extends StatelessWidget {
  final String lang;
  const _InterfacePage({required this.lang});

  static const List<IconData> _icons = [
    Icons.home,
    Icons.phone_android,
    Icons.tune,
  ];

  List<String> get _desc {
    if (lang == "en") {
      return [
        "Overview: monitoring status and how CocinaP works",
        "Watch your kitchen and receive absence alerts",
        "Duration, sensitivity, language, intervals and more",
      ];
    }
    return [
      "Resumen: estado del monitoreo y cómo funciona CocinaP",
      "Vigila tu cocina y recibe alertas por ausencia",
      "Duración, sensibilidad, idioma, intervalos y más",
    ];
  }

  List<String> get _tabs => [
        NavLabels.home(lang),
        NavLabels.monitoring(lang),
        NavLabels.settings(lang),
      ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tabs = _tabs;
    final desc = _desc;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      children: [
        const SizedBox(height: 8),
        Icon(Icons.dashboard_customize, size: 48, color: scheme.primary),
        const SizedBox(height: 12),
        Text(
          lang == "en" ? "How to use the app" : "Cómo usar la app",
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          lang == "en"
              ? "The app is organized in three tabs at the bottom. Here is what each one does:"
              : "La app se organiza en tres pestañas en la parte inferior. Esto hace cada una:",
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, height: 1.4, color: Colors.white70),
        ),
        const SizedBox(height: 20),
        for (var i = 0; i < tabs.length; i++) ...[
          _TabPreview(
            icon: _icons[i],
            label: tabs[i],
            desc: desc[i],
            index: i,
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.school, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  lang == "en"
                      ? "After this introduction, the first-use tour will highlight the main tabs."
                      : "Después de esta introducción, el tour inicial resaltará las pestañas principales.",
                  style: const TextStyle(fontSize: 12.5, color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TabPreview extends StatelessWidget {
  final IconData icon;
  final String label;
  final String desc;
  final int index;
  const _TabPreview({
    required this.icon,
    required this.label,
    required this.desc,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: scheme.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scheme.primary.withValues(alpha: 0.2),
                      ),
                      child: Text(
                        "${index + 1}",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  final String lang;
  const _WelcomePage({required this.lang});

  static const _icons = [
    Icons.phone_android,
    Icons.memory,
    Icons.notifications_active,
    Icons.wifi,
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final points = GeneralInfo.pointTexts(lang);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      children: [
        const SizedBox(height: 8),
        Icon(Icons.kitchen, size: 64, color: scheme.primary),
        const SizedBox(height: 12),
        Text(
          GeneralInfo.title(lang),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          GeneralInfo.subtitle(lang),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.orange.shade200),
        ),
        const SizedBox(height: 16),
        Text(
          GeneralInfo.intro(lang),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, height: 1.45, color: Colors.white70),
        ),
        const SizedBox(height: 20),
        for (var i = 0; i < points.length; i += 2) ...[
          _PointCard(
            icon: _icons[(i ~/ 2) % _icons.length],
            title: points[i],
            body: i + 1 < points.length ? points[i + 1] : "",
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _PointCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _PointCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: scheme.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepsPage extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> steps;
  const _StepsPage({
    required this.icon,
    required this.title,
    required this.steps,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      children: [
        const SizedBox(height: 8),
        Icon(icon, size: 48, color: scheme.primary),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        for (var i = 0; i < steps.length; i += 2) ...[
          _StepTile(
            number: (i ~/ 2) + 1,
            title: steps[i],
            body: i + 1 < steps.length ? steps[i + 1] : null,
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _StepTile extends StatelessWidget {
  final int number;
  final String title;
  final String? body;
  const _StepTile({required this.number, required this.title, this.body});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: scheme.primary,
            child: Text(
              "$number",
              style: TextStyle(
                color: scheme.onPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (body != null && body!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    body!,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyPage extends StatelessWidget {
  final String lang;
  const _PrivacyPage({required this.lang});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texts = PrivacyInfo.texts(lang);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      children: [
        const SizedBox(height: 8),
        Icon(Icons.lock_outline, size: 48, color: scheme.primary),
        const SizedBox(height: 12),
        Text(
          lang == "en" ? "Privacy and permissions" : "Privacidad y permisos",
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        for (var i = 0; i < texts.length; i += 2) ...[
          Text(
            texts[i],
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          if (i + 1 < texts.length)
            Text(
              texts[i + 1],
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: Colors.white70,
              ),
            ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}
