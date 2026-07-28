import 'package:flutter_test/flutter_test.dart';
import 'package:jigeum/core/astrology.dart';
import 'package:jigeum/core/explain.dart';
import 'package:jigeum/core/fortune.dart';
import 'package:jigeum/core/fortune_text.dart';
import 'package:jigeum/core/saju.dart';

void main() {
  final chart = computeSaju(
    DateTime(1990, 5, 15, 10, 30),
    hasHour: true,
    longitude: 126.98,
    male: true,
  );

  group('오늘의 운세 계산', () {
    test('결정성 — 같은 사주·날짜는 같은 결과', () {
      final a = computeDailyFortune(chart, DateTime(2026, 7, 22));
      final b = computeDailyFortune(chart, DateTime(2026, 7, 22));
      expect(a.overall, b.overall);
      for (var i = 0; i < a.categories.length; i++) {
        expect(a.categories[i].score, b.categories[i].score);
        expect(a.categories[i].key, b.categories[i].key);
      }
    });

    test('카테고리 14종(총운 포함) + 점수 범위', () {
      final f = computeDailyFortune(chart, DateTime(2026, 7, 22));
      expect(f.categories.length, 14);
      for (final c in f.categories) {
        expect(c.score, inInclusiveRange(0, 100));
      }
    });
  });

  group('레벨별 풀이 렌더', () {
    test('모든 카테고리 × 모든 레벨에서 요약·본문·조언 비지 않음', () {
      final f = computeDailyFortune(chart, DateTime(2026, 7, 22));
      for (final level in ExplainLevel.values) {
        for (final c in f.categories) {
          final txt = describeCategory(c, level);
          expect(txt.summary, isNotEmpty, reason: '${c.key}/$level summary');
          expect(txt.body, isNotEmpty, reason: '${c.key}/$level body');
          expect(txt.body.every((l) => l.trim().isNotEmpty), isTrue,
              reason: '${c.key}/$level body line');
          expect(txt.advice, isNotEmpty, reason: '${c.key}/$level advice');
        }
      }
    });

    test('일반인은 근거 블록 없음, 중급·고급은 근거 있음', () {
      final f = computeDailyFortune(chart, DateTime(2026, 7, 22));
      final overall = f.categories.first;
      expect(describeCategory(overall, ExplainLevel.general).basis, isEmpty);
      expect(
          describeCategory(overall, ExplainLevel.junggeup).basis, isNotEmpty);
      expect(describeCategory(overall, ExplainLevel.gogeup).basis, isNotEmpty);
    });
  });

  group('점성 풀이 렌더', () {
    test('모든 레벨에서 카드 5종·본문 비지 않음', () {
      final astro = computeAstroChart(DateTime(1990, 5, 15, 10, 30),
          hasTime: true, latitude: 37.57, longitude: 126.98);
      for (final level in ExplainLevel.values) {
        final rs = astroReadings(astro, DateTime(2026, 7, 22), level);
        expect(rs.length, 5);
        for (final r in rs) {
          expect(r.title, isNotEmpty);
          expect(r.body, isNotEmpty);
          expect(r.body.every((l) => l.trim().isNotEmpty), isTrue);
        }
      }
    });
  });

  group('용어 사전', () {
    test('gloss는 레벨마다 비지 않는 문자열', () {
      for (final key in ['gwanseong', 'hap', 'yongsin', 'mok']) {
        for (final level in ExplainLevel.values) {
          expect(gloss(key, level), isNotEmpty);
        }
      }
    });
  });
}
