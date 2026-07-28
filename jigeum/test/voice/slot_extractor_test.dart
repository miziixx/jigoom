// 커밋7 슬롯 추출기. 인텐트별 제목/중요·긴급/그룹·스텝/분 채우기를 단정.
import 'package:flutter_test/flutter_test.dart';
import 'package:jigeum/features/voice/models/intent_type.dart';
import 'package:jigeum/features/voice/models/time_parse_result.dart';
import 'package:jigeum/features/voice/models/voice_result.dart';
import 'package:jigeum/features/voice/pipeline/ko_datetime_parser.dart';
import 'package:jigeum/features/voice/pipeline/slot_extractor.dart';
import 'package:jigeum/features/voice/pipeline/text_normalizer.dart';

void main() {
  const normalizer = TextNormalizer();
  const parser = KoDateTimeParser();
  const extractor = SlotExtractor();
  final base = DateTime(2026, 7, 24);

  VoiceSlots slotsOf(String raw, IntentType intent,
      {Set<String> habits = const {}}) {
    final n = normalizer.normalize(raw);
    final tp = parser.parse(n, now: base);
    return SlotExtractor(knownHabits: habits).extract(intent, n, tp);
  }

  group('제목/내용 정리 — 시간부·구조어 제거', () {
    test('내일 3시에 치과 예약 → 제목 "치과" (+ 날짜/시각 슬롯)', () {
      final s = slotsOf('내일 3시에 치과 예약', IntentType.scheduleAdd);
      expect(s.title, '치과');
      expect(s.date, DateTime(2026, 7, 25));
      expect(s.time, const ParsedTime(15, 0));
    });

    test('장보기 할 일로 넣어줘 → 제목 "장보기"', () {
      expect(slotsOf('장보기 할 일로 넣어줘', IntentType.todoAdd).title, '장보기');
    });

    test('방금 30분 코딩했어 → 내용 "코딩", 분=30', () {
      final s = slotsOf('방금 30분 코딩했어', IntentType.logNow);
      expect(s.title, '코딩');
      expect(s.durationMin, 30);
    });

    test('물 마시기 습관 만들어 → 습관명 "물 마시기"', () {
      final s = slotsOf('물 마시기 습관 만들어', IntentType.habitAdd);
      expect(s.title, '물 마시기');
      expect(s.habitName, '물 마시기');
    });

    test('영어공부 목표 세울래 → 제목 "영어공부"', () {
      expect(slotsOf('영어공부 목표 세울래', IntentType.goalAdd).title, '영어공부');
    });

    test('오늘 목표는 보고서 끝내기 → 텍스트 "보고서 끝내기"', () {
      final s = slotsOf('오늘 목표는 보고서 끝내기', IntentType.goalToday);
      expect(s.title, '보고서 끝내기');
      expect(s.text, '보고서 끝내기');
    });

    test('애매(파란색 그거 처리)는 원문 유지 → 제목 "파란색 그거 처리"', () {
      expect(slotsOf('파란색 그거 처리', IntentType.todoAdd).title, '파란색 그거 처리');
    });
  });

  group('todo.matrix 중요·긴급 축', () {
    test('이거 중요하고 급해 보고서 → 제목 "보고서", 중요✓ 긴급✓', () {
      final s = slotsOf('이거 중요하고 급해 보고서', IntentType.todoMatrix);
      expect(s.title, '보고서');
      expect(s.important, isTrue);
      expect(s.urgent, isTrue);
    });
  });

  group('routine 그룹·스텝 분해', () {
    test('아침 루틴에 스트레칭 추가 → 그룹="아침", 스텝/제목="스트레칭"', () {
      final s = slotsOf('아침 루틴에 스트레칭 추가', IntentType.routineAdd);
      expect(s.groupName, '아침');
      expect(s.stepName, '스트레칭');
      expect(s.title, '스트레칭');
    });
  });

  group('focus 분 슬롯', () {
    test('지금 25분만 집중할래 → 분=25', () {
      expect(slotsOf('지금 25분만 집중할래', IntentType.focusStart).durationMin, 25);
    });
  });

  group('habit.check 대상 이름', () {
    test('등록 습관과 대조해 habitName 확정', () {
      final s = slotsOf('물 마시기 했어', IntentType.habitCheck,
          habits: {'물 마시기'});
      expect(s.habitName, '물 마시기');
    });
  });
}
