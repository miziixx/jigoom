import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../../data/db.dart';

/// 홈 위젯(포커스 2×1) 브리지.
/// 웹은 미지원 → kIsWeb 분기로 no-op.
class WidgetBridge {
  static const _keyTitle = 'focus_title';
  static const _keyId = 'focus_id';
  static const _androidWidget = 'FocusWidgetProvider';

  /// 포커스 노드를 위젯으로 전달 + 갱신.
  static Future<void> updateFocus(Node? focus) async {
    if (kIsWeb) return;
    try {
      await HomeWidget.saveWidgetData<String>(
          _keyTitle, focus?.title ?? '오늘 할 일을 정해볼까요');
      await HomeWidget.saveWidgetData<String>(_keyId, focus?.id ?? '');
      await HomeWidget.updateWidget(androidName: _androidWidget);
    } catch (_) {
      // 위젯 미설치 등 — 조용히 무시.
    }
  }

  /// 위젯 체크 탭 콜백 등록. background 콜백은 top-level 함수여야 함.
  static Future<void> registerBackgroundCallback(
      Future<void> Function(Uri?) callback) async {
    if (kIsWeb) return;
    await HomeWidget.registerInteractivityCallback(callback);
  }
}
