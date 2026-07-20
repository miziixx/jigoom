import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../../data/db.dart';

/// 홈 위젯(포커스 2×1) 브리지 — 표시 전용.
///
/// 위젯의 인터랙티브 콜백(버튼→백그라운드 실행)은 안정화를 위해 보류.
/// saveWidgetData + updateWidget 로 포커스 제목만 위젯에 표시한다.
/// 웹은 미지원 → kIsWeb 분기로 no-op. 모든 진입점은 예외를 삼킨다.
class WidgetBridge {
  static const _keyTitle = 'focus_title';
  static const _keyId = 'focus_id';
  static const _androidWidget = 'FocusWidgetProvider';

  static Future<void> updateFocus(Node? focus) async {
    if (kIsWeb) return;
    try {
      await HomeWidget.saveWidgetData<String>(
          _keyTitle, focus?.title ?? '오늘 할 일을 정해볼까요');
      await HomeWidget.saveWidgetData<String>(_keyId, focus?.id ?? '');
      await HomeWidget.updateWidget(androidName: _androidWidget);
    } catch (e) {
      debugPrint('updateFocus 실패(무시): $e');
    }
  }

  /// 인터랙티브 콜백은 보류 (no-op). 재도입 시 백그라운드 수신기/서비스
  /// 매니페스트 설정과 함께 활성화한다.
  static Future<void> registerBackgroundCallback(
      Future<void> Function(Uri?) callback) async {}
}
