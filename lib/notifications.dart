import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'bridge.dart';

/// Channel id used for medication reminders. Kept as a constant so the
/// notification builder and the channel declaration cannot drift apart.
const String _medRemindersChannelId = 'med_reminders';

/// Declarative definition of the Android notification channel. Created
/// eagerly in [NotificationService.init] so the channel shows up in the
/// system "App info > Notifications" screen from the very first launch,
/// even before any reminder has been scheduled.
const AndroidNotificationChannel _medRemindersChannel =
    AndroidNotificationChannel(
  _medRemindersChannelId,
  'Recordatorios de medicación',
  description: 'Avisos para tomar la medicación',
  importance: Importance.high,
  playSound: true,
  enableVibration: true,
);

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Whether the user has granted the POST_NOTIFICATIONS permission. Set by
  /// [init] and kept in sync by anything that re-requests the permission.
  /// Null means "not yet asked" (pre-Android 13 or init not run).
  static bool? _notificationsGranted;

  /// Last known result of the runtime notification permission prompt. The
  /// PWA reads this through the bridge so it can show an in-app banner when
  /// the user has denied notifications and reminders would silently fail.
  static bool? get notificationsGranted => _notificationsGranted;

  static Future<void> init() async {
    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(initSettings);

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    // Create the channel explicitly so it appears in Settings > Notifications
    // on first launch, not only once a reminder fires (recommended since
    // flutter_local_notifications 17+).
    await android?.createNotificationChannel(_medRemindersChannel);

    // Android 13+: runtime POST_NOTIFICATIONS permission.
    // On older releases this returns true without prompting.
    _notificationsGranted =
        await android?.requestNotificationsPermission() ?? true;
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
        location,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );
      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      await _plugin.zonedSchedule(
        id++,
        'Medicacion · $time',
        meds,
        scheduled,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _medRemindersChannel.id,
            _medRemindersChannel.name,
            channelDescription: _medRemindersChannel.description,
            importance: _medRemindersChannel.importance,
            priority: Priority.high,
            playSound: _medRemindersChannel.playSound,
            enableVibration: _medRemindersChannel.enableVibration,
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
    final msg = BridgeMessage.tryParse(message);
    if (msg == null) return;
    await handleBridgeMessage(msg);
  }

  static Future<void> handleBridgeMessage(BridgeMessage msg) async {
    switch (msg.type) {
      case BridgeMessageType.scheduleAlarms:
        await scheduleAlarms(msg.extractSlots());
      case BridgeMessageType.cancelAlarms:
        await _plugin.cancelAll();
    }
  }
}
