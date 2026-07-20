import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../data/db.dart';

/// 홈 위젯(포커스 2×1) 브리지 — 플러그인 없이 MethodChannel 로 직접 구현.
///
/// home_widget 플러그인이 이 기기에서 네이티브 크래시를 일으켜 제거했고,
/// 대신 MainActivity 의 'jigeum/widget' 채널이 SharedPreferences 저장 +
/// AppWidgetManager 갱신을 수행한다. 모든 진입점은 예외를 삼킨다.
class WidgetBridge {
  static const _channel = MethodChannel('jigeum/widget');

  static Future<void> updateFocus(Node? focus) async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod('updateFocus', {
        'title': focus?.title ?? '오늘 할 일을 정해볼까요',
      });
    } catch (e) {
      debugPrint('updateFocus 실패(무시): $e');
    }
  }

  /// 인터랙티브 콜백은 지원하지 않음 (no-op).
  static Future<void> registerBackgroundCallback(
      Future<void> Function(Uri?) callback) async {}
}
