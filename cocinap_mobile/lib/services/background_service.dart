import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const _channelId = 'cocinap_foreground';
const _channelName = 'CocinaP Monitor';
const _notifId = 888;
const _alarmNotifId = 889;

final FlutterLocalNotificationsPlugin _notif = FlutterLocalNotificationsPlugin();

class BackgroundServiceManager {
  static Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _notif.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    await _notif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: 'Notificaciones de monitoreo y alarma',
            importance: Importance.low,
          ),
        );

    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: _channelId,
        initialNotificationTitle: 'CocinaP',
        initialNotificationContent: 'Monitoreando cocina...',
        foregroundServiceNotificationId: _notifId,
        foregroundServiceTypes: [AndroidForegroundType.dataSync],
      ),
      iosConfiguration: IosConfiguration(
        onForeground: onStart,
        autoStart: false,
      ),
    );

    service.startService();
  }

  static Future<void> showAlarm(String alert) async {
    final service = FlutterBackgroundService();
    service.invoke('updateAlarm', {"alert": alert});
    _showAlarmNotification(alert);
  }

  static Future<void> updateStatus(String status) async {
    final service = FlutterBackgroundService();
    service.invoke('updateStatus', {"status": status});
  }

  static Future<void> _showAlarmNotification(String alert) async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Notificaciones de alarma',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    const iosDetails = DarwinNotificationDetails();
    await _notif.show(
      _alarmNotifId,
      'CocinaP - Alarma',
      alert,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }

  static Future<void> stop() async {
    final service = FlutterBackgroundService();
    service.invoke('stopService');
  }
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) {
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.setForegroundNotificationInfo(
      title: 'CocinaP',
      content: 'Monitoreando cocina...',
    );
  }

  service.on('stopService').listen((_) {
    service.stopSelf();
  });

  service.on('updateAlarm').listen((data) {
    if (data != null && data["alert"] != null) {
      _showAlarmNotification(data["alert"] as String);
    }
  });

  service.on('updateStatus').listen((data) {
    if (data != null && data["status"] != null) {
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: 'CocinaP',
          content: data["status"] as String,
        );
      }
    }
  });
}

void _showAlarmNotification(String alert) {
  const androidDetails = AndroidNotificationDetails(
    _channelId,
    _channelName,
    channelDescription: 'Notificaciones de alarma',
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
  );
  const iosDetails = DarwinNotificationDetails();
  _notif.show(
    _alarmNotifId,
    'CocinaP - Alarma',
    alert,
    const NotificationDetails(android: androidDetails, iOS: iosDetails),
  );
}
