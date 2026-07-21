import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../data/db.dart';
import '../../core/journal.dart';
import '../../core/theme.dart';
import '../../providers.dart';

/// 습관 탭 — 편집형. 카테고리 = 섹션 라벨, 습관마다 제목 + 오늘 토글 + 통계 + ●/○ 그리드.
class HabitView extends ConsumerWidget {
  const HabitView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = t(context);
    final habits = ref.watch(habitsProvider).valueOrNull ?? const [];

    if (habits.isEmpty) {
      return Container(
        color: tk.paper,
        alignment: Alignment.topLeft,
        padding: const EdgeInsets.only(top: 26),
        child: emptyNote(context, '오른쪽 위 + 로 습관을 만들어보세요'),
      );
    }

    final byCat = <String, List<Habit>>{};
    for (final h in habits) {
      byCat.putIfAbsent(h.category, () => []).add(h);
    }
    final cats = byCat.keys.toList()
      ..sort((a, b) {
        if (a.isEmpty) return -1;
        if (b.isEmpty) return 1;
        return a.compareTo(b);
      });

    final rows = <Widget>[];
    for (final c in cats) {
      final list = byCat[c]!;
      rows.add(SectionLabel(c.isEmpty ? 'GENERAL' : c, count: list.length));
      for (final h in list) {
        rows.add(_HabitBlock(habit: h));
      }
    }
    rows.add(const SizedBox(height: 16));

    return Container(
      color: tk.paper,
      child: ListView(padding: EdgeInsets.zero, children: rows),
    );
  }
}

class _HabitBlock extends ConsumerWidget {
  const _HabitBlock({required this.habit});
  final Habit habit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = t(context);
    final ticks =
        ref.watch(habitTicksProvider(habit.id)).valueOrNull ?? const [];
    final tickSet = {for (final t in ticks) dateOnly(t.date)};

    final start = dateOnly(habit.createdAt);
    final today = todayDate();
    final totalDays = today.difference(start).inDays + 1;
    final doneDays = tickSet.length;
    final percent = totalDays == 0 ? 0 : (doneDays * 100 / totalDays).round();
    final todayDone = tickSet.contains(today);

    final showDays = totalDays.clamp(1, 180);
    final firstShown = today.subtract(Duration(days: showDays - 1));

    return Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 12, kGutter, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(habit.title, style: AppText.body(tk.ink))),
              // 오늘 토글
              GestureDetector(
                onTap: () =>
                    ref.read(habitRepoProvider).toggleTick(habit.id, today),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(todayDone ? '● today' : '○ today',
                      style: AppText.nav(
                          todayDone ? tk.ink : tk.inkSoft,
                          active: todayDone)),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _menu(context, ref),
                behavior: HitTestBehavior.opaque,
                child: Text('⋯', style: AppText.glyph(tk.inkSoft, size: 16)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 통계 (모노 메타)
          Text('$totalDays일째 · $doneDays일 함 · $percent%',
              style: AppText.meta(tk.inkSoft)),
          const SizedBox(height: 12),
          // ●/○ 그리드
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              for (var i = 0; i < showDays; i++)
                _dot(
                  tk,
                  filled: tickSet.contains(firstShown.add(Duration(days: i))),
                  isToday: firstShown.add(Duration(days: i)) == today,
                  onTap: () => ref
                      .read(habitRepoProvider)
                      .toggleTick(habit.id, firstShown.add(Duration(days: i))),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dot(AppTokens tk,
      {required bool filled,
      required bool isToday,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Text(filled ? '●' : '○',
          style: AppText.glyph(
              filled ? tk.ink : tk.line.withValues(alpha: isToday ? 1 : 0.7),
              size: 13)),
    );
  }

  Future<void> _menu(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.folder_outlined, size: 20),
              title: const Text('카테고리 변경'),
              onTap: () {
                Navigator.of(ctx).pop();
                _changeCategory(context, ref);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, size: 20),
              title: const Text('삭제'),
              onTap: () {
                Navigator.of(ctx).pop();
                _confirmDelete(context, ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeCategory(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: habit.category);
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('카테고리'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration:
              const InputDecoration(hintText: '예: 건강, 공부 (비우면 기본)'),
          onSubmitted: (s) => Navigator.of(ctx).pop(s),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              child: const Text('저장')),
        ],
      ),
    );
    if (v == null) return;
    await ref.read(habitRepoProvider).setCategory(habit.id, v.trim());
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
