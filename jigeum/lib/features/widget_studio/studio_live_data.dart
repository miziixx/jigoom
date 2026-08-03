import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../data/db.dart';
import '../../features/habit/habit_stats.dart';
import '../../providers.dart';

/// ============================================================
/// WIDGET STUDIO — 실제 앱 데이터 연결(§16)
///
/// 위젯 본문이 쓰는 실데이터 묶음. 기존 Riverpod 스트림(할 일·습관·목표·일정)을
/// 위젯 표시용 경량 행으로 변환한다. **데이터가 없으면 각 리스트를 비워** 두고,
/// 본문은 그때만 레퍼런스 샘플 문구로 폴백한다(§16 규칙).
///
/// 아직 실데이터로 연결되지 않은 항목(운세=사주 차트 필요, 캘린더 WEEK/MONTH
/// 격자)은 후속 단계에서 이 묶음에 추가한다.
/// ============================================================

class StudioTaskRow {
  const StudioTaskRow(this.title, this.done, this.tags, this.chip);
  final String title;
  final bool done;
  final String tags; // "#중요 #긴급"
  final String chip; // 완료 / 오늘 / M/d
}

class StudioHabitRow {
  const StudioHabitRow(this.title, this.sub, this.done);
  final String title;
  final String sub; // "아침 · 7일 연속"
  final bool done;
}

class StudioGoalInfo {
  const StudioGoalInfo(this.title, this.sub, this.doneCount, this.total);
  final String title;
  final String sub;
  final int doneCount;
  final int total;
  double get ratio => total <= 0 ? 0 : (doneCount / total).clamp(0.0, 1.0);
}

class StudioEventRow {
  const StudioEventRow(this.time, this.title, this.sub);
  final String time; // "09:00"
  final String title;
  final String sub;
}

class StudioLiveData {
  const StudioLiveData({
    this.tasks = const [],
    this.habits = const [],
    this.goal,
    this.dayEvents = const [],
  });

  final List<StudioTaskRow> tasks;
  final List<StudioHabitRow> habits;
  final StudioGoalInfo? goal;
  final List<StudioEventRow> dayEvents;
}

String _hhmm(int min) =>
    '${(min ~/ 60).toString().padLeft(2, '0')}:${(min % 60).toString().padLeft(2, '0')}';

/// 기존 스트림을 위젯 표시용으로 묶는다. 스트림이 아직 로드 전이면 빈 값.
final studioLiveDataProvider = Provider<StudioLiveData>((ref) {
  final today = todayDate();

  // --- 할 일: 오늘 완료(승리) + 오늘 열린 할 일 ---
  final wins = ref.watch(todayWinsProvider).valueOrNull ?? const <Node>[];
  final open = ref.watch(todayNodesProvider).valueOrNull ?? const <Node>[];
  final openTasks = open.where((n) => n.type != 'goal').toList();

  String tagsOf(Node n) {
    final parts = <String>[];
    if (n.important) parts.add('#중요');
    if (n.urgent) parts.add('#긴급');
    if (parts.isEmpty && n.date == today) parts.add('#오늘');
    return parts.join(' ');
  }

  String chipOf(Node n) {
    if (n.date == today) return '오늘';
    if (n.date != null) return DateFormat('M/d').format(n.date!);
    return '—';
  }

  final tasks = <StudioTaskRow>[
    for (final n in wins.take(1))
      StudioTaskRow(n.title, true, tagsOf(n), '완료'),
    for (final n in openTasks) StudioTaskRow(n.title, false, tagsOf(n), chipOf(n)),
  ];

  // --- 습관: 제목 + "분류 · N일 연속" + 오늘 완료 ---
  final habitList = ref.watch(habitsProvider).valueOrNull ?? const <Habit>[];
  final rangeTicks = ref
          .watch(habitTicksInRangeProvider(
              (start: today.subtract(const Duration(days: 60)), end: today)))
          .valueOrNull ??
      const <HabitTick>[];
  final byHabit = <String, Set<DateTime>>{};
  for (final tk in rangeTicks) {
    final d = DateTime(tk.date.year, tk.date.month, tk.date.day);
    (byHabit[tk.habitId] ??= <DateTime>{}).add(d);
  }
  final habits = <StudioHabitRow>[
    for (final h in habitList)
      () {
        final set = byHabit[h.id] ?? const <DateTime>{};
        final streak = currentStreak(set, today);
        final sub = h.category.isNotEmpty
            ? '${h.category} · $streak일 연속'
            : '$streak일 연속';
        return StudioHabitRow(h.title, sub, set.contains(today));
      }(),
  ];

  // --- 목표: 첫 목표(없으면 포커스) + 오늘 진행률(완료/전체) ---
  final goals = ref.watch(goalsProvider).valueOrNull ?? const <Node>[];
  final total = wins.length + openTasks.length;
  StudioGoalInfo? goal;
  if (goals.isNotEmpty) {
    final g = goals.first;
    goal = StudioGoalInfo(
        g.title, g.note.isNotEmpty ? g.note : '오늘의 목표', wins.length, total);
  } else {
    final focus = ref.watch(focusProvider).valueOrNull;
    if (focus != null) {
      goal = StudioGoalInfo(focus.title, '지금 집중할 하나', wins.length, total);
    }
  }

  // --- 캘린더 DAY: 오늘 일정(종일 제외, 시작 시각순) ---
  final scheds = ref.watch(schedulesForDateProvider(today)).valueOrNull ??
      const <Schedule>[];
  final timed = scheds.where((s) => !s.allDay).toList()
    ..sort((a, b) => a.startMin.compareTo(b.startMin));
  final dayEvents = <StudioEventRow>[
    for (final s in timed)
      StudioEventRow(
        _hhmm(s.startMin),
        s.title,
        s.note.isNotEmpty
            ? s.note
            : (s.gcalCalendarId != null
                ? 'Google Calendar'
                : '${_hhmm(s.startMin)}–${_hhmm(s.endMin)}'),
      ),
  ];

  return StudioLiveData(
    tasks: tasks,
    habits: habits,
    goal: goal,
    dayEvents: dayEvents,
  );
});
