import 'package:flutter_test/flutter_test.dart';
import 'package:jigeum/core/regions.dart';

void main() {
  group('지역 검색', () {
    test('이름 부분일치', () {
      final r = searchRegions('성남');
      expect(r.any((x) => x.name == '성남'), isTrue);
    });

    test('별칭 검색(분당 → 성남)', () {
      final r = searchRegions('분당');
      expect(r.any((x) => x.name == '성남'), isTrue);
    });

    test('빈 검색어는 전체 반환', () {
      expect(searchRegions('').length, koreaRegions.length);
    });

    test('없는 지역은 빈 결과', () {
      expect(searchRegions('없는동네xyz'), isEmpty);
    });

    test('정확 이름이 앞에 온다', () {
      final r = searchRegions('강릉');
      expect(r.first.name, '강릉');
    });
  });

  group('지역 조회·복원', () {
    test('regionByName', () {
      final r = regionByName('부산');
      expect(r, isNotNull);
      expect(r!.lng, closeTo(129.08, 0.5));
      expect(r.lat, closeTo(35.18, 0.5));
    });

    test('경도 최근접(부산)', () {
      expect(nearestByLongitude(129.08).name, '부산');
    });

    test('resolveRegion — 이름 우선', () {
      expect(resolveRegion('대구', 126.98).name, '대구');
    });

    test('resolveRegion — 이름 없으면 경도 최근접', () {
      expect(resolveRegion(null, 126.53).name, '제주');
    });
  });

  test('모든 지역 좌표가 한반도 범위 안', () {
    for (final r in koreaRegions) {
      expect(r.lat, inInclusiveRange(33.0, 43.0), reason: r.name);
      expect(r.lng, inInclusiveRange(124.0, 132.0), reason: r.name);
    }
  });
}
