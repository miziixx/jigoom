import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
// ignore: avoid_print  (debug logging for alarm reliability diagnosis)

typedef NotificationTapCallback = void Function(String memoId);

class NotificationService {
  NotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _batteryChannel = MethodChannel('app/battery');

  static NotificationTapCallback? onNotificationTap;
  static final pendingMemoId = ValueNotifier<String?>(null);

  static const _channelId   = 'memo_reminders';
  static const _channelName = 'Memo Reminders';
  static const _channelDesc = 'Scheduled memo reminders';

  // ── Init ───────────────────────────────────────────────────────

  static Future<void> init() async {
    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings    = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onResponse,
      onDidReceiveBackgroundNotificationResponse: _onResponseBackground,
    );

    if (!kIsWeb) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDesc,
          importance: Importance.max,
          enableLights: true,
          enableVibration: true,
          playSound: true,
        ),
      );
    }
  }

  static void _onResponse(NotificationResponse details) {
    print('[ALARM_DEBUG] _onResponse() — notification tapped, payload=${details.payload}');
    final payload = details.payload;
    if (payload == null || payload.isEmpty) return;
    if (onNotificationTap != null) {
      onNotificationTap!(payload);
    } else {
      pendingMemoId.value = payload;
    }
  }

  // ── Permissions ────────────────────────────────────────────────

  /// Check current POST_NOTIFICATIONS grant status without requesting.
  static Future<bool> areNotificationsEnabled() async {
    if (kIsWeb) return false;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return false;
    return await android.areNotificationsEnabled() ?? false;
  }

  /// Check if exact alarm scheduling is allowed.
  static Future<bool> canScheduleExact() async {
    if (kIsWeb) return false;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return false;
    return await android.canScheduleExactNotifications() ?? false;
  }

  /// Open app notification settings page.
  static Future<void> openNotificationSettings() async {
    if (kIsWeb) return;
    try {
      await const MethodChannel('app/battery')
          .invokeMethod('openNotificationSettings');
    } catch (_) {}
  }

  /// POST_NOTIFICATIONS (Android 13+)
  static Future<bool> requestPermissions() async {
    if (kIsWeb) return false;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return false;
    final granted = await android.requestNotificationsPermission();
    return granted ?? false;
  }

  /// SCHEDULE_EXACT_ALARM — silently opens Settings if not granted.
  /// Returns true if already permitted.
  static Future<bool> ensureExactAlarmPermission() async {
    if (kIsWeb) return false;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return false;
    final permitted = await android.canScheduleExactNotifications() ?? false;
    if (!permitted) {
      // Opens "Alarms & reminders" settings page on Android 12+.
      await android.requestExactAlarmsPermission();
    }
    return permitted;
  }

  /// Whether the app is exempt from battery optimization.
  static Future<bool> isIgnoringBatteryOptimizations() async {
    if (kIsWeb) return true;
    try {
      return await _batteryChannel
              .invokeMethod<bool>('isIgnoringBatteryOptimizations') ??
          false;
    } catch (_) {
      return true;
    }
  }

  /// Opens the system dialog asking the user to exempt this app.
  static Future<void> requestBatteryOptimizationExemption() async {
    if (kIsWeb) return;
    try {
      await _batteryChannel.invokeMethod('requestIgnoreBatteryOptimizations');
    } catch (_) {}
  }

  // ── Schedule / Cancel ─────────────────────────────────────────

  /// Maps a repeat string to the plugin's recurrence matcher.
  /// Returns null for a one-shot (non-repeating) reminder.
  static DateTimeComponents? _repeatComponents(String repeat) {
    switch (repeat) {
      case 'daily':   return DateTimeComponents.time;
      case 'weekly':  return DateTimeComponents.dayOfWeekAndTime;
      case 'monthly': return DateTimeComponents.dayOfMonthAndTime;
      default:        return null;
    }
  }

  static Future<void> schedule({
    required String memoId,
    required String content,
    required DateTime scheduledAt,
    String repeat = 'none',
  }) async {
    if (kIsWeb) return;
    final id      = _notifId(memoId);
    final preview = content.length > 120
        ? '${content.substring(0, 120)}...'
        : content;

    final matchComponents = _repeatComponents(repeat);

    // For a repeating reminder whose first occurrence is already in the past,
    // roll forward to the next matching occurrence so it doesn't fire instantly.
    var fireAt = scheduledAt;
    if (matchComponents != null) {
      final now = DateTime.now();
      while (fireAt.isBefore(now)) {
        switch (repeat) {
          case 'daily':   fireAt = fireAt.add(const Duration(days: 1)); break;
          case 'weekly':  fireAt = fireAt.add(const Duration(days: 7)); break;
          case 'monthly': fireAt = DateTime(fireAt.year, fireAt.month + 1,
              fireAt.day, fireAt.hour, fireAt.minute); break;
          default: fireAt = now; break;
        }
      }
    }

    // epoch ms from local Dart DateTime → correct absolute firing time
    final tzWhen = tz.TZDateTime.fromMillisecondsSinceEpoch(
        tz.UTC, fireAt.millisecondsSinceEpoch);

    print('[ALARM_DEBUG] schedule() called — id=$id memoId=$memoId '
        'scheduledAt=$fireAt repeat=$repeat epochMs=${fireAt.millisecondsSinceEpoch}');

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.max,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(preview),
        enableLights: true,
        enableVibration: true,
        // fullScreenIntent removed: Android 14+ requires explicit user grant;
        // if denied on Samsung it can silently block notification delivery.
      ),
    );

    // alarmClock mode → AlarmManager.setAlarmClock()
    // • Immune to Doze mode and battery optimization (including Samsung One UI)
    // • Shows clock icon in status bar (user-visible, OS won't suppress it)
    // • Does NOT require SCHEDULE_EXACT_ALARM permission
    try {
      await _plugin.zonedSchedule(
        id,
        '[ MEMO ]',
        preview,
        tzWhen,
        details,
        androidScheduleMode: AndroidScheduleMode.alarmClock,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: matchComponents,
        payload: memoId,
      );
      print('[ALARM_DEBUG] zonedSchedule() succeeded — id=$id fires at $tzWhen');
    } catch (e, st) {
      print('[ALARM_DEBUG] zonedSchedule() FAILED — id=$id error=$e\n$st');
    }
  }

  static Future<void> cancel(String memoId) async {
    if (kIsWeb) return;
    await _plugin.cancel(_notifId(memoId));
  }

  static Future<void> checkLaunchDetails() async {
    if (kIsWeb) return;
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp ?? false) {
      final payload = details?.notificationResponse?.payload;
      if (payload != null && payload.isNotEmpty) {
        pendingMemoId.value = payload;
      }
    }
  }

  static int _notifId(String memoId) {
    final ts = int.tryParse(memoId) ?? memoId.hashCode;
    return ts.abs() % 2147483647;
  }
}

@pragma('vm:entry-point')
void _onResponseBackground(NotificationResponse details) {
  final payload = details.payload;
  if (payload != null && payload.isNotEmpty) {
    NotificationService.pendingMemoId.value = payload;
  }
}
