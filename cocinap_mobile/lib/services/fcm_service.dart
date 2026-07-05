import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_service.dart';

class FcmService {
  FirebaseMessaging? _fcm;
  final FlutterLocalNotificationsPlugin _notif = FlutterLocalNotificationsPlugin();
  String? _currentToken;

  Future<void> init(ApiService api) async {
    try {
      _fcm = FirebaseMessaging.instance;
    } catch (_) {
      return;
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _notif.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    await _fcm!.requestPermission();

    _currentToken = await _fcm!.getToken();
    if (_currentToken != null) {
      await api.registerToken(_currentToken!);
    }

    _fcm!.onTokenRefresh.listen((token) async {
      if (_currentToken != null) {
        await api.unregisterToken(_currentToken!);
      }
      _currentToken = token;
      await api.registerToken(token);
    });

    FirebaseMessaging.onMessage.listen(_handleForeground);

    FirebaseMessaging.onBackgroundMessage(_handleBackground);
  }

  void _handleForeground(RemoteMessage message) {
    final notif = message.notification;
    if (notif != null) {
      _showNotification(notif.title ?? "CocinaP", notif.body ?? "");
    }
  }

  Future<void> _showNotification(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'cocinap_alarms',
      'Alarmas CocinaP',
      channelDescription: 'Notificaciones de alarma de CocinaP',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );
    const iosDetails = DarwinNotificationDetails();
    await _notif.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }
}

@pragma('vm:entry-point')
Future<void> _handleBackground(RemoteMessage message) async {
  final notif = message.notification;
  if (notif != null) {
    final plugin = FlutterLocalNotificationsPlugin();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await plugin.initialize(settings);
    await plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      notif.title ?? "CocinaP",
      notif.body ?? "",
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'cocinap_alarms',
          'Alarmas CocinaP',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}
