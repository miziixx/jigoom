import 'package:flutter/services.dart';

/// ============================================================
/// WIDGET STUDIO — 홈 위젯 구성 액티비티 브리지
///
/// Android 위젯을 홈 화면에 얹을 때 뜨는 '구성 액티비티'(네이티브
/// StudioWidgetConfigActivity)와 통신한다. Flutter 가 위젯을 그려 PNG 로
/// 캡처한 뒤 [commit] 으로 넘기면, 네이티브가 그 이미지를 RemoteViews
/// ImageView 로 실제 홈 위젯에 표시하고 배치를 확정한다(setResult OK).
/// ============================================================
class StudioWidgetChannel {
  StudioWidgetChannel._();
  static const _ch = MethodChannel('jigeum/studio_widget');

  /// 구성 중인 위젯의 appWidgetId (없으면 null).
  static Future<int?> appWidgetId() async {
    try {
      return await _ch.invokeMethod<int>('getAppWidgetId');
    } catch (_) {
      return null;
    }
  }

  /// 렌더한 PNG(+설정 JSON)를 네이티브에 넘겨 홈 위젯 배치를 확정한다.
  /// configJson 은 이후 앱에서 위젯을 실데이터로 다시 렌더할 때 쓰인다.
  static Future<bool> commit({
    required Uint8List png,
    required int widthPx,
    required int heightPx,
    required String configJson,
  }) async {
    try {
      final ok = await _ch.invokeMethod<bool>('commit', {
        'png': png,
        'w': widthPx,
        'h': heightPx,
        'config': configJson,
      });
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 구성 취소(위젯 배치 안 함).
  static Future<void> cancel() async {
    try {
      await _ch.invokeMethod('cancel');
    } catch (_) {}
  }
}
