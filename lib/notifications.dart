import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(initSettings);

    // Request notification permission on Android 13+
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
  }

  static Future<void> scheduleAlarms(List<Map<String, dynamic>> slots) async {
    await _plugin.cancelAll();

    final location = tz.local;
    final now = tz.TZDateTime.now(location);

    int id = 0;
    for (final slot in slots) {
      final time = slot['time'] as String;
      final meds = slot['meds'] as String;
      final parts = time.split(':');
      if (parts.length != 2) continue;

      final hour = int.tryParse(parts[0]) ?? 0;
      final minute = int.tryParse(parts[1]) ?? 0;

      var scheduled = tz.TZDateTime(
          location, now.year, now.month, now.day, hour, minute);
      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      await _plugin.zonedSchedule(
        id++,
        'Medicacion · $time',
        meds,
        scheduled,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'med_reminders',
            'Recordatorios de medicacion',
            channelDescription: 'Avisos para tomar la medicacion',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  static Future<void> handleMessage(String message) async {
    try {
      final data = jsonDecode(message) as Map<String, dynamic>;
      final type = data['type'] as String?;

      if (type == 'schedule-alarms') {
        final slots = (data['slots'] as List<dynamic>)
            .map((s) => Map<String, dynamic>.from(s as Map))
            .toList();
        await scheduleAlarms(slots);
      } else if (type == 'cancel-alarms') {
        await _plugin.cancelAll();
      }
    } catch (_) {
      // Ignore malformed messages
    }
  }
}
