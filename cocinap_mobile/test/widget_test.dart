import 'package:cocinap_mobile/main.dart';
import 'package:cocinap_mobile/providers/standalone_provider.dart';
import 'package:cocinap_mobile/providers/tour_controller.dart';
import 'package:cocinap_mobile/services/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App loads without crash', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => StandaloneProvider()),
          ChangeNotifierProvider(create: (_) => TourController()),
          Provider.value(value: settings),
        ],
        child: const CocinaPApp(),
      ),
    );
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
