import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static bool _enabled = true;

  static bool get isEnabled => _enabled;

  static Future<void> init() async {
    // Android
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS / macOS
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _plugin.initialize(settings);

    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        'plant_care',
        '식물 관리',
        description: '식물 수분 부족 및 사망 알림',
        importance: Importance.high,
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } else if (Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    }

    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool('notifications_enabled') ?? true;

    _initialized = true;
  }

  static Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', enabled);
  }

  static NotificationDetails get _details => NotificationDetails(
        android: const AndroidNotificationDetails(
          'plant_care',
          '식물 관리',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          categoryIdentifier: 'plant_care',
        ),
      );

  static NotificationDetails get _detailsLow => NotificationDetails(
        android: const AndroidNotificationDetails(
          'plant_care',
          '식물 관리',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: false,
          presentSound: false,
          categoryIdentifier: 'plant_care',
        ),
      );

  static Future<void> showPlantThirsty(String plantName) async {
    if (!_initialized || !_enabled) return;
    await _plugin.show(
      plantName.hashCode & 0x7FFFFFFF,
      '💧 식물이 목말라요!',
      '$plantName이(가) 물이 필요해요. 지금 바로 물을 주세요!',
      _details,
    );
  }

  static Future<void> showPlantDied(String plantName) async {
    if (!_initialized || !_enabled) return;
    await _plugin.show(
      (plantName.hashCode + 1000) & 0x7FFFFFFF,
      '💀 식물이 죽었어요',
      '$plantName이(가) 물 부족으로 시들어 죽었어요...',
      _detailsLow,
    );
  }
}
