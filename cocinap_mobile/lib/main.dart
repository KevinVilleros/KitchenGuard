import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/settings_service.dart';
import 'services/background_service.dart';
import 'providers/standalone_provider.dart';
import 'providers/tour_controller.dart';
import 'pages/settings_page.dart';
import 'pages/standalone_page.dart';
import 'pages/onboarding_page.dart';
import 'pages/home_page.dart';
import 'widgets/tour_overlay.dart';
import 'content/content.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settings = SettingsService();
  final standalone = StandaloneProvider();

  AppLocal.setLanguage(await settings.getLanguage());

  try {
    await BackgroundServiceManager.init();
  } catch (_) {}

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => standalone),
        ChangeNotifierProvider(create: (_) => TourController()),
        Provider.value(value: settings),
      ],
      child: const CocinaPApp(),
    ),
  );
}

class CocinaPApp extends StatefulWidget {
  const CocinaPApp({super.key});

  @override
  State<CocinaPApp> createState() => _CocinaPAppState();
}

class _CocinaPAppState extends State<CocinaPApp> {
  bool? _showInstallGuide;

  @override
  void initState() {
    super.initState();
    _loadInstallGuideFlag();
  }

  Future<void> _loadInstallGuideFlag() async {
    final settings = SettingsService();
    final seen = await settings.getHasSeenInstallGuide();
    if (!mounted) return;
    setState(() => _showInstallGuide = !seen);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: Colors.orange,
      brightness: Brightness.dark,
    );
    return MaterialApp(
      title: "CocinaP",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF120D0B),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E1714),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF1E1714),
          indicatorColor: scheme.primary.withValues(alpha: 0.22),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        ),
      ),
      routes: {
        '/main': (context) => const MainShell(),
      },
      home: _showInstallGuide == null
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : (_showInstallGuide! ? const OnboardingPage() : const MainShell()),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  static const int _destinationCount = 3;

  int _currentIndex = 0;
  final GlobalKey _navKey = GlobalKey();
  TourController? _tour;
  bool _tourWasActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final seen = await SettingsService().getHasSeenAppTour();
      if (!mounted || seen) return;
      context.read<TourController>().start();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tour = context.read<TourController>();
    if (_tour != tour) {
      _tour?.removeListener(_onTourChanged);
      _tour = tour;
      tour.addListener(_onTourChanged);
    }
  }

  void _onTourChanged() {
    final tour = _tour;
    if (tour == null || !mounted) return;
    if (tour.active) {
      final tab = tour.highlightedTab;
      if (tab != null && tab != _currentIndex) {
        setState(() => _currentIndex = tab);
      } else {
        setState(() {});
      }
    } else {
      setState(() {});
    }
    if (_tourWasActive && !tour.active) {
      SettingsService().setHasSeenAppTour(true);
    }
    _tourWasActive = tour.active;
  }

  @override
  void dispose() {
    _tour?.removeListener(_onTourChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tour = context.watch<TourController>();
    final standalone = context.watch<StandaloneProvider>();
    final lang = AppLocal.language;

    final pages = [
      HomePage(onOpenTab: (i) => setState(() => _currentIndex = i)),
      const StandalonePage(),
      const SettingsPage(),
    ];

    return Stack(
      children: [
        Scaffold(
          body: IndexedStack(index: _currentIndex, children: pages),
          bottomNavigationBar: NavigationBar(
            key: _navKey,
            height: 62,
            labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
            selectedIndex: _currentIndex,
            onDestinationSelected: (i) => setState(() => _currentIndex = i),
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home),
                label: NavLabels.home(lang),
              ),
              NavigationDestination(
                icon: Icon(Icons.phone_android,
                    color: standalone.timerRunning ? Colors.orange : null),
                label: NavLabels.monitoring(lang),
              ),
              NavigationDestination(
                icon: const Icon(Icons.tune),
                label: NavLabels.settings(lang),
              ),
            ],
          ),
        ),
        if (tour.active)
          TourOverlay(
            tour: tour,
            navKey: _navKey,
            destinationCount: _destinationCount,
            lang: lang,
          ),
      ],
    );
  }
}
