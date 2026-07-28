// 커밋6 인텐트 분류기. 정규화 → 파싱 → 분류 후 최고점 인텐트/격차를 단정한다.
// (라우팅 세 갈래 자체는 커밋8 VoiceRouter 테스트에서 검증.)
import 'package:flutter_test/flutter_test.dart';
import 'package:jigeum/features/voice/models/intent_type.dart';
import 'package:jigeum/features/voice/pipeline/intent_classifier.dart';
import 'package:jigeum/features/voice/pipeline/ko_datetime_parser.dart';
import 'package:jigeum/features/voice/pipeline/text_normalizer.dart';

void main() {
  const normalizer = TextNormalizer();
  const parser = KoDateTimeParser();
  final base = DateTime(2026, 7, 24); // 금요일

  IntentClassifier clf({Set<String> habits = const {}}) =>
      IntentClassifier(knownHabits: habits);

  ({IntentType intent, int score, int gap}) run(String raw,
      {Set<String> habits = const {}}) {
    final n = normalizer.normalize(raw);
    final tp = parser.parse(n, now: base);
    final r = clf(habits: habits).classify(n, tp);
    return (intent: r.intent, score: r.score, gap: r.runnerUpGap);
  }

  group('§8 코퍼스 최고점 인텐트', () {
    final expected = <String, IntentType>{
      '내일 3시에 치과 예약': IntentType.scheduleAdd,
      '금요일에 장보기': IntentType.scheduleAdd,
      '장보기 할 일로 넣어줘': IntentType.todoAdd,
      '이거 중요하고 급해 보고서': IntentType.todoMatrix,
      '방금 30분 코딩했어': IntentType.logNow,
      '물 마시기 습관 만들어': IntentType.habitAdd,
      '아침 루틴에 스트레칭 추가': IntentType.routineAdd,
      '영어공부 목표 세울래': IntentType.goalAdd,
      '오늘 목표는 보고서 끝내기': IntentType.goalToday,
      '지금 25분만 집중할래': IntentType.focusStart,
      '오늘 운세 봐줘': IntentType.helpFortune,
      '이번 달 달력 보여줘': IntentType.navMove,
      '막혔어 못하겠어': IntentType.helpStuck,
      '어… 그거 있잖아 뭐였지': IntentType.none,
      '파란색 그거 처리': IntentType.todoAdd,
    };
    expected.forEach((raw, intent) {
      test('"$raw" → ${intent.code}', () {
        expect(run(raw).intent, intent);
      });
    });
  });

  group('세 갈래를 가르는 점수 성질', () {
    test('미인식은 S==0', () {
      expect(run('어… 그거 있잖아 뭐였지').score, 0);
    });

    test('애매(파란색 그거 처리)는 0<S<CONFIRM(3)', () {
      final r = run('파란색 그거 처리');
      expect(r.score, greaterThan(0));
      expect(r.score, lessThan(3));
    });

    test('확정후보(내일 3시 치과)는 S>=3 이고 격차 D>=1', () {
      final r = run('내일 3시에 치과 예약');
      expect(r.score, greaterThanOrEqualTo(3));
      expect(r.gap, greaterThanOrEqualTo(1));
    });

    test('날짜만(금요일 장보기)은 schedule 이 최고점이나 S<3 → A 로 떨어질 것', () {
      final r = run('금요일에 장보기');
      expect(r.intent, IntentType.scheduleAdd);
      expect(r.score, lessThan(3));
    });
  });

  group('§11-2 등록 습관 대조로 habit.check 분기', () {
    test('등록 습관 "물 마시기" + 과거 → habit.check', () {
      final r = run('물 마시기 했어', habits: {'물 마시기'});
      expect(r.intent, IntentType.habitCheck);
    });

    test('미등록이면 habit.check 안 뜸(과거 → log.now)', () {
      final r = run('물 마시기 했어');
      expect(r.intent, IntentType.logNow);
    });
  });
}
