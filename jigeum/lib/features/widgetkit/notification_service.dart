import 'package:flutter/foundation.dart';

/// MVP 안정화 단계: 상주/브리핑 알림 임시 비활성화 (no-op 스텁).
///
/// flutter_local_notifications 를 앱에서 제거해 시작 크래시 원인에서 배제한다.
/// 앱이 안정적으로 열리는 것을 확인한 뒤 실제 구현을 다시 붙인다.
/// API 는 호출부와 동일하게 유지 — 전부 아무 동작도 하지 않음.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  Future<void> init() async {
    debugPrint('[stub] NotificationService.init — 비활성화됨');
  }

  Future<bool> requestPermission() async => false;

  Future<void> showOngoingFocus(String? title) async {}

  Future<void> cancelOngoing() async {}

  Future<void> scheduleMorning(String? q2Title) async {}

  Future<void> scheduleEvening(int winCount) async {}
}
