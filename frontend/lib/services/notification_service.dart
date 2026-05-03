import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;

/// Handles local push notifications for session events.
/// Uses flutter_local_notifications which works on Windows, Android, iOS and macOS.
/// On Web, it gracefully degrades (no-op) since web doesn't support local notifications.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized || kIsWeb) return;
    try {
      const initSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
        macOS: DarwinInitializationSettings(),
      );
      await _plugin.initialize(initSettings);
      _initialized = true;
      debugPrint('NotificationService initialized');
    } catch (e) {
      debugPrint('NotificationService init failed (non-fatal): $e');
    }
  }

  /// Called on the lecturer side when a session is successfully started.
  static Future<void> showSessionStarted({
    required String classCode,
    required String classTitle,
    required String sessionCode,
  }) async {
    await _show(
      id: 1,
      title: '✅ Session Started — $classCode',
      body: '$classTitle\nClass code: $sessionCode  •  Share with students',
    );
  }

  /// Called on the student side when a new active session is detected for an enrolled class.
  static Future<void> showNewSession({
    required String classCode,
    required String classTitle,
    required String sessionCode,
    required String lecturerName,
  }) async {
    await _show(
      id: classCode.hashCode.abs() % 10000,
      title: '🔔 Class Started — $classCode',
      body: '$classTitle by $lecturerName\nYour code: $sessionCode',
    );
  }

  static Future<void> _show({
    required int id,
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return; // Web doesn't support local notifications
    if (!_initialized) await init();
    if (!_initialized) return;

    try {
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'gps_sessions',
          'Class Sessions',
          channelDescription: 'Notifications when a class session starts',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
        macOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
      );
      await _plugin.show(id, title, body, details);
    } catch (e) {
      debugPrint('Notification show failed (non-fatal): $e');
    }
  }
}
