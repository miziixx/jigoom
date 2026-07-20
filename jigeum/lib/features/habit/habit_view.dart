import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../data/db.dart';
import '../../providers.dart';

/// 습관 탭 — 레퍼런스 스타일 해빗 트래커.
/// 습관마다: 제목 + [오늘 체크] + 통계(총/완료/%) + ✦ 그리드
/// (한 날 = 잉크 ✦, 안 한 날 = 연회색 ✦).
class HabitView extends ConsumerWidget {
  const HabitView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(habitsProvider).valueOrNull ?? const [];

    if (habits.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('아직 습관이 없어요',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text('오른쪽 위 ✦ 버튼으로 만들어보세요',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [for (final h in habits) _HabitCard(habit: h)],
    );
  }
}

class _HabitCard extends ConsumerWidget {
  const _HabitCard({required this.habit});
  final Habit habit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hairline = theme.dividerTheme.color ?? Colors.black12;
    final ink = theme.textTheme.bodyLarge?.color ?? Colors.black;

    final ticks =
        ref.watch(habitTicksProvider(habit.id)).valueOrNull ?? const [];
    final tickSet = {for (final t in ticks) dateOnly(t.date)};

    final start = dateOnly(habit.createdAt);
    final today = todayDate();
    final totalDays = today.difference(start).inDays + 1;
    final doneDays = tickSet.length;
    final percent =
        totalDays == 0 ? 0 : (doneDays * 100 / totalDays).round();
    final todayDone = tickSet.contains(today);

    // 표시 일수: 시작일부터, 최대 최근 180일.
    final showDays = totalDays.clamp(1, 180);
    final firstShown = today.subtract(Duration(days: showDays - 1));

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: hairline, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(habit.title, style: theme.textTheme.titleMedium),
              ),
              // 오늘 체크 토글
              GestureDetector(
                onTap: () => ref
                    .read(habitRepoProvider)
                    .toggleTick(habit.id, today),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: todayDone ? ink : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                    border: todayDone
                        ? null
                        : Border.all(color: hairline, width: 0.8),
                  ),
                  child: Text(
                    todayDone ? '오늘 ✦' : '오늘',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: todayDone
                          ? theme.scaffoldBackgroundColor
                          : theme.textTheme.bodySmall?.color,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onLongPress: () => _confirmDelete(context, ref),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.more_horiz,
                      size: 16, color: theme.textTheme.bodySmall?.color),
                ),
                onTap: () => _confirmDelete(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 통계 (레퍼런스 스타일)
          _stat(theme, '$totalDays', '일째'),
          _stat(theme, '$doneDays', '일 함'),
          _stat(theme, '$percent%', '만큼 해냈어요'),
          const SizedBox(height: 12),

          // ✦ 그리드
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              for (var i = 0; i < showDays; i++)
                _star(
                  theme,
                  filled: tickSet
                      .contains(firstShown.add(Duration(days: i))),
                  isToday:
                      firstShown.add(Duration(days: i)) == today,
                  onTap: () {
                    final d = firstShown.add(Duration(days: i));
                    // 과거 날짜도 탭해서 수정 가능 (미래는 없음)
                    ref.read(habitRepoProvider).toggleTick(habit.id, d);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(ThemeData theme, String strong, String rest) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(strong,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          Text(rest,
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _star(ThemeData theme,
      {required bool filled,
      required bool isToday,
      required VoidCallback onTap}) {
    final ink = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final faint = (theme.textTheme.bodySmall?.color ?? Colors.grey)
        .withValues(alpha: 0.22);
    return GestureDetector(
      onTap: onTap,
      child: Text(
        '✦',
        style: TextStyle(
          fontSize: 14,
          height: 1,
          color: filled ? ink : faint,
          fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('"${habit.title}" 삭제할까요?'),
        content: const Text('기록도 함께 지워져요.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('삭제')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(habitRepoProvider).deleteHabit(habit.id);
    }
  }
}
