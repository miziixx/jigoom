import 'package:flutter_test/flutter_test.dart';
import 'package:jigeum/features/voice/models/time_parse_result.dart';
import 'package:jigeum/features/voice/pipeline/ko_datetime_parser.dart';

void main() {
  const p = KoDateTimeParser();
  // 기준일 2026-07-24(금).
  final now = DateTime(2026, 7, 24);
  DateTime d(int m, int day) => DateTime(2026, m, day);

  TimeParseResult parse(String s) => p.parse(s, now: now);

  group('시각(§4-2)', () {
    test('오전/오후 12h→24h', () {
      expect(parse('오전 9시').time, const ParsedTime(9, 0));
      expect(parse('오후 3시').time, const ParsedTime(15, 0));
      expect(parse('저녁 7시').time, const ParsedTime(19, 0));
    });

    test('표기 없는 정시: 1~6시는 오후로, 7~11시는 그대로', () {
      expect(parse('3시').time, const ParsedTime(15, 0));
      expect(parse('7시').time, const ParsedTime(7, 0));
      expect(parse('9시').time, const ParsedTime(9, 0));
    });

    test('분과 "반"', () {
      expect(parse('3시 30분').time, const ParsedTime(15, 30));
      expect(parse('3시 반').time, const ParsedTime(15, 30));
    });

    test('순우리말 수사(세시/열두시)', () {
      expect(parse('세시').time, const ParsedTime(15, 0));
      expect(parse('열두시').time, const ParsedTime(12, 0));
    });

    test('오전 12시 → 00시, 오후 12시 → 12시', () {
      expect(parse('오전 12시').time, const ParsedTime(0, 0));
      expect(parse('오후 12시').time, const ParsedTime(12, 0));
    });
  });

  group('기간(§4-3)', () {
    test('N분 / N분만', () {
      expect(parse('25분만 집중').durationMin, 25);
      expect(parse('90분').durationMin, 90);
    });

    test('시간 + 반', () {
      expect(parse('한시간 반').durationMin, 90);
      expect(parse('두시간').durationMin, 120);
      expect(parse('1시간 30분').durationMin, 90);
    });

    test('"시간"은 시각(N시)으로 오인되지 않음', () {
      final r = parse('한시간');
      expect(r.durationMin, 60);
      expect(r.time, isNull);
    });
  });

  group('날짜(§4-1)', () {
    test('상대일', () {
      expect(parse('오늘').date, d(7, 24));
      expect(parse('내일').date, d(7, 25));
      expect(parse('모레').date, d(7, 26));
      expect(parse('글피').date, d(7, 27));
    });

    test('어제는 과거(isPast)', () {
      final r = parse('어제');
      expect(r.date, d(7, 23));
      expect(r.isPast, isTrue);
    });

    test('N일 뒤/후', () {
      expect(parse('3일 뒤').date, d(7, 27));
      expect(parse('열흘 뒤').date, isNull); // "열흘"은 사전에 없음 → 미검출
      expect(parse('5일 후').date, d(7, 29));
    });

    test('N월 N일 — 미래는 올해, 과거는 내년 롤오버', () {
      expect(parse('8월 15일').date, d(8, 15));
      expect(parse('1월 5일').date, DateTime(2027, 1, 5));
    });

    test('요일 — 가장 가까운 미래, "다음주"면 +7', () {
      expect(parse('수요일').date, d(7, 29)); // 금→다음 수요일
      expect(parse('다음주 수요일').date, DateTime(2026, 8, 5));
      expect(parse('월요일').date!.weekday, DateTime.monday);
    });
  });

  group('과거 시제(§3-3)', () {
    test('past_markers 감지', () {
      expect(parse('방금 코딩했어').isPast, isTrue);
      expect(parse('아까 마쳤어').isPast, isTrue);
    });

    test('막혔어/못하겠어는 과거로 오검출되지 않음', () {
      expect(parse('막혔어 못하겠어').isPast, isFalse);
    });
  });

  group('구간 제거(§4-4 matchedSpans)', () {
    test('날짜·시각 제거 후 제목만 남음', () {
      const text = '내일 오후 3시에 회의';
      final r = parse(text);
      expect(r.date, d(7, 25));
      expect(r.time, const ParsedTime(15, 0));
      expect(r.stripFrom(text), '회의');
    });

    test('과거 마커도 제거된다', () {
      const text = '방금 30분 코딩했어';
      final r = parse(text);
      expect(r.durationMin, 30);
      // "방금", "30분", "했어" 제거 → "코딩"
      expect(r.stripFrom(text), '코딩');
    });
  });
}
