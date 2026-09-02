import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/api_service.dart';
import 'services/discovery_service.dart';
import 'services/settings_service.dart';
import 'services/background_service.dart';
import 'providers/server_provider.dart';
import 'providers/alarms_provider.dart';
import 'providers/config_provider.dart';
import 'providers/standalone_provider.dart';
import 'pages/discovery_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/alarms_page.dart';
import 'pages/settings_page.dart';
import 'pages/standalone_page.dart';
import 'pages/camera_install_guide_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final api = ApiService("");
  final discovery = DiscoveryService();
  final settings = SettingsService();
  final standalone = StandaloneProvider();

  try {
    await BackgroundServiceManager.init();
  } catch (_) {}

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ServerProvider(api, discovery, settings)),
        ChangeNotifierProvider(create: (_) => AlarmsProvider(api)),
        ChangeNotifierProvider(create: (_) => ConfigProvider(api)),
        ChangeNotifierProvider(create: (_) => standalone),
        Provider.value(value: settings),
        Provider.value(value: api),
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
    return MaterialApp(
      title: "CocinaP",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.orange,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      routes: {
        '/main': (context) => const MainShell(),
      },
      home: _showInstallGuide == null
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : (_showInstallGuide! ? const CameraInstallGuidePage() : const MainShell()),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  bool _wasConnected = false;

  final _pages = const [
    StandalonePage(),
    DiscoveryPage(),
    DashboardPage(),
    AlarmsPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final server = context.watch<ServerProvider>();
    final standalone = context.watch<StandaloneProvider>();
    final isConnected = server.status == ConnectionStatus.connected;

    // When connection succeeds, jump to camera.
    if (isConnected && !_wasConnected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && isConnected && _currentIndex == 1) {
          setState(() => _currentIndex = 2);
        }
      });
    }
    _wasConnected = isConnected;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.phone_android, color: standalone.timerRunning ? Colors.orange : null),
            label: "Monitoreo",
          ),
          const NavigationDestination(
            icon: Icon(Icons.search),
            label: "Conectar",
          ),
          NavigationDestination(
            icon: Icon(Icons.videocam, color: isConnected ? Colors.green : null),
            label: "Cámara",
          ),
          NavigationDestination(
            icon: Icon(Icons.warning_amber, color: isConnected ? Colors.orange : null),
            label: "Alarmas",
          ),
          const NavigationDestination(
            icon: Icon(Icons.tune),
            label: "Ajustes",
          ),
        ],
      ),
    );
  }
}
