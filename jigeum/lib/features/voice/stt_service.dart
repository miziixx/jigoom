/// 온디바이스 STT 래퍼. 기획서 §1 ① 단계 + §5 커밋2.
///
/// 안드로이드 `SpeechRecognizer`(한국어)를 [MethodChannel] 로 감싼다. **UI 없음** —
/// 명령(start/stop/cancel)과 콜백(부분/최종 결과·상태)만 노출한다. 상위 파이프라인은
/// [SttService] 추상 타입에만 의존하므로, 테스트는 [MethodChannelSttService] 대신
/// 가짜 구현을 주입할 수 있다.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 받아쓰기 세션 상태.
enum SttStatus {
  /// 대기.
  idle,

  /// 듣는 중.
  listening,

  /// 자동 종료(최종 결과 전달 완료).
  done,

  /// 오류(네트워크/인식 실패 등).
  error,

  /// 기기가 STT 미지원.
  unavailable,

  /// 마이크 권한 거부.
  denied,
}

/// STT 한 조각. 부분 결과는 [isFinal]=false 로 여러 번, 최종은 true 로 한 번.
@immutable
class SttResult {
  const SttResult({
    required this.text,
    required this.confidence,
    required this.isFinal,
  });

  /// 받아쓴 텍스트.
  final String text;

  /// STT 신뢰도 0.0~1.0. 기기가 안 주면 -1(미상).
  final double confidence;

  /// 최종 결과 여부.
  final bool isFinal;

  @override
  bool operator ==(Object other) =>
      other is SttResult &&
      other.text == text &&
      other.confidence == confidence &&
      other.isFinal == isFinal;

  @override
  int get hashCode => Object.hash(text, confidence, isFinal);

  @override
  String toString() => 'SttResult("$text", conf: $confidence, final: $isFinal)';
}

/// STT 서비스 계약. 상위 코드는 이 인터페이스에만 의존한다.
abstract class SttService {
  /// 마이크 권한 요청(이미 있으면 즉시 true).
  Future<bool> requestPermission();

  /// 이 기기에서 STT 사용 가능한지.
  Future<bool> isAvailable();

  /// 상태 변화 스트림.
  Stream<SttStatus> get status;

  /// 부분/최종 결과 스트림.
  Stream<SttResult> get results;

  /// 사람이 읽을 오류 메시지 스트림(마이크 버튼이 스낵바로 띄운다).
  Stream<String> get errors;

  /// 받아쓰기 시작. [localeId] 기본 한국어.
  Future<void> start({String localeId = 'ko_KR'});

  /// 지금까지 받은 것으로 즉시 종료(최종 결과 유도).
  Future<void> stop();

  /// 결과 없이 취소.
  Future<void> cancel();

  /// 리소스 해제.
  Future<void> dispose();
}

/// [MethodChannel] 기반 실제 구현. 네이티브(SpeechRecognizer)가 이벤트를
/// Dart 로 되보낸다: `onPartial`, `onResult`, `onStatus`, `onError`.
class MethodChannelSttService implements SttService {
  MethodChannelSttService({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(channelName) {
    _channel.setMethodCallHandler(handleNativeCall);
  }

  /// 명령·콜백 공용 채널 이름. (네이티브와 동일해야 함)
  static const String channelName = 'jigeum/stt';

  final MethodChannel _channel;
  final _statusCtrl = StreamController<SttStatus>.broadcast();
  final _resultCtrl = StreamController<SttResult>.broadcast();
  final _errorCtrl = StreamController<String>.broadcast();

  @override
  Stream<SttStatus> get status => _statusCtrl.stream;

  @override
  Stream<SttResult> get results => _resultCtrl.stream;

  @override
  Stream<String> get errors => _errorCtrl.stream;

  @override
  Future<bool> requestPermission() async {
    final ok = await _invoke<bool>('requestPermission');
    if (ok == false) _statusCtrl.add(SttStatus.denied);
    return ok ?? false;
  }

  @override
  Future<bool> isAvailable() async {
    final ok = await _invoke<bool>('isAvailable');
    if (ok == false) _statusCtrl.add(SttStatus.unavailable);
    return ok ?? false;
  }

  @override
  Future<void> start({String localeId = 'ko_KR'}) =>
      _invoke<void>('start', {'localeId': localeId});

  @override
  Future<void> stop() => _invoke<void>('stop');

  @override
  Future<void> cancel() => _invoke<void>('cancel');

  @override
  Future<void> dispose() async {
    _channel.setMethodCallHandler(null);
    await _statusCtrl.close();
    await _resultCtrl.close();
    await _errorCtrl.close();
  }

  /// 네이티브 → Dart 콜백 처리. 테스트에서 직접 호출해 검증할 수 있다.
  @visibleForTesting
  Future<void> handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onPartial':
      case 'onResult':
        final args = (call.arguments as Map).cast<String, dynamic>();
        _resultCtrl.add(SttResult(
          text: (args['text'] as String?) ?? '',
          confidence: (args['confidence'] as num?)?.toDouble() ?? -1,
          isFinal: call.method == 'onResult',
        ));
        if (call.method == 'onResult') _statusCtrl.add(SttStatus.done);
      case 'onStatus':
        final raw = (call.arguments as Map)['status'] as String?;
        _statusCtrl.add(_statusFromNative(raw));
      case 'onError':
        _statusCtrl.add(SttStatus.error);
        final msg = (call.arguments as Map?)?.cast<String, dynamic>();
        _errorCtrl.add((msg?['message'] as String?) ?? '음성 인식 오류');
    }
  }

  static SttStatus _statusFromNative(String? raw) => switch (raw) {
        'listening' => SttStatus.listening,
        'done' => SttStatus.done,
        'unavailable' => SttStatus.unavailable,
        'denied' => SttStatus.denied,
        'error' => SttStatus.error,
        _ => SttStatus.idle,
      };

  Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      _statusCtrl.add(SttStatus.unavailable);
      _errorCtrl.add('이 환경에서는 음성 인식을 쓸 수 없어요. 안드로이드 앱에서 실행해 주세요.');
      return null;
    } on PlatformException catch (e) {
      _statusCtrl.add(SttStatus.error);
      _errorCtrl.add(e.message ?? '음성 인식 오류');
      return null;
    }
  }
}
