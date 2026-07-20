import 'package:flutter/foundation.dart';

import '../../data/db.dart';

/// MVP 안정화 단계: 홈 위젯 브리지 임시 비활성화 (no-op 스텁).
///
/// home_widget 를 앱에서 제거해 시작 크래시 원인에서 배제한다.
/// 앱이 안정적으로 열리는 것을 확인한 뒤 실제 구현을 다시 붙인다.
class WidgetBridge {
  static Future<void> updateFocus(Node? focus) async {}

  static Future<void> registerBackgroundCallback(
      Future<void> Function(Uri?) callback) async {
    debugPrint('[stub] WidgetBridge.registerBackgroundCallback — 비활성화됨');
  }
}
