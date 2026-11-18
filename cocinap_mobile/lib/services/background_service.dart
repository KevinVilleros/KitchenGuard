import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../content/content.dart';

const _alarmChannelId = 'cocinap_alarms';
const _alarmChannelName = 'CocinaP Alarmas';
const _backgroundMonitoringChannel =
    MethodChannel('com.cocinap.mobile/background_monitoring');

final FlutterLocalNotificationsPlugin _notif =
    FlutterLocalNotificationsPlugin();

class BackgroundServiceManager {
  static Future<bool> get notificationsEnabled async {
    final result = await _notif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.areNotificationsEnabled();
    return result ?? true;
  }

  static Future<void> init() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _notif.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    await _notif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _notif
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    await _notif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          AndroidNotificationChannel(
            _alarmChannelId,
            _alarmChannelName,
            description: AppLocal.language == 'en'
                ? 'Security alerts and alarms'
                : 'Alertas de seguridad y alarmas',
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
          ),
        );
  }

  static Future<void> startMonitoring({
    required int remainingSeconds,
    required double confidence,
    required int noPersonAlertSeconds,
    required List<int> alertIntervals,
    required bool intervalAlertsEnabled,
    required bool repeatLastInterval,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    await _backgroundMonitoringChannel.invokeMethod<void>(
      'startMonitoring',
      {
        'remainingSeconds': remainingSeconds,
        'confidence': confidence,
        'noPersonAlertSeconds': noPersonAlertSeconds,
        'alertIntervals': alertIntervals,
        'intervalAlertsEnabled': intervalAlertsEnabled,
        'repeatLastInterval': repeatLastInterval,
        'language': AppLocal.language,
      },
    );
  }

  static Future<void> setCameraActive(bool active) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    await _backgroundMonitoringChannel.invokeMethod<void>(
      'setCameraActive',
      active,
    );
  }

  static Future<Map<String, dynamic>?> getMonitoringState() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    return _backgroundMonitoringChannel.invokeMapMethod<String, dynamic>(
      'getMonitoringState',
    );
  }

  static Future<void> stopMonitoring() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    await _backgroundMonitoringChannel.invokeMethod<void>('stopMonitoring');
  }

  static Future<void> showAlarm(String alert) async {
    await _showAlarmNotification(alert);
  }

  static Future<void> updateStatus(String status) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    await _backgroundMonitoringChannel.invokeMethod<void>(
      'updateStatus',
      status,
    );
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
          : 'Alertas de seguridad y alarmas',
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
