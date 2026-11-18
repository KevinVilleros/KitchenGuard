import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cocinap_mobile/content/content.dart';
import 'package:cocinap_mobile/providers/tour_controller.dart';
import 'package:cocinap_mobile/providers/standalone_provider.dart';
import 'package:cocinap_mobile/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TourController', () {
    test('starts at the welcome step and advances through the tour', () {
      final tour = TourController();

      expect(tour.active, isFalse);
      tour.start();

      expect(tour.active, isTrue);
      expect(tour.step, 0);
      expect(tour.highlightedTab, isNull);

      tour.next();
      expect(tour.step, 1);
      expect(tour.highlightedTab, 0);

      tour.next();
      expect(tour.step, 2);
      expect(tour.highlightedTab, 1);
    });

    test('back, skip and finish are safe at all boundaries', () {
      final tour = TourController();

      tour.start(initialStep: 0);
      tour.prev();
      expect(tour.step, 0);

      tour.next();
      tour.prev();
      expect(tour.step, 0);

      tour.skip();
      expect(tour.active, isFalse);

      tour.start(initialStep: tour.totalSteps - 1);
      expect(tour.active, isTrue);
      tour.next();
      expect(tour.active, isFalse);
    });

    test('all highlighted tabs belong to the three available destinations', () {
      for (var step = 0; step < AppTour.totalSteps; step++) {
        final tab = AppTour.tabIndexAt(step);
        expect(tab == null || (tab >= 0 && tab < 3), isTrue);
      }

      expect(AppTour.tabIndexAt(0), isNull);
      expect(AppTour.tabIndexAt(1), 0);
      expect(AppTour.tabIndexAt(2), 1);
      expect(AppTour.tabIndexAt(5), 2);
    });

    test('first-use onboarding and app tour persist independently', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService();

      expect(await settings.getHasSeenOnboarding(), isFalse);
      expect(await settings.getHasSeenAppTour(), isFalse);

      await settings.setHasSeenOnboarding(true);
      await settings.setHasSeenAppTour(true);

      expect(await settings.getHasSeenOnboarding(), isTrue);
      expect(await settings.getHasSeenAppTour(), isTrue);
    });

    test('legacy install guide completion migrates the onboarding state',
        () async {
      SharedPreferences.setMockInitialValues({
        'has_seen_install_guide': true,
      });
      final settings = SettingsService();

      expect(await settings.getHasSeenInstallGuide(), isTrue);
      expect(await settings.getHasSeenOnboarding(), isFalse);

      await settings.setHasSeenOnboarding(
        await settings.getHasSeenInstallGuide(),
      );

      expect(await settings.getHasSeenOnboarding(), isTrue);
    });
  });

  group('StandaloneProvider presence state', () {
    test('requires consecutive frames before confirming presence', () {
      final provider = StandaloneProvider();
      expect(provider.personPresent, isFalse);

      provider.onPersonDetected(1, score: 0.8);
      expect(provider.personPresent, isFalse);

      provider.onPersonDetected(1, score: 0.9);
      expect(provider.personPresent, isTrue);
    });

    test('requires consecutive absent frames and clears when person returns',
        () {
      final provider = StandaloneProvider();
      provider.onPersonDetected(1, score: 0.9);
      provider.onPersonDetected(1, score: 0.9);
      expect(provider.personPresent, isTrue);

      provider.onPersonDetected(0);
      provider.onPersonDetected(0);
      expect(provider.personPresent, isTrue);

      provider.onPersonDetected(0);
      expect(provider.personPresent, isFalse);

      provider.onPersonDetected(1, score: 0.9);
      provider.onPersonDetected(1, score: 0.9);
      expect(provider.personPresent, isTrue);
    });

    test('restores background detection and does not duplicate its alert', () {
      final provider = StandaloneProvider()..startTimer(minutes: 30);
      final now = DateTime.now().millisecondsSinceEpoch;
      final state = {
        'lastPersonSeenMillis': now,
        'personPresent': false,
        'consecutivePresentFrames': 0,
        'consecutiveAbsentFrames': 3,
        'firedIntervals': [10],
        'lastAlertMillis': now,
        'lastAlertInterval': 10,
        'lastAlertMessage': 'Cocina desatendida',
      };

      void restore() => provider.syncBackgroundDetection(
            lastPersonSeenMillis: state['lastPersonSeenMillis']! as int,
            personPresent: state['personPresent']! as bool,
            consecutivePresentFrames: state['consecutivePresentFrames']! as int,
            consecutiveAbsentFrames: state['consecutiveAbsentFrames']! as int,
            firedIntervals: state['firedIntervals']! as List<int>,
            lastAlertMillis: state['lastAlertMillis']! as int,
            lastAlertInterval: state['lastAlertInterval']! as int,
            lastAlertMessage: state['lastAlertMessage']! as String,
          );

      restore();
      restore();

      expect(provider.personPresent, isFalse);
      expect(provider.alerts, hasLength(1));
      provider.stopTimer();
    });

    test('remote monitoring snapshots keep their alert idempotent', () {
      final provider = StandaloneProvider();
      final now = DateTime.now().millisecondsSinceEpoch;
      void sync() => provider.syncRemoteMonitoring(
            personPresent: false,
            timerRunning: true,
            timerPaused: true,
            durationMinutes: 45,
            remainingSeconds: 45 * 60,
            lastPersonSeenMillis: now - 60 * 1000,
            firedIntervals: const [1],
            lastAlertMillis: now,
            lastAlertInterval: 1,
            lastAlertMessage: 'Cocina desatendida',
          );

      sync();
      sync();

      expect(provider.cameraActive, isTrue);
      expect(provider.timerRunning, isTrue);
      expect(provider.timerPaused, isTrue);
      expect(provider.durationMinutes, 45);
      expect(provider.remainingSeconds, 45 * 60);
      expect(provider.personPresent, isFalse);
      expect(provider.alerts, hasLength(1));
    });

    test('monitor interval and frame counters remain bounded by state', () {
      final provider = StandaloneProvider();
      provider.setConfidence(1.5);
      provider.setNoPersonAlertSeconds(5);
      provider.setAlertIntervals([30, 10, 10]);

      expect(provider.confidence, 0.9);
      expect(provider.noPersonAlertSeconds, 10);
      expect(provider.sortedIntervals, [10, 30]);

      provider.startTimer(minutes: 15);
      expect(provider.timerRunning, isTrue);
      expect(provider.remainingSeconds, 15 * 60);

      provider.stopTimer();
      expect(provider.timerRunning, isFalse);
    });
  });
}
