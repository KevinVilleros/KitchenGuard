import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../content/content.dart';

const _fgChannelId = 'cocinap_foreground';
const _fgChannelName = 'CocinaP Monitor';
const _alarmChannelId = 'cocinap_alarms';
const _alarmChannelName = 'CocinaP Alarmas';
const _notifId = 888;

final FlutterLocalNotificationsPlugin _notif = FlutterLocalNotificationsPlugin();

class BackgroundServiceManager {
  static Future<bool> get notificationsEnabled async {
    final result = await _notif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.areNotificationsEnabled();
    return result ?? true;
  }

  static Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _notif.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    // Solicitar permiso de notificaciones (Android 13+ / iOS).
    await _notif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _notif
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    // Foreground service channel (low importance, no sound)
    await _notif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _fgChannelId,
            _fgChannelName,
            description: AppLocal.language == 'en'
                ? 'Foreground monitoring service'
                : 'Notificacion de servicio en primer plano',
            importance: Importance.low,
          ),
        );

    // Alarm notification channel (high importance, with sound)
    await _notif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _alarmChannelId,
            _alarmChannelName,
            description: AppLocal.language == 'en'
                ? 'Security alerts and alarms'
                : 'Alertas y alarmas de seguridad',
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
          ),
        );

    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: _fgChannelId,
        initialNotificationTitle: 'CocinaP',
        initialNotificationContent: AppLocal.language == 'en'
            ? 'Monitoring kitchen...'
            : 'Monitoreando cocina...',
        foregroundServiceNotificationId: _notifId,
        foregroundServiceTypes: [AndroidForegroundType.dataSync, AndroidForegroundType.camera],
      ),
      iosConfiguration: IosConfiguration(
        onForeground: onStart,
        autoStart: false,
      ),
    );

  }

  static Future<void> startMonitoring(int remainingSeconds) async {
    if (kIsWeb || (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }
    final service = FlutterBackgroundService();
    final running = await service.isRunning();
    if (!running) {
      await service.startService();
    }
    service.invoke('updateStatus', {
      'status': AppLocal.language == 'en'
          ? 'Monitoring active: ${remainingSeconds ~/ 60} min'
          : 'Monitoreo activo: ${remainingSeconds ~/ 60} min'
    });
  }

  static Future<void> stopMonitoring() async {
    if (kIsWeb || (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }
    final service = FlutterBackgroundService();
    if (await service.isRunning()) {
      service.invoke('stopService');
    }
  }

  static Future<void> showAlarm(String alert) async {
    final service = FlutterBackgroundService();
    service.invoke('updateAlarm', {"alert": alert});
    await _showAlarmNotification(alert);
  }

  static Future<void> updateStatus(String status) async {
    if (kIsWeb || (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }
    final service = FlutterBackgroundService();
    service.invoke('updateStatus', {"status": status});
  }

  static Future<void> sendTestAlarm() async {
    await _showAlarmNotification(
      AppLocal.language == 'en'
          ? 'Test alert: sound and vibration are active.'
          : 'Prueba de alerta: sonido y vibración activos.',
    );
  }

  static Future<void> _showAlarmNotification(String alert) async {
    final androidDetails = AndroidNotificationDetails(
      _alarmChannelId,
      _alarmChannelName,
      channelDescription: AppLocal.language == 'en'
          ? 'Security alerts and alarms'
          : 'Alertas y alarmas de seguridad',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true,
    );
    const iosDetails = DarwinNotificationDetails();
    final id = DateTime.now().millisecondsSinceEpoch % 100000;
    await _notif.show(
      id,
      AppLocal.language == 'en' ? 'CocinaP - Alarm' : 'CocinaP - Alarma',
      alert,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) {
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.setForegroundNotificationInfo(
      title: 'CocinaP',
      content: AppLocal.language == 'en'
          ? 'Monitoring kitchen...'
          : 'Monitoreando cocina...',
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
  final androidDetails = AndroidNotificationDetails(
    _alarmChannelId,
    _alarmChannelName,
    channelDescription: AppLocal.language == 'en'
        ? 'Security alerts and alarms'
        : 'Alertas y alarmas de seguridad',
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
    fullScreenIntent: true,
  );
  const iosDetails = DarwinNotificationDetails();
  final id = DateTime.now().millisecondsSinceEpoch % 100000;
  _notif.show(
    id,
    AppLocal.language == 'en' ? 'CocinaP - Alarm' : 'CocinaP - Alarma',
    alert,
    NotificationDetails(android: androidDetails, iOS: iosDetails),
  );
}
