import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../content/content.dart';
import '../providers/standalone_provider.dart';
import '../providers/tour_controller.dart';
import '../widgets/graphical.dart';

/// Pantalla de inicio: dashboard gráfico con el estado del monitoreo,
/// estadísticas, los objetivos de la app, cómo funciona y su información.
class HomePage extends StatelessWidget {
  /// Permite saltar a otra pestaña de la barra inferior.
  final void Function(int index) onOpenTab;
  const HomePage({super.key, required this.onOpenTab});

  static const List<IconData> _objectiveIcons = [
    Icons.local_fire_department,
    Icons.notifications_active,
    Icons.lock,
    Icons.touch_app,
  ];

  static const List<Color> _objectiveColors = [
    Colors.deepOrange,
    Colors.amber,
    Colors.teal,
    Colors.lightBlue,
  ];

  @override
  Widget build(BuildContext context) {
    final lang = AppLocal.language;
    final standalone = context.watch<StandaloneProvider>();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _header(context, lang, standalone),
            const SizedBox(height: 16),
            _hero(context, lang, standalone),
            const SizedBox(height: 16),
            _stats(standalone),
            const SizedBox(height: 22),
            SectionTitle(icon: Icons.flag, text: HomeTexts.objectivesTitle(lang)),
            const SizedBox(height: 12),
            _objectives(lang),
            const SizedBox(height: 22),
            SectionTitle(icon: Icons.insights, text: HomeTexts.howTitle(lang)),
            const SizedBox(height: 12),
            _howItWorks(lang),
            const SizedBox(height: 22),
            _setup(context, lang, standalone),
            const SizedBox(height: 22),
            _privacy(context, lang),
            const SizedBox(height: 14),
            _about(context, lang),
            const SizedBox(height: 20),
            _actions(context, lang, standalone),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, String lang, StandaloneProvider s) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: [scheme.primary, scheme.primary.withValues(alpha: 0.6)],
            ),
          ),
          child: const Icon(Icons.kitchen, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "CocinaP",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              Text(
                HomeTexts.taglineOf(lang),
                style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.7)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _hero(BuildContext context, String lang, StandaloneProvider s) {
    final running = s.timerRunning;
    final person = s.personPresent;
    final color = person
        ? Colors.green
        : (running ? Colors.orange : Theme.of(context).colorScheme.primary);

    final double value;
    if (running) {
      value = s.durationMinutes > 0
          ? (s.remainingSeconds / (s.durationMinutes * 60)).clamp(0.0, 1.0)
          : 0.0;
    } else {
      value = 1.0;
    }

    final String centerMain = running ? s.remainingLabel : "OK";
    final String centerSub = running
        ? HomeTexts.statRemaining(lang)
        : HomeTexts.active(lang);

    final statusLine = !running
        ? HomeTexts.ready(lang)
        : (person ? HomeTexts.monitoring(lang) : HomeTexts.personAway(lang));

    return GradientCard(
      accent: color,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          RingProgress(
            value: value,
            color: color,
            size: 108,
            stroke: 10,
            center: Padding(
              padding: const EdgeInsets.all(18),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      !running
                          ? Icons.verified_user
                          : (person ? Icons.person : Icons.person_off),
                      color: color,
                      size: 22,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      centerMain,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      centerSub,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 10, color: Colors.white60),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  HomeTexts.statusTitle(lang),
                  style: const TextStyle(fontSize: 13, color: Colors.white60),
                ),
                const SizedBox(height: 4),
                Text(
                  statusLine,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _pill(
                      running ? HomeTexts.active(lang) : HomeTexts.inactive(lang),
                      running ? Colors.orange : Colors.grey,
                    ),
                    _pill(
                      person ? HomeTexts.yes(lang) : HomeTexts.no(lang),
                      person ? Colors.green : Colors.redAccent,
                      icon: Icons.person,
                    ),
                    _pill(
                      s.cameraActive ? HomeTexts.active(lang) : HomeTexts.inactive(lang),
                      s.cameraActive ? Colors.green : Colors.grey,
                      icon: Icons.videocam,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String text, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _stats(StandaloneProvider s) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: IconStatTile(
                icon: Icons.timer,
                value: s.timerRunning ? s.remainingLabel : "${s.durationMinutes} min",
                label: s.timerRunning
                    ? HomeTexts.statRemaining(AppLocal.language)
                    : HomeTexts.statTimer(AppLocal.language),
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: IconStatTile(
                icon: s.personPresent ? Icons.person : Icons.person_off,
                value: s.personPresent
                    ? HomeTexts.yes(AppLocal.language)
                    : HomeTexts.no(AppLocal.language),
                label: HomeTexts.statPerson(AppLocal.language),
                color: s.personPresent ? Colors.green : Colors.redAccent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: IconStatTile(
                icon: Icons.videocam,
                value: s.cameraActive
                    ? HomeTexts.active(AppLocal.language)
                    : HomeTexts.inactive(AppLocal.language),
                label: HomeTexts.statCamera(AppLocal.language),
                color: s.cameraActive ? Colors.teal : Colors.grey,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _objectives(String lang) {
    final texts = AppObjectives.texts(lang);
    final children = <Widget>[];
    for (var i = 0; i < texts.length; i += 2) {
      children.add(GoalTile(
        icon: _objectiveIcons[(i ~/ 2) % _objectiveIcons.length],
        title: texts[i],
        body: i + 1 < texts.length ? texts[i + 1] : "",
        color: _objectiveColors[(i ~/ 2) % _objectiveColors.length],
      ));
    }
    return Column(children: children);
  }

  Widget _howItWorks(String lang) {
    final texts = AppHowItWorks.texts(lang);
    const icons = [Icons.person_search, Icons.timer, Icons.notifications_active];
    final items = <StepItem>[];
    for (var i = 0; i < texts.length; i += 2) {
      items.add(StepItem(
        icons[(i ~/ 2) % icons.length],
        texts[i],
        i + 1 < texts.length ? texts[i + 1] : "",
      ));
    }
    return GradientCard(
      accent: Colors.orange,
      child: StepTimeline(items: items),
    );
  }

  Widget _setup(BuildContext context, String lang, StandaloneProvider s) {
    final cameraDone = s.cameraSource == StandaloneCameraSource.phone ||
        s.cameraUrl.isNotEmpty;
    final rows = <Widget>[
      ChecklistRow(
        icon: Icons.videocam,
        label: cameraDone
            ? HomeTexts.setupCameraDone(lang)
            : HomeTexts.setupCameraPending(lang),
        done: cameraDone,
      ),
      ChecklistRow(
        icon: Icons.notifications_active,
        label: HomeTexts.setupHints(lang),
        done: true,
      ),
      ChecklistRow(
        icon: Icons.language,
        label: HomeTexts.setupLanguage(lang),
        done: true,
      ),
    ];
    final done = rows.where((r) => (r as ChecklistRow).done).length;
    final progress = rows.isEmpty ? 0.0 : done / rows.length;

    return GradientCard(
      accent: Colors.teal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SectionTitle(
                  icon: Icons.tune,
                  text: HomeTexts.setupTitle(lang),
                  accent: Colors.teal,
                ),
              ),
              RingProgress(
                value: progress,
                color: Colors.teal,
                size: 46,
                stroke: 5,
                center: Text(
                  "${(progress * 100).round()}%",
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...rows,
        ],
      ),
    );
  }

  Widget _privacy(BuildContext context, String lang) {
    return GradientCard(
      accent: Colors.indigo,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.indigo.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.shield_moon, color: Colors.lightBlueAccent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  HomeTexts.privacyTitle(lang),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppInfo.privacyValue(lang),
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _pill(lang == "en" ? "No uploads" : "Sin subidas", Colors.lightBlueAccent),
                    _pill(lang == "en" ? "On-device AI" : "IA local", Colors.lightBlueAccent),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _about(BuildContext context, String lang) {
    final rows = <MapEntry<String, String>>[
      MapEntry(AppInfo.versionLabel(lang), "1.0.0"),
      MapEntry(AppInfo.techLabel(lang), "Flutter · Dart"),
      MapEntry(AppInfo.modelLabel(lang), "ML Kit Pose Detection"),
      MapEntry(AppInfo.privacyLabel(lang), AppInfo.privacyValue(lang)),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1714),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(icon: Icons.info_outline, text: HomeTexts.aboutTitle(lang), accent: Colors.white70),
          const SizedBox(height: 12),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      row.key,
                      style: const TextStyle(fontSize: 13, color: Colors.white60),
                    ),
                  ),
                  Text(
                    row.value,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _actions(
    BuildContext context,
    String lang,
    StandaloneProvider s,
  ) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => onOpenTab(1),
            icon: const Icon(Icons.play_circle_outline),
            label: Text(
              s.timerRunning
                  ? HomeTexts.btnOpenMonitoring(lang)
                  : HomeTexts.btnStart(lang),
            ),
          ),
        ),
        const SizedBox(height: 6),
        TextButton.icon(
          onPressed: () => context.read<TourController>().start(),
          icon: const Icon(Icons.school_outlined, size: 18),
          label: Text(HomeTexts.replayTour(lang)),
        ),
      ],
    );
  }
}
