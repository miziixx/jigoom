import 'package:flutter_test/flutter_test.dart';
import 'package:jigeum/features/habit/habit_stats.dart';

void main() {
  // 기준일들 (자정 기준).
  DateTime d(int day) => DateTime(2026, 1, day);
  final start = d(1);
  final today = d(10);

  Set<DateTime> ticksOf(List<int> days) => {for (final x in days) d(x)};

  group('복귀 점수 (returnCount)', () {
    test('기록이 없으면 0', () {
      expect(returnCount(<DateTime>{}, start, today), 0);
    });

    test('끊김 없는 한 구간이면 복귀 0 (첫 시작은 복귀가 아님)', () {
      final ticks = ticksOf([1, 2, 3, 4]);
      expect(returnCount(ticks, start, today), 0);
    });

    test('공백 뒤 다시 시작하면 복귀 1', () {
      // 1,2 (공백 3) 4,5
      final ticks = ticksOf([1, 2, 4, 5]);
      expect(returnCount(ticks, start, today), 1);
    });

    test('세 구간이면 복귀 2', () {
      // 1 (공백) 3 (공백) 8,9
      final ticks = ticksOf([1, 3, 8, 9]);
      expect(returnCount(ticks, start, today), 2);
    });

    test('하루씩 띄엄띄엄이면 매번 복귀로 카운트', () {
      // 2,4,6 → 세 구간 → 복귀 2
      final ticks = ticksOf([2, 4, 6]);
      expect(returnCount(ticks, start, today), 2);
    });
  });

  group('최근 실행일 (recentActiveDays)', () {
    test('오늘 포함 최근 7일 중 실행일 수', () {
      // today=10 기준 최근 7일 = 4..10. 이 중 실행: 6,8,10 → 3
      final ticks = ticksOf([1, 6, 8, 10]);
      expect(recentActiveDays(ticks, today), 3);
    });

    test('window 를 넘기면 그만큼만 집계', () {
      final ticks = ticksOf([3, 4, 5, 6, 7, 8, 9, 10]);
      expect(recentActiveDays(ticks, today, window: 3), 3); // 8,9,10
    });
  });

  group('연속 (currentStreak / longestStreak)', () {
    test('현재 연속은 오늘부터 거꾸로', () {
      final ticks = ticksOf([8, 9, 10]);
      expect(currentStreak(ticks, today), 3);
    });

    test('오늘 안 했으면 현재 연속 0', () {
      final ticks = ticksOf([7, 8, 9]);
      expect(currentStreak(ticks, today), 0);
    });

    test('최장 연속', () {
      // 1,2,3 (공백) 5,6 → 최장 3
      final ticks = ticksOf([1, 2, 3, 5, 6]);
      expect(longestStreak(ticks, start, today), 3);
    });
  });

  group('여정 마일스톤 (habitMilestones)', () {
    test('시작 노드는 항상 첫 노드', () {
      final ms = habitMilestones(<DateTime>{}, start, today);
      expect(ms.first.kind, HabitMilestoneKind.start);
    });

    test('연속 임계값 달성일 + 현재/다음 목표', () {
      final ticks = ticksOf([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]); // 10일 연속(오늘 완료)
      final ms = habitMilestones(ticks, start, today);
      final reached =
          ms.where((m) => m.kind == HabitMilestoneKind.reached).toList();
      expect(reached.map((m) => m.streak).toSet(), {3, 7});
      expect(reached.firstWhere((m) => m.streak == 3).date, d(3));
      expect(reached.firstWhere((m) => m.streak == 7).date, d(7));
      final cur = ms.firstWhere((m) => m.kind == HabitMilestoneKind.current);
      expect(cur.streak, 10);
      final up = ms.firstWhere((m) => m.kind == HabitMilestoneKind.upcoming);
      expect(up.streak, 14);
      expect(up.date, isNull);
    });

    test('기록 없으면 현재 없음 + 다음 목표 3일', () {
      final ms = habitMilestones(<DateTime>{}, start, today);
      expect(ms.any((m) => m.kind == HabitMilestoneKind.current), false);
      final up = ms.firstWhere((m) => m.kind == HabitMilestoneKind.upcoming);
      expect(up.streak, 3);
    });
  });
}
