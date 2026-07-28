import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// 상주 알림(잠금화면 대체) + 아침/저녁 브리핑.
/// 웹은 미지원 → kIsWeb 분기로 no-op.
/// 모든 진입점은 예외를 삼켜 앱 시작/동작을 절대 막지 않는다.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _inited = false;

  /// 방해 금지 — 켜지면 상주/아침/저녁 알림을 내보내지 않는다(하이퍼포커스 보호).
  bool quietMode = false;

  /// 알림 문구 변주 — 켜지면 브리핑 문구를 매번 조금씩 바꿔 무뎌짐을 줄인다.
  bool variedNudges = true;

  /// 날짜 기반 회전 인덱스(변주용) — 같은 날은 같은 문구, 날이 바뀌면 달라짐.
  int _rotate(int len) =>
      len <= 1 ? 0 : DateTime.now().day % len;

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
  static const _reminderChannel = AndroidNotificationChannel(
    'schedule_reminder',
    '일정 알림',
    description: '일정 시작 전 알림',
    importance: Importance.high,
  );

  Future<void> init() async {
    if (kIsWeb || _inited) return;
    try {
      tz.initializeTimeZones();

      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const settings = InitializationSettings(android: android);
      await _plugin.initialize(settings);

      final android13 = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android13?.createNotificationChannel(_ongoingChannel);
      await android13?.createNotificationChannel(_briefChannel);
      await android13?.createNotificationChannel(_reminderChannel);
      _inited = true;
    } catch (e, s) {
      debugPrint('NotificationService.init 실패(무시): $e\n$s');
    }
  }

  /// Android 13+ POST_NOTIFICATIONS 권한 요청.
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? false;
    } catch (e) {
      debugPrint('requestPermission 실패(무시): $e');
      return false;
    }
  }

  /// 상주 알림: "지금 할 것: {포커스 title}" + [완료] 액션.
  Future<void> showOngoingFocus(String? title) async {
    if (kIsWeb || !_inited) return;
    try {
      if (quietMode || title == null || title.isEmpty) {
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
        // 잠금화면에서도 내용이 그대로 보이도록 공개.
        visibility: NotificationVisibility.public,
      );
      await _plugin.show(
        _ongoingId,
        '지금 할 것',
        title,
        const NotificationDetails(android: details),
      );
    } catch (e) {
      debugPrint('showOngoingFocus 실패(무시): $e');
    }
  }

  Future<void> cancelOngoing() async {
    if (kIsWeb) return;
    try {
      await _plugin.cancel(_ongoingId);
    } catch (_) {}
  }

  /// 아침 08:00 브리핑: "오늘의 추천 — {Q2 title}부터 2분만"
  Future<void> scheduleMorning(String? q2Title) async {
    if (kIsWeb || !_inited || q2Title == null || q2Title.isEmpty) return;
    if (quietMode) {
      try {
        await _plugin.cancel(_morningId);
      } catch (_) {}
      return;
    }
    // 페르소나 톤으로 여는 꼬리말(변주 켜짐일 때). 컨텍스트(아침)에 맞춘 목소리.
    final tail = variedNudges ? _morningTail() : '부터 2분만';
    await _zonedDaily(_morningId, '오늘의 추천', '$q2Title $tail', 8, 0);
  }

  String _morningTail() {
    const tails = ['부터 딱 2분만', '· 천천히 하나만', '· 아침에 시작이 유리해요'];
    return tails[_rotate(tails.length)];
  }

  /// 저녁 20:30: "오늘의 승리 {N}개". N=0이면 보내지 않음.
  Future<void> scheduleEvening(int winCount) async {
    if (kIsWeb || !_inited) return;
    if (quietMode || winCount <= 0) {
      await cancelOngoing();
      try {
        await _plugin.cancel(_eveningId);
      } catch (_) {}
      return;
    }
    final body = variedNudges ? _praise(winCount, _rotate(3)) : '$winCount개';
    await _zonedDaily(_eveningId, '오늘의 승리', body, 20, 30);
  }

  String _praise(int n, int i) {
    switch (i) {
      case 0:
        return '오늘 $n개 해냈어요';
      case 1:
        return '$n개나 마쳤네요';
      default:
        return '$n걸음 나아갔어요';
    }
  }

  /// 방해 금지가 켜졌을 때 즉시 모든 알림 정리.
  Future<void> silenceAll() async {
    if (kIsWeb) return;
    try {
      await _plugin.cancel(_ongoingId);
      await _plugin.cancel(_morningId);
      await _plugin.cancel(_eveningId);
    } catch (_) {}
  }

  Future<void> _zonedDaily(
      int id, String title, String body, int hour, int minute) async {
    try {
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
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('_zonedDaily 실패(무시): $e');
    }
  }

  // -------------------------------------------------------- 일정 알림
  /// 일정 id → 안정적인 양수 알림 id (상주=1·브리핑=2/3 과 겹치지 않게 offset).
  int _reminderId(String scheduleId) {
    var h = 0;
    for (final c in scheduleId.codeUnits) {
      h = (h * 31 + c) & 0x3fffffff;
    }
    return 100000 + h;
  }

  /// 일정 알림 예약(재예약 시 이전 것 취소). reminderMin=시작 몇 분 전(0=정각),
  /// 종일이면 그날 09:00 기준. repeatRule=null|daily|weekly|monthly.
  Future<void> scheduleEventReminder({
    required String scheduleId,
    required DateTime date, // 자정 기준
    required int startMin,
    required int reminderMin,
    required bool allDay,
    required String title,
    String? repeatRule,
  }) async {
    if (kIsWeb || !_inited) return;
    try {
      final id = _reminderId(scheduleId);
      await _plugin.cancel(id); // 재예약 전 정리

      // 기준 시각: 종일=09:00, 아니면 시작 시각. 거기서 reminderMin 만큼 당김.
      final base = DateTime(date.year, date.month, date.day)
          .add(Duration(minutes: allDay ? 9 * 60 : startMin));
      final fire = base.subtract(Duration(minutes: reminderMin));
      var scheduled = tz.TZDateTime.from(fire, tz.local);
      final now = tz.TZDateTime.now(tz.local);

      DateTimeComponents? match;
      switch (repeatRule) {
        case 'daily':
          match = DateTimeComponents.time;
          break;
        case 'weekly':
          match = DateTimeComponents.dayOfWeekAndTime;
          break;
        case 'monthly':
          match = DateTimeComponents.dayOfMonthAndTime;
          break;
      }

      if (match == null) {
        // 1회성: 이미 지났으면 예약하지 않음.
        if (scheduled.isBefore(now)) return;
      } else {
        // 반복: 다음 발생 시각으로 밀어 미래로.
        if (repeatRule == 'monthly') {
          while (scheduled.isBefore(now)) {
            scheduled = tz.TZDateTime(tz.local, scheduled.year,
                scheduled.month + 1, scheduled.day, scheduled.hour,
                scheduled.minute);
          }
        } else {
          final step = repeatRule == 'weekly'
              ? const Duration(days: 7)
              : const Duration(days: 1);
          while (scheduled.isBefore(now)) {
            scheduled = scheduled.add(step);
          }
        }
      }

      final body = allDay
          ? '오늘 일정'
          : (reminderMin <= 0 ? '지금 시작' : '$reminderMin분 후 시작');
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'schedule_reminder',
          '일정 알림',
          importance: Importance.high,
          priority: Priority.high,
          visibility: NotificationVisibility.public,
        ),
      );
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: match,
      );
    } catch (e) {
      debugPrint('scheduleEventReminder 실패(무시): $e');
    }
  }

  Future<void> cancelEventReminder(String scheduleId) async {
    if (kIsWeb) return;
    try {
      await _plugin.cancel(_reminderId(scheduleId));
    } catch (_) {}
  }
}
