/// Real OS notifications, wrapped so a refused permission never breaks the demo.
library;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const String _channelId = '8x_demo';
const String _channelName = '8x Friends';
const String _channelDescription =
    'Invitations and meet-up confirmations from the people you know.';
const String _androidIcon = '@mipmap/ic_launcher';
const int _maxId = 0x7FFFFFFF;

/// Real OS notifications. Every method is best-effort: a platform that refuses
/// permission, or a plugin that fails to initialise, must never break the demo.
abstract final class Notifications {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// True once [init] completed without throwing. Everything is a no-op until
  /// then, so an unsupported platform simply stays quiet.
  static bool _ready = false;

  /// Monotonic, so successive notifications stack instead of replacing.
  static int _nextId = 1;

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      presentBanner: true,
      presentList: true,
    ),
  );

  /// Call once from `main()`. Never throws.
  static Future<void> init() async {
    if (_ready) return;
    try {
      const settings = InitializationSettings(
        android: AndroidInitializationSettings(_androidIcon),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        ),
      );
      await _plugin.initialize(settings: settings);
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  /// Asks for permission (iOS + Android 13+). Never throws.
  static Future<void> requestPermission() async {
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (_) {
      // A device that says no is a device that says no.
    }
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    } catch (_) {
      // Same.
    }
  }

  /// Shows an immediate notification. Never throws.
  static Future<void> show(String title, String body) async {
    if (!_ready) return;
    final id = _nextId;
    _nextId = id >= _maxId ? 1 : id + 1;
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: _details,
      );
    } catch (_) {
      // Best effort: the in-app banner still carries the beat.
    }
  }
}
