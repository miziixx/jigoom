import 'dart:async';

import 'package:jigeum/features/voice/stt_service.dart';

/// 네이티브 없이 STT 를 흉내내는 테스트용 구현.
///
/// 상위 파이프라인(라우터 등) 테스트에서 발화를 프로그램적으로 주입하는 데 쓴다.
class FakeSttService implements SttService {
  final _statusCtrl = StreamController<SttStatus>.broadcast();
  final _resultCtrl = StreamController<SttResult>.broadcast();
  final _errorCtrl = StreamController<String>.broadcast();

  /// 호출된 명령 로그(검증용).
  final List<String> calls = [];

  bool available = true;
  bool permission = true;

  @override
  Stream<SttStatus> get status => _statusCtrl.stream;

  @override
  Stream<SttResult> get results => _resultCtrl.stream;

  @override
  Stream<String> get errors => _errorCtrl.stream;

  @override
  Future<bool> isAvailable() async {
    calls.add('isAvailable');
    return available;
  }

  @override
  Future<bool> requestPermission() async {
    calls.add('requestPermission');
    return permission;
  }

  @override
  Future<void> start({String localeId = 'ko_KR'}) async {
    calls.add('start:$localeId');
    _statusCtrl.add(SttStatus.listening);
  }

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<void> cancel() async => calls.add('cancel');

  @override
  Future<void> dispose() async {
    await _statusCtrl.close();
    await _resultCtrl.close();
    await _errorCtrl.close();
  }

  /// 테스트 헬퍼 — 오류 메시지 주입.
  void emitError(String message) => _errorCtrl.add(message);

  // --- 테스트 헬퍼 ---------------------------------------------------------

  void emitPartial(String text, {double confidence = -1}) => _resultCtrl
      .add(SttResult(text: text, confidence: confidence, isFinal: false));

  void emitFinal(String text, {double confidence = -1}) {
    _resultCtrl.add(SttResult(text: text, confidence: confidence, isFinal: true));
    _statusCtrl.add(SttStatus.done);
  }
}
