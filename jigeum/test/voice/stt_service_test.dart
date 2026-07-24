import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jigeum/features/voice/stt_service.dart';

import 'support/fake_stt_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MethodChannelSttService — 명령(Dart→네이티브)', () {
    final channel = MethodChannel(MethodChannelSttService.channelName);
    final log = <MethodCall>[];

    setUp(() {
      log.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        log.add(call);
        return switch (call.method) {
          'requestPermission' => true,
          'isAvailable' => true,
          _ => null,
        };
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('start 는 localeId 를 실어 start 를 호출', () async {
      final s = MethodChannelSttService();
      await s.start();
      expect(log.single.method, 'start');
      expect((log.single.arguments as Map)['localeId'], 'ko_KR');
      await s.dispose();
    });

    test('권한/가용성 결과를 bool 로 반환', () async {
      final s = MethodChannelSttService();
      expect(await s.requestPermission(), isTrue);
      expect(await s.isAvailable(), isTrue);
      await s.dispose();
    });
  });

  group('MethodChannelSttService — 콜백(네이티브→Dart)', () {
    test('onResult → 최종 결과 + done 상태', () async {
      final s = MethodChannelSttService();
      final gotResult = expectLater(
        s.results,
        emits(const SttResult(text: '치과 예약', confidence: 0.9, isFinal: true)),
      );
      final gotStatus = expectLater(s.status, emits(SttStatus.done));
      await s.handleNativeCall(const MethodCall(
        'onResult',
        {'text': '치과 예약', 'confidence': 0.9},
      ));
      await gotResult;
      await gotStatus;
      await s.dispose();
    });

    test('onPartial → 부분 결과(isFinal=false), confidence 미상은 -1', () async {
      final s = MethodChannelSttService();
      final got = expectLater(
        s.results,
        emits(const SttResult(text: '치과', confidence: -1, isFinal: false)),
      );
      await s.handleNativeCall(const MethodCall('onPartial', {'text': '치과'}));
      await got;
      await s.dispose();
    });

    test('onStatus 문자열을 enum 으로 매핑', () async {
      final s = MethodChannelSttService();
      final got = expectLater(s.status, emits(SttStatus.listening));
      await s.handleNativeCall(
          const MethodCall('onStatus', {'status': 'listening'}));
      await got;
      await s.dispose();
    });
  });

  group('FakeSttService', () {
    test('start 는 명령을 기록하고 listening 을 방출', () async {
      final fake = FakeSttService();
      final got = expectLater(fake.status, emits(SttStatus.listening));
      await fake.start();
      expect(fake.calls, contains('start:ko_KR'));
      await got;
      await fake.dispose();
    });

    test('emitFinal 은 최종 결과와 done 을 함께 방출', () async {
      final fake = FakeSttService();
      final gotResult = expectLater(
        fake.results,
        emits(const SttResult(text: '방금 코딩했어', confidence: 0.8, isFinal: true)),
      );
      final gotStatus = expectLater(fake.status, emits(SttStatus.done));
      fake.emitFinal('방금 코딩했어', confidence: 0.8);
      await gotResult;
      await gotStatus;
      await fake.dispose();
    });
  });
}
