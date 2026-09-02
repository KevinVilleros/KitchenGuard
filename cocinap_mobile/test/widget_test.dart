import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:cocinap_mobile/main.dart';
import 'package:cocinap_mobile/services/api_service.dart';
import 'package:cocinap_mobile/services/discovery_service.dart';
import 'package:cocinap_mobile/services/settings_service.dart';
import 'package:cocinap_mobile/providers/server_provider.dart';
import 'package:cocinap_mobile/providers/alarms_provider.dart';
import 'package:cocinap_mobile/providers/config_provider.dart';

void main() {
  testWidgets('App loads without crash', (WidgetTester tester) async {
    final api = ApiService("");
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ServerProvider(api, DiscoveryService(), SettingsService())),
          ChangeNotifierProvider(create: (_) => AlarmsProvider(api)),
          ChangeNotifierProvider(create: (_) => ConfigProvider(api)),
          Provider.value(value: SettingsService()),
          Provider.value(value: api),
        ],
        child: const CocinaPApp(),
      ),
    );
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
