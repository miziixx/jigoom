import 'package:flutter_test/flutter_test.dart';
import 'package:jigeum/core/almanac.dart';

/// 음력 변환 잠금 테스트.
/// 1391~2049년은 KASI 기반 룩업표를 쓰므로 날짜·윤달이 만세력과 정확히 일치한다.
/// 공식 공휴일(설날·추석·부처님오신날) + 알려진 윤달(윤11 포함)로 잠근다.
void main() {
  Lunar lunar(int y, int m, int d) => lunarOf(DateTime(y, m, d));

  group('음력 — 공휴일 기준(만세력)', () {
    test('설날 = 음력 1월 1일', () {
      for (final e in const [
        [2023, 1, 22],
        [2024, 2, 10],
        [2025, 1, 29],
        [2026, 2, 17],
      ]) {
        final l = lunar(e[0], e[1], e[2]);
        expect(l.month, 1, reason: '$e 설날은 음력 1월');
        expect(l.day, 1, reason: '$e 설날은 초하루');
        expect(l.leap, isFalse, reason: '$e 설날은 평달');
      }
    });

    test('추석 = 음력 8월 15일', () {
      for (final e in const [
        [2023, 9, 29],
        [2024, 9, 17],
        [2025, 10, 6],
      ]) {
        final l = lunar(e[0], e[1], e[2]);
        expect(l.month, 8, reason: '$e 추석은 음력 8월');
        expect(l.day, 15, reason: '$e 추석은 보름');
        expect(l.leap, isFalse);
      }
    });

    test('부처님오신날 = 음력 4월 8일', () {
      for (final e in const [
        [2024, 5, 15],
        [2025, 5, 5],
      ]) {
        final l = lunar(e[0], e[1], e[2]);
        expect(l.month, 4, reason: '$e 초파일은 음력 4월');
        expect(l.day, 8);
        expect(l.leap, isFalse);
      }
    });
  });

  group('윤달 — 무중치윤 규칙', () {
    int leapMonthOf(int year) {
      var d = DateTime(year, 1, 1);
      final end = DateTime(year, 12, 31);
      while (!d.isAfter(end)) {
        final l = lunarOf(d);
        if (l.leap) return l.month;
        d = d.add(const Duration(days: 1));
      }
      return 0; // 평년
    }

    test('윤달 위치 — KASI 정답과 일치', () {
      const expected = {
        2014: 9,
        2017: 5,
        2020: 4,
        2023: 2,
        2025: 6,
        2028: 5,
        2031: 3,
        2033: 11, // 희귀한 윤11월
      };
      final got = {for (final y in expected.keys) y: leapMonthOf(y)};
      expect(got, expected);
    });

    test('평년엔 윤달 없음', () {
      for (final y in const [2019, 2021, 2022, 2024, 2026, 2027]) {
        expect(leapMonthOf(y), 0, reason: '$y 평년');
      }
    });
  });

  group('음력 일자 연속성', () {
    test('삭일(초하루) 다음날은 초이틀', () {
      final l = lunar(2025, 1, 30); // 2025 설날(1/1) 다음날
      expect(l.month, 1);
      expect(l.day, 2);
      expect(l.leap, isFalse);
    });

    test('일자는 1~30·월은 1~12 범위', () {
      var d = DateTime(2025, 1, 1);
      final end = DateTime(2025, 12, 31);
      while (!d.isAfter(end)) {
        final l = lunarOf(d);
        expect(l.day, inInclusiveRange(1, 30));
        expect(l.month, inInclusiveRange(1, 12));
        d = d.add(const Duration(days: 1));
      }
    });
  });
}
