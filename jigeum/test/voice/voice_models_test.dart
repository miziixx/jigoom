import 'package:flutter_test/flutter_test.dart';
import 'package:jigeum/features/voice/models/intent_type.dart';
import 'package:jigeum/features/voice/models/time_parse_result.dart';
import 'package:jigeum/features/voice/models/voice_result.dart';
import 'package:jigeum/features/voice/voice_constants.dart';

void main() {
  group('IntentType', () {
    test('code 는 기획서 표기와 일치', () {
      expect(IntentType.scheduleAdd.code, 'schedule.add');
      expect(IntentType.goalToday.code, 'goal.today');
      expect(IntentType.none.code, 'none');
    });

    test('추가형/비추가형 구분', () {
      expect(IntentType.focusStart.isAdditive, isTrue);
      expect(IntentType.navMove.isAdditive, isFalse);
      expect(IntentType.helpFortune.isAdditive, isFalse);
      expect(IntentType.none.isAdditive, isFalse);
    });
  });

  group('기본 라우팅 지점 매핑(§3-1)', () {
    test('추가형은 A~J 로 매핑', () {
      expect(defaultRoutePointOf(IntentType.scheduleAdd), RoutePoint.schedule);
      expect(defaultRoutePointOf(IntentType.todoAdd), RoutePoint.quickCapture);
      expect(defaultRoutePointOf(IntentType.todoMatrix), RoutePoint.matrix);
      expect(defaultRoutePointOf(IntentType.goalToday), RoutePoint.goalToday);
      expect(defaultRoutePointOf(IntentType.focusStart), RoutePoint.focus);
    });

    test('habit.add / habit.check 둘 다 E 습관', () {
      expect(defaultRoutePointOf(IntentType.habitAdd), RoutePoint.habit);
      expect(defaultRoutePointOf(IntentType.habitCheck), RoutePoint.habit);
    });

    test('none → 보류함', () {
      expect(defaultRoutePointOf(IntentType.none), RoutePoint.inbox);
    });

    test('입력지점 문자·라벨', () {
      expect(RoutePoint.matrix.letter, 'B');
      expect(RoutePoint.schedule.label, '일정');
    });
  });

  group('상수(§2)', () {
    test('임계값 초기값', () {
      expect(VoiceThresholds.confirm, 3);
      expect(VoiceThresholds.minGap, 1);
    });

    test('시간단서 가점 초기값', () {
      expect(VoiceScores.futureDateTime, 3);
      expect(VoiceScores.pastTense, 3);
      expect(VoiceScores.durationClue, 2);
    });
  });

  group('TimeParseResult.stripFrom', () {
    test('구간이 없으면 원문 유지(trim)', () {
      const r = TimeParseResult();
      expect(r.stripFrom('  장보기 '), '장보기');
      expect(r.hasAny, isFalse);
    });

    test('여러 구간 제거 후 공백 정리', () {
      // "내일 3시에 치과 예약" 에서 "내일 3시에"(0..6) 제거 → "치과 예약"
      const r = TimeParseResult(
        matchedSpans: [SpanRange(0, 6)],
      );
      expect(r.stripFrom('내일 3시에 치과 예약'), '치과 예약');
    });
  });

  group('IntentScore / VoiceSlots 기본값', () {
    test('IntentScore.none 은 S==0', () {
      expect(IntentScore.none.intent, IntentType.none);
      expect(IntentScore.none.score, 0);
    });

    test('VoiceSlots.copyWith 은 지정 필드만 교체', () {
      const base = VoiceSlots(title: 'a', important: true);
      final next = base.copyWith(urgent: true);
      expect(next.title, 'a');
      expect(next.important, isTrue);
      expect(next.urgent, isTrue);
    });
  });
}
