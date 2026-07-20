import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// 상주 알림(잠금화면 대체) + 아침/저녁 브리핑.
/// 웹은 미지원 → kIsWeb 분기로 no-op.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _inited = false;

  static const _ongoingId = 1;
  static const _morningId = 2;
  static const _eveningId = 3;

  static const _ongoingChannel = AndroidNotificationChannel(
    'focus_ongoing',
    '지금 할 것',
    description: '상주 포커스 알림',
    importance: Importance.low, // 소리 없음
  );
  static const _briefChannel = AndroidNotificationChannel(
    'daily_brief',
    '아침/저녁 브리핑',
    importance: Importance.defaultImportance,
  );

  Future<void> init() async {
    if (kIsWeb || _inited) return;
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);

    final android13 = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android13?.createNotificationChannel(_ongoingChannel);
    await android13?.createNotificationChannel(_briefChannel);
    _inited = true;
  }

  /// Android 13+ POST_NOTIFICATIONS 권한 요청.
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission();
    return granted ?? false;
  }

  /// 상주 알림: "지금 할 것: {포커스 title}" + [완료] 액션.
  Future<void> showOngoingFocus(String? title) async {
    if (kIsWeb) return;
    if (title == null || title.isEmpty) {
      await _plugin.cancel(_ongoingId);
      return;
    }
    const details = AndroidNotificationDetails(
      'focus_ongoing',
      '지금 할 것',
      ongoing: true,
      autoCancel: false,
      priority: Priority.low,
      importance: Importance.low,
      playSound: false,
      onlyAlertOnce: true,
      actions: [
        AndroidNotificationAction('complete_focus', '완료',
            showsUserInterface: false, cancelNotification: false),
      ],
    );
    await _plugin.show(
      _ongoingId,
      '지금 할 것',
      title,
      const NotificationDetails(android: details),
      payload: 'ongoing_focus',
    );
  }

  Future<void> cancelOngoing() async {
    if (kIsWeb) return;
    await _plugin.cancel(_ongoingId);
  }

  /// 아침 08:00 브리핑: "오늘의 추천 — {Q2 title}부터 2분만"
  Future<void> scheduleMorning(String? q2Title) async {
    if (kIsWeb || q2Title == null || q2Title.isEmpty) return;
    await _zonedDaily(_morningId, '오늘의 추천', '$q2Title 부터 2분만', 8, 0);
  }

  /// 저녁 20:30: "오늘의 승리 {N}개". N=0이면 보내지 않음.
  Future<void> scheduleEvening(int winCount) async {
    if (kIsWeb) return;
    if (winCount <= 0) {
      await _plugin.cancel(_eveningId);
      return;
    }
    await _zonedDaily(_eveningId, '오늘의 승리', '$winCount개', 20, 30);
  }

  Future<void> _zonedDaily(
      int id, String title, String body, int hour, int minute) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    const details = NotificationDetails(
      android: AndroidNotificationDetails('daily_brief', '아침/저녁 브리핑'),
    );
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}
