import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 홈/잠금화면 위젯 브리지 — 플러그인 없이 MethodChannel 로 직접 구현.
///
/// MainActivity 의 'jigeum/widget' 채널이 SharedPreferences 저장 +
/// AppWidgetManager 갱신을 수행한다. 모든 진입점은 예외를 삼킨다.
class WidgetBridge {
  static const _channel = MethodChannel('jigeum/widget');

  /// 포커스 + 매트릭스 데이터를 위젯에 반영.
  /// 각 사분면은 상위 항목 제목을 개행으로 이은 문자열.
  static Future<void> updateWidgets({
    required String focusTitle,
    required String q1,
    required String q2,
    required String q3,
    required int q4Count,
  }) async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod('updateWidgets', {
        'focus': focusTitle,
        'q1': q1,
        'q2': q2,
        'q3': q3,
        'q4count': q4Count,
      });
    } catch (e) {
      debugPrint('updateWidgets 실패(무시): $e');
    }
  }

  /// 타임트래커 위젯 갱신 (지금 블록 라벨 + 마지막 기록).
  static Future<void> updateTimeTrack(String label, String text) async {
    if (kIsWeb) return;
    try {
      await _channel
          .invokeMethod('updateTimeTrack', {'label': label, 'text': text});
    } catch (e) {
      debugPrint('updateTimeTrack 실패(무시): $e');
    }
  }

  /// 위젯 배경 투명도 (0=완전투명 ~ 100=불투명).
  static Future<void> setWidgetOpacity(int percent) async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod('setWidgetOpacity', {'percent': percent});
    } catch (e) {
      debugPrint('setWidgetOpacity 실패(무시): $e');
    }
  }

  static Future<int> getWidgetOpacity() async {
    if (kIsWeb) return 90;
    try {
      return await _channel.invokeMethod<int>('getWidgetOpacity') ?? 90;
    } catch (_) {
      return 90;
    }
  }

  /// 위젯 탭으로 앱이 열렸는지 확인 (1회성 소비).
  /// 'quick_capture' 면 입력창에 바로 포커스.
  static Future<String?> consumeLaunchAction() async {
    if (kIsWeb) return null;
    try {
      return await _channel.invokeMethod<String>('consumeLaunchAction');
    } catch (_) {
      return null;
    }
  }

  /// 백업 JSON 을 문서창(SAF)으로 저장. true=저장됨, null/false=취소·실패.
  static Future<bool> saveBackup(String filename, String content) async {
    if (kIsWeb) return false;
    try {
      final ok = await _channel.invokeMethod<bool>(
          'saveBackup', {'filename': filename, 'content': content});
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 문서창(SAF)에서 백업 파일 선택 → 내용 반환. null=취소·실패.
  static Future<String?> openBackup() async {
    if (kIsWeb) return null;
    try {
      return await _channel.invokeMethod<String>('openBackup');
    } catch (_) {
      return null;
    }
  }
}
