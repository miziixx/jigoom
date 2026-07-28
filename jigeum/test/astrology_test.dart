import 'package:flutter_test/flutter_test.dart';
import 'package:jigeum/core/almanac.dart';
import 'package:jigeum/core/astrology.dart';

void main() {
  group('별자리 황경 판정', () {
    test('signIndexFromLongitude 경계', () {
      expect(signIndexFromLongitude(0), 0); // 양자리
      expect(signIndexFromLongitude(29.9), 0);
      expect(signIndexFromLongitude(30), 1); // 황소
      expect(signIndexFromLongitude(359.9), 11); // 물고기
      expect(signIndexFromLongitude(360), 0); // 래핑
      expect(signIndexFromLongitude(-1), 11); // 음수 정규화
    });

    test('태양 별자리 — 각 별자리 안쪽 날짜', () {
      int sun(DateTime d) =>
          signIndexFromLongitude(sunEclipticLongitude(d));
      expect(sun(DateTime(2024, 4, 10, 12)), 0); // 양자리
      expect(sun(DateTime(2024, 8, 5, 12)), 4); // 사자자리
      expect(sun(DateTime(2024, 11, 15, 12)), 7); // 전갈자리
      expect(sun(DateTime(2024, 1, 15, 12)), 9); // 염소자리
    });
  });

  group('달 황경', () {
    test('0~360 범위·정규화', () {
      final l = moonEclipticLongitude(DateTime(2024, 6, 1, 12));
      expect(l, greaterThanOrEqualTo(0));
      expect(l, lessThan(360));
    });

    test('결정성 — 같은 시각 같은 값', () {
      final a = moonEclipticLongitude(DateTime(1990, 5, 15, 10, 30));
      final b = moonEclipticLongitude(DateTime(1990, 5, 15, 10, 30));
      expect(a, b);
    });

    test('달은 하루에 약 13도 전진', () {
      final d0 = moonEclipticLongitude(DateTime(2024, 3, 1, 0));
      final d1 = moonEclipticLongitude(DateTime(2024, 3, 2, 0));
      var diff = d1 - d0;
      if (diff < 0) diff += 360;
      expect(diff, inInclusiveRange(11, 15));
    });
  });

  group('상승궁', () {
    test('위도별 유효 index 반환(예외 없음)', () {
      for (final lat in [33.5, 37.57, 41.8]) {
        final i = ascendantSignIndex(DateTime(1990, 5, 15, 6, 0), lat, 126.98);
        expect(i, inInclusiveRange(0, 11));
      }
    });
  });

  group('AstroChart', () {
    test('시각 없으면 상승궁 null, 원소 집계 태양+달 2개', () {
      final c = computeAstroChart(DateTime(1988, 2, 20),
          hasTime: false, latitude: 37.57, longitude: 126.98);
      expect(c.rising, isNull);
      final total =
          c.elementCount.values.reduce((a, b) => a + b);
      expect(total, 2);
    });

    test('시각+지역 있으면 상승궁 존재, 원소 집계 3개', () {
      final c = computeAstroChart(DateTime(1988, 2, 20, 9, 15),
          hasTime: true, latitude: 37.57, longitude: 126.98);
      expect(c.rising, isNotNull);
      final total = c.elementCount.values.reduce((a, b) => a + b);
      expect(total, 3);
    });
  });
}
