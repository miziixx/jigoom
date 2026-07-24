// 커밋8 라우터. 원문 → 전 구간 → 세 갈래(§2) 결정을 단정.
import 'package:flutter_test/flutter_test.dart';
import 'package:jigeum/features/voice/models/intent_type.dart';
import 'package:jigeum/features/voice/models/voice_result.dart';
import 'package:jigeum/features/voice/voice_router.dart';

void main() {
  final base = DateTime(2026, 7, 24);
  final router = VoiceRouter();

  group('§2 세 갈래 결정', () {
    test('미인식(S==0) → 보류함 + 인텐트 none + 슬롯 비움', () {
      final r = router.analyze('어… 그거 있잖아 뭐였지', now: base);
      expect(r.decision, RouteDecision.inbox);
      expect(r.routedTo, RoutePoint.inbox);
      expect(r.intent, IntentType.none);
      expect(r.slots.title, isNull);
      expect(r.rawText, '어… 그거 있잖아 뭐였지'); // 원문 보존
    });

    test('애매(S 낮음) → 빠른담기(A), 인텐트는 최고점 유지', () {
      final r = router.analyze('파란색 그거 처리', now: base);
      expect(r.decision, RouteDecision.quickCapture);
      expect(r.routedTo, RoutePoint.quickCapture);
      expect(r.intent, IntentType.todoAdd);
      expect(r.slots.title, '파란색 그거 처리');
    });

    test('날짜만(금요일 장보기)은 유력하지만 임계 미달 → A 로', () {
      final r = router.analyze('금요일에 장보기', now: base);
      expect(r.intent, IntentType.scheduleAdd); // 최고점은 일정
      expect(r.decision, RouteDecision.quickCapture); // 그러나 S<3 → A
      expect(r.routedTo, RoutePoint.quickCapture);
      expect(r.slots.title, '장보기');
    });

    test('확정(내일 3시 치과) → 일정(C) 확정 라우팅', () {
      final r = router.analyze('내일 3시에 치과 예약', now: base);
      expect(r.decision, RouteDecision.confirm);
      expect(r.routedTo, RoutePoint.schedule);
      expect(r.intent, IntentType.scheduleAdd);
      expect(r.slots.title, '치과');
    });
  });

  test('되돌리기용 원문·정규화문을 항상 담는다', () {
    final r = router.analyze('  이거 중요하고, 급해! 보고서 ', now: base);
    expect(r.rawText, '  이거 중요하고, 급해! 보고서 ');
    expect(r.normalizedText, '이거 중요하고 급해 보고서');
    expect(r.routedTo, RoutePoint.matrix);
  });
}
