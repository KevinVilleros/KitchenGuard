import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/api_service.dart';
import 'services/discovery_service.dart';
import 'services/settings_service.dart';
import 'services/fcm_service.dart';
import 'services/background_service.dart';
import 'providers/server_provider.dart';
import 'providers/alarms_provider.dart';
import 'providers/config_provider.dart';
import 'pages/discovery_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/alarms_page.dart';
import 'pages/config_page.dart';
import 'pages/settings_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final api = ApiService("");
  final discovery = DiscoveryService();
  final settings = SettingsService();
  final fcm = FcmService();

  try {
    await Firebase.initializeApp();
    await fcm.init();
  } catch (_) {}

  try {
    await BackgroundServiceManager.init();
  } catch (_) {}

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ServerProvider(api, discovery, settings, fcm)),
        ChangeNotifierProvider(create: (_) => AlarmsProvider(api)),
        ChangeNotifierProvider(create: (_) => ConfigProvider(api)),
        Provider.value(value: settings),
        Provider.value(value: api),
      ],
      child: const CocinaPApp(),
    ),
  );
}

class CocinaPApp extends StatelessWidget {
  const CocinaPApp({super.key});

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
      home: const MainShell(),
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
    DiscoveryPage(),
    DashboardPage(),
    AlarmsPage(),
    ConfigPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final server = context.watch<ServerProvider>();
    final isConnected = server.status == ConnectionStatus.connected;

    // When connection succeeds while on the "Conectar" tab, jump to Camera.
    if (isConnected && !_wasConnected && _currentIndex == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && isConnected) {
          setState(() => _currentIndex = 1);
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
            icon: Icon(Icons.settings),
            label: "Config",
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
